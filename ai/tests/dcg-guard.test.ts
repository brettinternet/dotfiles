import { describe, expect, test } from "bun:test";
import { mkdtempSync, realpathSync, rmdirSync, symlinkSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import {
  applyUserApproval,
  type GitOwnership,
  isLinkedGitCheckout,
  localBashIntegrityDecision,
  localDestructiveTargetDecision,
  resetGitOwnership,
} from "../pi/extensions/dcg-guard";

const home = "/Users/example";
const repoKey = "/Users/example/project/.git";
const managedCwd = "/Users/example/worktree";
const ownership: GitOwnership = {
  managedRoots: new Map([
    [managedCwd, repoKey],
    ["/Users/example/project/.worktrees/agent-task", repoKey],
  ]),
  repoRoots: new Map([
    ["/Users/example/project", repoKey],
    [managedCwd, repoKey],
    ["/Users/example/project/.worktrees/agent-task", repoKey],
  ]),
  managedBranches: new Set([
    `${repoKey}\0agent-work`,
    `${repoKey}\0agent-release`,
    `${repoKey}\0agent-task`,
  ]),
  protectedBranches: new Set([`${repoKey}\0main`]),
};

type TestDecision = { deny: boolean; reason: string; ruleId?: string };
type TestContext = { hasUI: boolean; ui: { confirm(title: string, message: string): Promise<boolean> } };

async function resolveTestCheckout(
  path: string,
): Promise<{ branch?: string; repoKey: string; root: string } | undefined> {
  const root = [...ownership.repoRoots.entries()]
    .map(([candidate, key]) => ({ candidate, key }))
    .filter(({ candidate }) => path === candidate || path.startsWith(`${candidate}/`))
    .sort((left, right) => right.candidate.length - left.candidate.length)[0];
  return root ? { repoKey: root.key, root: root.candidate } : undefined;
}

function applyManagedCleanup(
  decision: TestDecision,
  command: string,
  ctx: TestContext,
  events?: { emit(event: string, value: unknown): void },
  recheck?: (command: string) => Promise<TestDecision>,
): Promise<TestDecision> {
  return applyUserApproval(
    decision,
    command,
    { ...ctx, cwd: managedCwd },
    events,
    recheck,
    ownership,
    resolveTestCheckout,
  );
}

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

describe("Git ownership discovery", () => {
  test("distinguishes a linked worktree from a primary checkout with a separate Git directory", () => {
    expect(isLinkedGitCheckout({ gitDir: "/repo/.git/worktrees/task", repoKey: "/repo/.git" })).toBe(true);
    expect(isLinkedGitCheckout({ gitDir: "/external/repo.git", repoKey: "/external/repo.git" })).toBe(false);
  });

  test("clears stale managed branches when ownership is refreshed", () => {
    const stale: GitOwnership = {
      managedRoots: new Map([[managedCwd, repoKey]]),
      repoRoots: new Map([["/Users/example/project", repoKey]]),
      managedBranches: new Set([`${repoKey}\0agent-work`]),
      protectedBranches: new Set([`${repoKey}\0main`]),
    };

    resetGitOwnership(stale);

    expect(stale.managedRoots.size).toBe(0);
    expect(stale.repoRoots.size).toBe(0);
    expect(stale.managedBranches.size).toBe(0);
    expect(stale.protectedBranches.size).toBe(0);
  });
});

describe("dcg user approval", () => {
  test("allows branch deletion when every other command passes dcg", async () => {
    const checked: string[] = [];
    const command =
      "cd /Users/example/project && git branch -d agent-work && git worktree prune && git status --short --branch && git rev-parse HEAD &&\n git rev-parse origin/main && gh run view 123 --json status,conclusion";
    const decision = await applyManagedCleanup(
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
      "cd /Users/example/project",
      "git worktree prune",
      "git status --short --branch",
      "git rev-parse HEAD",
      "git rev-parse origin/main",
      "gh run view 123 --json status,conclusion",
    ]);
  });

  test("allows forced branch update alongside other literal cleanup commands", async () => {
    const checked: string[] = [];
    const command =
      "cd /Users/example/project/.worktrees/agent-task && git restore -- tracked && git diff old new -- file.go > /tmp/agent-recovery.patch && git switch --detach new && git branch -f agent-task new && git switch agent-task && git apply /tmp/agent-recovery.patch && git status --short --branch && git diff --check";
    const decision = await applyManagedCleanup(
      {
        deny: true,
        reason: "git branch deletion or forced ref updates require explicit user approval.",
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
    expect(checked).not.toContain("git restore -- tracked");
    expect(checked).not.toContain("git branch -f agent-task new");
    expect(checked).toContain("git apply /tmp/agent-recovery.patch");
  });

  test("allows branch deletion followed by piped inspection commands", async () => {
    const checked: string[] = [];
    const decision = await applyManagedCleanup(
      {
        deny: true,
        reason: "git branch deletion requires explicit user approval.",
        ruleId: "core.git:branch-force-delete",
      },
      "git branch -d agent-work && worklease checkpoint --help | head -80 && worklease release --help | head -80",
      { hasUI: false, ui: { confirm: async () => false } },
      undefined,
      async (clause) => {
        checked.push(clause);
        return { deny: false, reason: "" };
      },
    );

    expect(decision.deny).toBe(false);
    expect(checked).toEqual([
      "worklease checkpoint --help",
      "head -80",
      "worklease release --help",
      "head -80",
    ]);
  });

  test("allows guarded branch deletion in a shell conditional", async () => {
    const checked: string[] = [];
    const command =
      "cd /Users/example/project && git worktree prune && if git show-ref --verify --quiet refs/heads/agent-release; then git branch -d agent-release; fi; git worktree list --porcelain; git status --short --branch; git log -3 --oneline";
    const decision = await applyManagedCleanup(
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
    expect(checked).not.toContain("then git branch -d agent-release");
    expect(checked).toContain("if git show-ref --verify --quiet refs/heads/agent-release");
  });

  test("allows literal worktree restore when every other command passes dcg", async () => {
    const checked: string[] = [];
    const command =
      `git restore -- "docs/backlog/tasks/task-59 - Add-a-local-claim-history-ledger.md" && cd /Users/example/worktree && backlog task edit TASK-59 --plan $'1. Verify.\n2. Run checks.' --plain >/dev/null && printf '%s\\n' '--- WORKTREE ---' && git status --short --branch`;
    const decision = await applyManagedCleanup(
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

  test("does not exempt restore targeting the primary checkout through git -C", async () => {
    const blocked = {
      deny: true,
      reason: "git restore discards uncommitted changes.",
      ruleId: "core.git:restore-worktree",
    };
    const decision = await applyManagedCleanup(
      blocked,
      "git -C /Users/example/project restore docs/allowlist.tsv",
      { hasUI: false, ui: { confirm: async () => false } },
    );

    expect(decision).toEqual(blocked);
  });

  test("allows literal restore through the rtk wrapper", async () => {
    const checked: string[] = [];
    const decision = await applyManagedCleanup(
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

  test("allows literal checkout discard when every other command passes dcg", async () => {
    const checked: string[] = [];
    const decision = await applyManagedCleanup(
      {
        deny: true,
        reason: "git checkout -- discards uncommitted changes permanently.",
        ruleId: "core.git:checkout-discard",
      },
      "git checkout -- server/server.go && mise exec go -- go test ./server -run '^TestBack265' -count=1",
      { hasUI: false, ui: { confirm: async () => false } },
      undefined,
      async (clause) => {
        checked.push(clause);
        return { deny: false, reason: "" };
      },
    );

    expect(decision.deny).toBe(false);
    expect(checked).toEqual(["mise exec go -- go test ./server -run '^TestBack265' -count=1"]);
  });

  test("allows hard reset to a literal revision when every other command passes dcg", async () => {
    const checked: string[] = [];
    const decision = await applyManagedCleanup(
      {
        deny: true,
        reason: "git reset --hard destroys uncommitted changes.",
        ruleId: "core.git:reset-hard",
      },
      "git reset --hard 6a92441 && git status --short --branch && git log -1 --oneline",
      { hasUI: false, ui: { confirm: async () => false } },
      undefined,
      async (clause) => {
        checked.push(clause);
        return { deny: false, reason: "" };
      },
    );

    expect(decision.deny).toBe(false);
    expect(checked).toEqual(["git status --short --branch", "git log -1 --oneline"]);
  });

  test("does not exempt reset in the primary checkout", async () => {
    const blocked = {
      deny: true,
      reason: "git reset --hard destroys uncommitted changes.",
      ruleId: "core.git:reset-hard",
    };
    const decision = await applyUserApproval(
      blocked,
      "git reset --hard HEAD",
      { hasUI: false, ui: { confirm: async () => false }, cwd: "/Users/example/project" },
      undefined,
      undefined,
      ownership,
      resolveTestCheckout,
    );

    expect(decision).toEqual(blocked);
  });

  test("does not exempt restore in the primary checkout", async () => {
    const blocked = {
      deny: true,
      reason: "git restore discards uncommitted changes.",
      ruleId: "core.git:restore-worktree",
    };
    const decision = await applyUserApproval(
      blocked,
      "git restore -- tracked-file",
      { hasUI: false, ui: { confirm: async () => false }, cwd: "/Users/example/project" },
      undefined,
      undefined,
      ownership,
      resolveTestCheckout,
    );

    expect(decision).toEqual(blocked);
  });

  test("does not exempt deletion of a protected branch", async () => {
    const blocked = {
      deny: true,
      reason: "git branch deletion requires explicit user approval.",
      ruleId: "core.git:branch-force-delete",
    };
    const decision = await applyUserApproval(
      blocked,
      "git branch -D main",
      { hasUI: false, ui: { confirm: async () => false }, cwd: managedCwd },
      undefined,
      undefined,
      ownership,
      resolveTestCheckout,
    );

    expect(decision).toEqual(blocked);
  });

  test.each([
    "git branch -D user-feature",
    "git branch -r -D origin/main",
    "git branch -f main HEAD~1",
  ])("does not exempt an unowned, remote, or default branch: %s", async (command) => {
    const blocked = {
      deny: true,
      reason: "git branch deletion or forced ref updates require explicit user approval.",
      ruleId: "core.git:branch-force-delete",
    };
    const decision = await applyUserApproval(
      blocked,
      command,
      { hasUI: false, ui: { confirm: async () => false }, cwd: managedCwd },
      undefined,
      undefined,
      ownership,
      resolveTestCheckout,
    );

    expect(decision).toEqual(blocked);
  });

  test.each([
    'git -C "$HOME/.dotfiles" reset --hard HEAD',
    "pushd /Users/example/project && git reset --hard HEAD",
    "move_to_primary() { cd /Users/example/project; }; move_to_primary; git reset --hard HEAD",
  ])("does not exempt cleanup after a dynamic target or unmodelled cwd change: %s", async (command) => {
    const blocked = {
      deny: true,
      reason: "git reset --hard destroys uncommitted changes.",
      ruleId: "core.git:reset-hard",
    };
    const decision = await applyUserApproval(
      blocked,
      command,
      { hasUI: false, ui: { confirm: async () => false }, cwd: managedCwd },
      undefined,
      undefined,
      ownership,
      resolveTestCheckout,
    );

    expect(decision).toEqual(blocked);
  });

  test("validates branch names after the option terminator", async () => {
    const blocked = {
      deny: true,
      reason: "git branch deletion requires explicit user approval.",
      ruleId: "core.git:branch-force-delete",
    };
    const decision = await applyUserApproval(
      blocked,
      "git branch -D agent-work -- -user-owned",
      { hasUI: false, ui: { confirm: async () => false }, cwd: managedCwd },
      undefined,
      undefined,
      ownership,
      resolveTestCheckout,
    );

    expect(decision).toEqual(blocked);
  });

  test("does not exempt cleanup in an unknown linked checkout", async () => {
    const blocked = {
      deny: true,
      reason: "git restore discards uncommitted changes.",
      ruleId: "core.git:restore-worktree",
    };
    const decision = await applyUserApproval(
      blocked,
      "git restore -- .",
      { hasUI: false, ui: { confirm: async () => false }, cwd: "/Users/example/unknown-worktree" },
      undefined,
      undefined,
      ownership,
      resolveTestCheckout,
    );

    expect(decision).toEqual(blocked);
  });

  test("does not exempt cleanup in a nested unowned repository", async () => {
    const blocked = {
      deny: true,
      reason: "git reset --hard destroys uncommitted changes.",
      ruleId: "core.git:reset-hard",
    };
    const decision = await applyUserApproval(
      blocked,
      "git -C nested-repo reset --hard HEAD",
      { hasUI: false, ui: { confirm: async () => false }, cwd: managedCwd },
      undefined,
      undefined,
      ownership,
      async () => ({ repoKey: "/nested/.git", root: `${managedCwd}/nested-repo` }),
    );

    expect(decision).toEqual(blocked);
  });

  test("does not exempt cleanup through a symlink to an unowned checkout", async () => {
    const managedRoot = mkdtempSync(join(tmpdir(), "dcg-owned-worktree-"));
    const outsideRoot = mkdtempSync(join(tmpdir(), "dcg-unowned-worktree-"));
    const link = join(managedRoot, "outside-link");
    symlinkSync(outsideRoot, link);
    const temporaryOwnership: GitOwnership = {
      managedRoots: new Map([[managedRoot, repoKey]]),
      repoRoots: new Map([[outsideRoot, "/outside/.git"]]),
      managedBranches: new Set(),
      protectedBranches: new Set(),
    };
    const blocked = {
      deny: true,
      reason: "git restore discards uncommitted changes.",
      ruleId: "core.git:restore-worktree",
    };

    try {
      const decision = await applyUserApproval(
        blocked,
        `git -C ${link} restore -- .`,
        { hasUI: false, ui: { confirm: async () => false }, cwd: managedRoot },
        undefined,
        undefined,
        temporaryOwnership,
        async (path) => ({ repoKey: "/outside/.git", root: realpathSync(path) }),
      );
      expect(decision).toEqual(blocked);
    } finally {
      unlinkSync(link);
      rmdirSync(managedRoot);
      rmdirSync(outsideRoot);
    }
  });

  test("does not let branch deletion hide another destructive command", async () => {
    const forcePushDecision = {
      deny: true,
      reason: "force push requires explicit user approval.",
      ruleId: "core.git:force-push",
    };
    const decision = await applyManagedCleanup(
      {
        deny: true,
        reason: "git branch deletion requires explicit user approval.",
        ruleId: "core.git:branch-force-delete",
      },
      "git branch -d agent-work && git push --force",
      { hasUI: false, ui: { confirm: async () => false } },
      undefined,
      async () => forcePushDecision,
    );

    expect(decision).toEqual(forcePushDecision);
  });

  test("allows merged-only branch deletion without prompting", async () => {
    let prompted = false;
    const decision = await applyManagedCleanup(
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
    const decision = await applyManagedCleanup(
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
        reason: "force push requires explicit user approval.",
        ruleId: "core.git:force-push",
      },
      "git push --force",
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
      reason: "force push requires explicit user approval.",
      ruleId: "core.git:force-push",
    };
    const declined = await applyUserApproval(blocked, "git push --force", {
      hasUI: true,
      ui: { confirm: async () => false },
    });
    const headless = await applyUserApproval(blocked, "git push --force", {
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
