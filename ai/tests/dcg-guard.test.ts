import { describe, expect, test } from "bun:test";

import { applyUserApproval, isBranchDelete, localDestructiveTargetDecision } from "../pi/extensions/dcg-guard";

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
  test.each([
    "git branch -d agent-work",
    "git branch -D agent-work",
    "git branch --delete --force agent-work",
    "git -C ../repo branch -d agent-work",
  ])("recognizes standalone branch deletion: %s", (command: string) => {
    expect(isBranchDelete(command)).toBe(true);
  });

  test.each(["git branch -f existing new-tip", "git branch -M old new", "git branch -d agent-work && git reset --hard"])(
    "does not treat other forced or compound branch operations as deletion: %s",
    (command: string) => {
      expect(isBranchDelete(command)).toBe(false);
    },
  );

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
