import { describe, expect, test } from "bun:test";

import { localDestructiveTargetDecision } from "../pi/extensions/dcg-guard";

const home = "/Users/example";

describe("local destructive target policy", () => {
  test.each([
    'trash "$dir"',
    'command trash -- "${target}"',
    'find "$path" -delete',
    'printf "%s\\0" "$tmp" | xargs -0 trash',
    'rm -rf "$HOME/.dotfiles"',
  ])("blocks variable-derived deletion: %s", (command) => {
    expect(localDestructiveTargetDecision(command, home).deny).toBe(true);
  });

  test.each(["trash /", `trash ${home}`, `trash "${home}/.dotfiles"`, `trash ${home}/.ssh`])(
    "blocks protected roots: %s",
    (command) => {
      expect(localDestructiveTargetDecision(command, home).deny).toBe(true);
    },
  );

  test.each([
    "trash /tmp/pi-progress.literal",
    `trash ${home}/Downloads/disposable`,
    'echo "$dir"',
    'printf "%s" "$dir"; trash /tmp/pi-progress.literal',
  ])("allows non-destructive or literal temp targets: %s", (command) => {
    expect(localDestructiveTargetDecision(command, home).deny).toBe(false);
  });
});
