from __future__ import annotations

from pathlib import Path
import shutil
import subprocess
import tomllib


ROOT = Path(__file__).parents[2]


def run_sidecar_init(taskfile: Path, project: Path) -> None:
    result = subprocess.run(
        [
            "task",
            "--dir",
            str(project),
            "--taskfile",
            str(taskfile),
            "sidecar:init-config",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        raise AssertionError(
            f"sidecar:init-config failed with exit status {result.returncode}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )


def test_sidecar_init_config_creates_and_preserves_config(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    taskfile = project / "Taskfile.yaml"
    shutil.copy2(ROOT / "Taskfile.yaml", taskfile)
    sidecar = project / "city.sidecar.toml"

    run_sidecar_init(taskfile, project)

    assert tomllib.loads(sidecar.read_text(encoding="utf-8")) == {
        "workspace": {"max_active_sessions": 2}
    }

    operator_config = "[workspace]\nmax_active_sessions = 7\ncustom = true\n"
    sidecar.write_text(operator_config, encoding="utf-8")

    run_sidecar_init(taskfile, project)

    assert sidecar.read_text(encoding="utf-8") == operator_config
