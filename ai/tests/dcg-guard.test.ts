import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmdirSync, symlinkSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import {
  applyUserApproval,
  localBashIntegrityDecision,
  localDestructiveTargetDecision,
} from "../pi/extensions/dcg-guard";

const home = "/Users/example";

describe("local destructive target policy", () => {
  test.each(['trash "$dir"', 'command trash -- "${target}"', 'find "$path" -delete', 'printf "%s\\0" "$tmp" | xargs -0 trash'])(
    "blocks variable-derived deletion: %s",
    (command: string) => {
      expect(localDestructiveTargetDecision(command, home).deny).toBe(true);
    },
  );

  test.each([
    "rm file.txt",
    "command rm -- file.txt",
    "/bin/rm /tmp/file.txt",
    "find . -name '*.tmp' -exec rm {} +",
    "find . -print0 | xargs -0 rm",
  ])("blocks all rm invocations: %s", (command: string) => {
    const decision = localDestructiveTargetDecision(command, home);
    expect(decision.deny).toBe(true);
    expect(decision.reason).toContain("Use `trash` instead");
  });

  test.each(["trash /", `trash ${home}`, `trash "${home}/.dotfiles"`, `trash ${home}/.ssh`])(
    "blocks protected roots: %s",
    (command: string) => {
      expect(localDestructiveTargetDecision(command, home).deny).toBe(true);
    },
  );

  test.each([
    "trash /tmp/pi-progress.literal",
    `trash ${home}/Downloads/disposable`,
    'echo "$dir"',
    'printf "%s" "$dir"; trash /tmp/pi-progress.literal',
  ])("allows non-destructive or literal temp targets: %s", (command: string) => {
    expect(localDestructiveTargetDecision(command, home).deny).toBe(false);
  });
});

describe("local Bash integrity policy", () => {
  const cwd = process.cwd();

  test("rejects unknown tool argument keys", () => {
    const decision = localBashIntegrityDecision({ "command magnificence Fox": "cd /reit" }, cwd);

    expect(decision).toEqual({
      deny: true,
      reason: "Blocked unknown Bash argument keys: command magnificence Fox.",
    });
  });

  test.each(["cd / jokes", "cd /roch", "cd / yen", "cd /Users Blocks"])(
    "rejects suspicious command-only directory changes: %s",
    (command: string) => {
      expect(localBashIntegrityDecision({ command }, cwd).deny).toBe(true);
    },
  );

  test.each([
    "rg -n 'stale_revision|revision_conflict' /Usersnergies",
    "rg -n 'stale_revision|revision_conflict' /Users/brett/dev/FMresso",
    "rg -n needle /Usersnergies | head -20",
  ])("rejects searches outside the session root: %s", (command: string) => {
    const decision = localBashIntegrityDecision({ command }, cwd);

    expect(decision.deny).toBe(true);
    expect(decision.reason).toContain("outside the session root");
  });

  test.each([
    "rg -n secret ../outside",
    "grep -r secret ../outside",
    "rg -f ../outside/patterns .",
    "LC_ALL=C rg -n secret /Usersnergies",
    "$(printf 'rg -n secret ../outside')",
    `rg "$(rg -n secret ../outside)" .`,
    "true & rg -n secret ../outside",
    "rg -n secret ~/outside",
  ])("rejects alternate outside-root search forms: %s", (command: string) => {
    expect(localBashIntegrityDecision({ command }, cwd).deny).toBe(true);
  });

  test("rejects a search through a symlink outside the session root", () => {
    const root = mkdtempSync(join(tmpdir(), "dcg-guard-root-"));
    const outside = mkdtempSync(join(tmpdir(), "dcg-guard-outside-"));
    const link = join(root, "outside-link");
    symlinkSync(outside, link);

    try {
      expect(localBashIntegrityDecision({ command: "rg -n secret outside-link" }, root).deny).toBe(true);
    } finally {
      unlinkSync(link);
      rmdirSync(root);
      rmdirSync(outside);
    }
  });

  test("allows slash-prefixed patterns and paths within the session root", () => {
    const commands = [`rg -n '/api/v1' ai`, `rg -e '/api/v1' ai`, `rg -n needle ${cwd}/ai`];

    for (const command of commands) {
      expect(localBashIntegrityDecision({ command, timeout: 30 }, cwd).deny).toBe(false);
    }
  });

  test("allows a chained directory change and search within the session root", () => {
    const command = `cd ${cwd}/ai && rg -n dcg-guard tests`;

    expect(localBashIntegrityDecision({ command, timeout: 30 }, cwd).deny).toBe(false);
  });

  test("allows ordinary Bash commands without path-bearing searches", () => {
    expect(localBashIntegrityDecision({ command: "git status --short && bun --version" }, cwd).deny).toBe(false);
  });
});

