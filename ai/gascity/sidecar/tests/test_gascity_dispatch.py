from __future__ import annotations

import asyncio
from pathlib import Path
from typing import Any

import pytest

from gascity_sidecar.gascity import (
    GasCityClient,
    GasCityCommandError,
    GasCitySchemaError,
)


class _Process:
    def __init__(self, returncode: int, stdout: bytes = b"", stderr: bytes = b""):
        self.returncode = returncode
        self._stdout = stdout
        self._stderr = stderr

    async def communicate(self) -> tuple[bytes, bytes]:
        return self._stdout, self._stderr


def test_dispatch_workflow_uses_exact_gc_argv_and_parses_json(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    calls: list[tuple[tuple[Any, ...], dict[str, Any]]] = []

    async def spawn(*args: Any, **kwargs: Any) -> _Process:
        calls.append((args, kwargs))
        return _Process(0, b'{"workflow_id":"wf-7","status":"queued"}')

    monkeypatch.setattr(asyncio, "create_subprocess_exec", spawn)
    client = GasCityClient(city_path=tmp_path, cli_command="gc")

    result = asyncio.run(client.dispatch_workflow("builder", "BD-7", 3))

    assert result == {"workflow_id": "wf-7", "status": "queued"}
    assert len(calls) == 1
    argv, kwargs = calls[0]
    assert argv == (
        "gc",
        "--city",
        str(tmp_path),
        "sling",
        "builder",
        "backlog-item",
        "--formula",
        "--var",
        "item=BD-7",
        "--var",
        "max_repair_attempts=3",
        "--json",
    )
    assert kwargs["stdout"] is asyncio.subprocess.PIPE
    assert kwargs["stderr"] is asyncio.subprocess.PIPE
    assert kwargs["cwd"] == str(tmp_path)
    assert "shell" not in kwargs


def test_dispatch_workflow_propagates_command_failure(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    async def spawn(*args: Any, **kwargs: Any) -> _Process:
        return _Process(17, stderr=b"dispatch failed")

    monkeypatch.setattr(asyncio, "create_subprocess_exec", spawn)
    client = GasCityClient(city_path=tmp_path)

    with pytest.raises(GasCityCommandError) as raised:
        asyncio.run(client.dispatch_workflow("builder", "BD-7", 0))

    assert raised.value.category == "dispatch"
    assert raised.value.returncode == 17
    assert raised.value.stderr == "dispatch failed"


@pytest.mark.parametrize("stdout", [b"not json", b"[]"])
def test_dispatch_workflow_rejects_invalid_or_non_object_json(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, stdout: bytes
) -> None:
    async def spawn(*args: Any, **kwargs: Any) -> _Process:
        return _Process(0, stdout=stdout)

    monkeypatch.setattr(asyncio, "create_subprocess_exec", spawn)
    client = GasCityClient(city_path=tmp_path)

    with pytest.raises(GasCitySchemaError):
        asyncio.run(client.dispatch_workflow("builder", "BD-7", 0))


@pytest.mark.parametrize(
    ("target", "bead_id", "max_repair_attempts", "message"),
    [
        ("", "BD-7", 0, "target"),
        ("builder", "", 0, "bead_id"),
        ("builder", "BD-7", -1, "max_repair_attempts"),
        ("builder", "BD-7", 101, "max_repair_attempts"),
        ("builder", "BD-7", True, "max_repair_attempts"),
    ],
)
def test_dispatch_workflow_validates_inputs(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    target: str,
    bead_id: str,
    max_repair_attempts: int,
    message: str,
) -> None:
    async def spawn(*args: Any, **kwargs: Any) -> _Process:
        pytest.fail("dispatch validation must happen before starting gc")

    monkeypatch.setattr(asyncio, "create_subprocess_exec", spawn)
    client = GasCityClient(city_path=tmp_path)

    with pytest.raises(ValueError, match=message):
        asyncio.run(client.dispatch_workflow(target, bead_id, max_repair_attempts))
