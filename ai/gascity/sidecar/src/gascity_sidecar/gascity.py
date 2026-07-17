"""Narrow asynchronous client for the Gas City REST API and CLI."""

from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import Mapping
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from .config import Settings

_LOG = logging.getLogger(__name__)


class GasCityError(RuntimeError):
    """Base class for expected Gas City client failures."""


class GasCityUnavailable(GasCityError):
    """The REST endpoint or CLI could not be reached."""


class GasCityTimeout(GasCityError):
    """A REST or CLI request exceeded its deadline."""


class GasCityCommandError(GasCityError):
    """The Gas City CLI exited unsuccessfully."""

    def __init__(self, category: str, returncode: int, stderr: str = ""):
        self.category = category
        self.returncode = returncode
        self.stderr = stderr
        detail = stderr.strip() or f"exit code {returncode}"
        super().__init__(f"Gas City {category} command failed: {detail}")


class GasCitySchemaError(GasCityError):
    """Gas City returned data that is not the documented JSON shape."""


class _ApiUnavailable(GasCityUnavailable):
    pass


class GasCityClient:
    """Status-focused client that never invokes a shell or interpolates commands."""

    def __init__(
        self,
        settings: Settings | None = None,
        *,
        city_path: str | Path | None = None,
        api_base_url: str | None = None,
        cli_command: str | Path | None = None,
        timeout: float | None = None,
    ):
        self.settings = settings or Settings()
        self.city_path = Path(city_path or self.settings.city_path)
        self.api_base_url = (api_base_url or self.settings.api_base_url()).rstrip("/")
        self.cli_command = str(cli_command or self.settings.gc_command)
        self.timeout = timeout or self.settings.gc_timeout_seconds

    @property
    def city_name(self) -> str:
        return self.city_path.resolve().name

    async def _request_api(
        self,
        category: str,
        path: str,
        *,
        payload: Mapping[str, Any] | None = None,
        method: str | None = None,
    ) -> Any:
        url = f"{self.api_base_url}{path}"
        body = json.dumps(payload).encode() if payload is not None else None
        request_method = method or ("POST" if body else "GET")
        headers = {"Accept": "application/json"}
        if request_method != "GET":
            headers["X-GC-Request"] = "sidecar"
        if body is not None:
            headers["Content-Type"] = "application/json"
        request = Request(url, data=body, headers=headers, method=request_method)

        def fetch() -> tuple[int, bytes]:
            try:
                with urlopen(request, timeout=self.timeout) as response:
                    return response.status, response.read()
            except HTTPError as exc:
                if exc.code == 404:
                    raise _ApiUnavailable(f"Gas City API does not provide {category}") from exc
                raise GasCityError(f"Gas City API {category} returned HTTP {exc.code}") from exc
            except (URLError, OSError) as exc:
                raise _ApiUnavailable(f"Gas City API unavailable for {category}") from exc

        try:
            _, raw = await asyncio.wait_for(asyncio.to_thread(fetch), self.timeout)
        except asyncio.TimeoutError as exc:
            raise GasCityTimeout(f"Gas City API {category} timed out") from exc
        try:
            return json.loads(raw)
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise GasCitySchemaError(f"Gas City API {category} returned invalid JSON") from exc

    async def _run_cli(self, category: str, *arguments: str) -> str:
        _LOG.info("running Gas City command", extra={"command_category": category})
        command = [
            self.cli_command,
            "--city",
            str(self.city_path),
            *arguments,
        ]
        try:
            process = await asyncio.create_subprocess_exec(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(self.city_path),
            )
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), self.timeout)
            except asyncio.TimeoutError as exc:
                process.kill()
                await process.communicate()
                raise GasCityTimeout(f"Gas City {category} command timed out") from exc
        except FileNotFoundError as exc:
            raise GasCityUnavailable("Gas City CLI is not installed") from exc
        if process.returncode:
            raise GasCityCommandError(category, process.returncode, stderr.decode(errors="replace"))
        return stdout.decode(errors="replace")

    @staticmethod
    def _json_object(raw: Any, category: str) -> dict[str, Any]:
        if not isinstance(raw, Mapping):
            raise GasCitySchemaError(f"Gas City {category} response must be a JSON object")
        return dict(raw)

    async def status(self) -> dict[str, Any]:
        """Get city status, preferring REST and falling back to `gc status --json`."""
        path = f"/v0/city/{quote(self.city_name, safe='')}/status"
        try:
            raw = await self._request_api("status", path)
            return self._json_object(raw, "status")
        except _ApiUnavailable:
            raw = await self._run_cli("status", "status", "--json")
            try:
                decoded = json.loads(raw)
            except json.JSONDecodeError as exc:
                raise GasCitySchemaError("Gas City status CLI returned invalid JSON") from exc
            return self._json_object(decoded, "status")

    async def snapshot(self) -> dict[str, Any]:
        status = await self.status()
        sessions = status.get("sessions", status.get("running_sessions", []))
        workflows = status.get("workflows", status.get("active_workflows", []))
        if not isinstance(sessions, list) or not isinstance(workflows, list):
            raise GasCitySchemaError("Gas City status sessions/workflows must be arrays")
        return {"status": status, "sessions": sessions, "workflows": workflows}

    async def sessions(self) -> list[Any]:
        return (await self.snapshot())["sessions"]

    async def workflows(self) -> list[Any]:
        return (await self.snapshot())["workflows"]

    async def mutate(self, method: str, path: str, payload: Mapping[str, Any] | None = None) -> Any:
        """Issue a REST mutation with the required request-confirmation header."""
        if method.upper() not in {"POST", "PUT", "PATCH", "DELETE"}:
            raise ValueError("mutations require POST, PUT, PATCH, or DELETE")
        return await self._request_api(
            "mutation", path, payload=payload, method=method.upper()
        )

    get_status = status
    list_sessions = sessions
    list_workflows = workflows