describe("dcg user approval", () => {
  test("allows branch deletion when every other command passes dcg", async () => {
    const checked: string[] = [];
    const command =
      "cd /Users/example/dev/project && git branch -d agent-work && git worktree prune && git status --short --branch && git rev-parse HEAD &&\n git rev-parse origin/main && gh run view 123 --json status,conclusion";
    const decision = await applyUserApproval(
      {
        deny: true,
        reason: "git branch deletion requires explicit user approval.",
        ruleId: "core.git:branch-force-delete",
      },
      command,
      { hasUI: false, ui: { confirm: async () => false } },
      undefined,
      async (clause) => {
        checked.push(clause);
        return { deny: false, reason: "" };
      },
    );

    expect(decision.deny).toBe(false);
    expect(checked).toEqual([
      "cd /Users/example/dev/project",
      "git worktree prune",
      "git status --short --branch",
      "git rev-parse HEAD",
      "git rev-parse origin/main",
      "gh run view 123 --json status,conclusion",
    ]);
  });

  test("allows literal worktree restore when every other command passes dcg", async () => {
    const checked: string[] = [];
    const command =
      `git restore -- "docs/backlog/tasks/task-59 - Add-a-local-claim-history-ledger.md" && cd /Users/example/worktree && backlog task edit TASK-59 --plan $'1. Verify.\n2. Run checks.' --plain >/dev/null && printf '%s\\n' '--- WORKTREE ---' && git status --short --branch`;
    const decision = await applyUserApproval(
      {
        deny: true,
        reason: "git restore discards uncommitted changes.",
        ruleId: "core.git:restore-worktree",
      },
      command,
      { hasUI: false, ui: { confirm: async () => false } },
      undefined,
      async (clause) => {
        checked.push(clause);
        return { deny: false, reason: "" };
      },
    );

    expect(decision.deny).toBe(false);
    expect(checked).toHaveLength(4);
    expect(checked[1]).toContain("$'1. Verify.\n2. Run checks.'");
  });

  test("allows literal restore without a path separator in a compound command", async () => {
    const checked: string[] = [];
    const command =
      "cp /Users/example/project/docs/allowlist.tsv /Users/example/project/.worktrees/agent-task/docs/allowlist.tsv && git -C /Users/example/project restore docs/allowlist.tsv && cd /Users/example/project/.worktrees/agent-task && mise exec go -- gofmt -w internal/identity_guard_test.go && git status --short && git diff --check";
    const decision = await applyUserApproval(
      {
        deny: true,
        reason: "git restore discards uncommitted changes.",
        ruleId: "core.git:restore-worktree",
      },
      command,
      { hasUI: false, ui: { confirm: async () => false } },
      undefined,
      async (clause) => {
        checked.push(clause);
        return { deny: false, reason: "" };
      },
    );

    expect(decision.deny).toBe(false);
    expect(checked).toEqual([
      "cp /Users/example/project/docs/allowlist.tsv /Users/example/project/.worktrees/agent-task/docs/allowlist.tsv",
      "cd /Users/example/project/.worktrees/agent-task",
      "mise exec go -- gofmt -w internal/identity_guard_test.go",
      "git status --short",
      "git diff --check",
    ]);
  });

  test("allows literal restore through the rtk wrapper", async () => {
    const checked: string[] = [];
    const decision = await applyUserApproval(
      {
        deny: true,
        reason: "git restore discards uncommitted changes.",
        ruleId: "core.git:restore-worktree",
      },
      "rtk git diff -- .mcp.json && rtk git restore -- .mcp.json && rtk git status --short",
      { hasUI: false, ui: { confirm: async () => false } },
      undefined,
      async (clause) => {
        checked.push(clause);
        return { deny: false, reason: "" };
      },
    );

    expect(decision.deny).toBe(false);
    expect(checked).toEqual(["rtk git diff -- .mcp.json", "rtk git status --short"]);
  });

  test("does not exempt restore with a variable-derived path", async () => {
    let rechecked = false;
    const blocked = {
      deny: true,
      reason: "git restore discards uncommitted changes.",
      ruleId: "core.git:restore-worktree",
    };
    const decision = await applyUserApproval(
      blocked,
      'git restore -- "$changed_file"',
      { hasUI: false, ui: { confirm: async () => false } },
      undefined,
      async () => {
        rechecked = true;
        return { deny: false, reason: "" };
      },
    );

    expect(decision).toEqual(blocked);
    expect(rechecked).toBe(false);
  });

  test("does not let branch deletion hide another destructive command", async () => {
    const resetDecision = {
      deny: true,
      reason: "hard reset requires explicit user approval.",
      ruleId: "core.git:reset-hard",
    };
    const decision = await applyUserApproval(
      {
        deny: true,
        reason: "git branch deletion requires explicit user approval.",
        ruleId: "core.git:branch-force-delete",
      },
      "git branch -d agent-work && git reset --hard",
      { hasUI: false, ui: { confirm: async () => false } },
      undefined,
      async () => resetDecision,
    );

    expect(decision).toEqual(resetDecision);
  });

  test("allows merged-only branch deletion without prompting", async () => {
    let prompted = false;
    const decision = await applyUserApproval(
      {
        deny: true,
        reason: "git branch deletion requires explicit user approval.",
        ruleId: "core.git:branch-force-delete",
      },
      "git branch -d agent-work",
      {
        hasUI: true,
        ui: {
          async confirm() {
            prompted = true;
            return false;
          },
        },
      },
    );

    expect(decision.deny).toBe(false);
    expect(prompted).toBe(false);
  });

  test("allows forced branch deletion without UI", async () => {
    const decision = await applyUserApproval(
      {
        deny: true,
        reason: "git branch deletion requires explicit user approval.",
        ruleId: "core.git:branch-force-delete",
      },
      "git branch -D agent-work",
      {
        hasUI: false,
        ui: { confirm: async () => false },
      },
    );

    expect(decision.deny).toBe(false);
  });

  test("reports the approval lifecycle for Herdr", async () => {
    const lifecycle: Array<{ event: string; value: unknown }> = [];
    const decision = await applyUserApproval(
      {
        deny: true,
        reason: "hard reset requires explicit user approval.",
        ruleId: "core.git:reset-hard",
      },
      "git reset --hard",
      {
        hasUI: true,
        ui: { confirm: async () => true },
      },
      { emit: (event, value) => lifecycle.push({ event, value }) },
    );

    expect(decision.deny).toBe(false);
    expect(lifecycle).toEqual([
      {
        event: "herdr:blocked",
        value: { active: true, label: "Destructive Git approval required" },
      },
      { event: "herdr:blocked", value: { active: false } },
    ]);
  });

  test("blocks destructive Git operations when approval is declined or unavailable", async () => {
    const blocked = {
      deny: true,
      reason: "hard reset requires explicit user approval.",
      ruleId: "core.git:reset-hard",
    };
    const declined = await applyUserApproval(blocked, "git reset --hard", {
      hasUI: true,
      ui: { confirm: async () => false },
    });
    const headless = await applyUserApproval(blocked, "git reset --hard", {
      hasUI: false,
      ui: { confirm: async () => true },
    });

    expect(declined).toEqual({ deny: true, reason: "Blocked by user." });
    expect(headless).toEqual(blocked);
  });

  test("does not make non-Git dcg denials promptable", async () => {
    let prompted = false;
    const blocked = {
      deny: true,
      reason: "filesystem operation blocked",
      ruleId: "core.filesystem:unlink-general",
    };
    const decision = await applyUserApproval(blocked, "unlink important-file", {
      hasUI: true,
      ui: {
        async confirm() {
          prompted = true;
          return true;
        },
      },
    });

    expect(decision).toEqual(blocked);
    expect(prompted).toBe(false);
  });
});
