import { describe, expect, test } from "bun:test";

import { applyUserApproval, localDestructiveTargetDecision } from "../pi/extensions/dcg-guard";

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
