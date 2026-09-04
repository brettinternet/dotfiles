import { describe, expect, test } from "bun:test";

import { localDestructiveTargetDecision } from "../pi/extensions/dcg-guard";

const home = "/Users/example";

describe("local destructive target policy", () => {
  test.each([
    'trash "$dir"',
    'command trash -- "${target}"',
    'find "$path" -delete',
    'printf "%s\\0" "$tmp" | xargs -0 trash',
  ])("blocks variable-derived deletion: %s", (command: string) => {
    expect(localDestructiveTargetDecision(command, home).deny).toBe(true);
  });

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
