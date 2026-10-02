import os
from pathlib import Path
import subprocess
import tempfile
import unittest


MANAGED_CONFIG = Path(__file__).resolve().parents[1] / ".gitconfig"


class GitConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gitconfig-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        # Do not inherit Git overrides, gh tokens, or paths to live credentials.
        self.env = {
            "PATH": os.environ["PATH"],
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "GH_CONFIG_DIR": str(self.home / ".config/gh"),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
            "GH_PROMPT_DISABLED": "1",
        }
        self.local = self.home / ".gitconfig.local"

    def run_command(self, *args, env=None):
        return subprocess.run(
            args, cwd=self.home, env=env or self.env,
            check=True, capture_output=True, text=True, timeout=30,
        ).stdout

    def test_missing_local_file_and_local_precedence(self):
        # Read the real managed config; no command in this test writes it.
        (self.home / ".gitconfig").symlink_to(MANAGED_CONFIG)
        baseline = self.run_command("git", "config", "--global", "--includes", "--get", "core.editor").strip()
        self.assertFalse(self.local.exists())
        override = baseline + "-local-test"
        self.local.write_text(f"[core]\n\teditor = {override}\n")
        self.assertEqual(
            self.run_command("git", "config", "--global", "--includes", "--get", "core.editor").strip(),
            override,
        )

    def test_gh_setup_git_respects_global_override(self):
        # Reproduce the installer symlink using only synthetic settings and the
        # managed include paths, never copying personal configuration or tokens.
        includes = self.run_command(
            "git", "config", "--file", str(MANAGED_CONFIG), "--get-all", "include.path",
        ).splitlines()
        managed = self.home / "managed.gitconfig"
        managed.write_text(
            "[credential]\n\thelper = test-helper\n"
            + "".join(f"[include]\n\tpath = {path}\n" for path in includes)
        )
        global_config = self.home / ".gitconfig"
        global_config.symlink_to(managed)
        before = managed.read_bytes()
        tracked_before = MANAGED_CONFIG.read_bytes()
        self.local.write_text("[core]\n\teditor = local-test-editor\n")
        env = dict(self.env, GIT_CONFIG_GLOBAL=str(self.local), GH_TOKEN="test-placeholder-not-a-token")
        self.run_command("gh", "auth", "setup-git", "--hostname", "github.com", env=env)
        self.assertTrue(global_config.is_symlink())
        self.assertEqual(managed.read_bytes(), before)
        self.assertEqual(MANAGED_CONFIG.read_bytes(), tracked_before)
        self.assertEqual(
            self.run_command("git", "config", "--file", str(self.local), "--get", "core.editor").strip(),
            "local-test-editor",
        )
        helpers = self.run_command(
            "git", "config", "--global", "--includes", "--get-all", "credential.https://github.com.helper",
        ).splitlines()
        self.assertEqual(helpers[0], "")  # Reset inherited helpers.
        self.assertEqual(len(helpers), 2)
        self.assertTrue(helpers[1].startswith("!"))
        self.assertTrue(helpers[1].endswith(" auth git-credential"))


if __name__ == "__main__":
    unittest.main()
