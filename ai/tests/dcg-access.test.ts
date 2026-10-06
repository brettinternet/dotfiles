import { describe, expect, test } from "bun:test";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmdirSync,
  statSync,
  symlinkSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  localBashIntegrityDecision,
  localDestructiveTargetDecision,
  readAccessRoots,
  registerDirectoryAccess,
  updateAccessRoots,
} from "../pi/extensions/dcg-guard";

type API = Parameters<typeof registerDirectoryAccess>[0];
type Context = Parameters<ReturnType<typeof registerDirectoryAccess>>[1];

function fixture() {
  const base = realpathSync(mkdtempSync(join(tmpdir(), "dcg-access-")));
  const cwd = join(base, "project");
  const outside = join(base, "other project");
  const third = join(base, "third");
  for (const path of [cwd, outside, third]) mkdirSync(path);
  const file = join(base, "access.json");
  const entries: ReturnType<Context["sessionManager"]["getEntries"]> = [];
  const notifications: string[] = [];
  const choices: Array<string | undefined> = [];
  const prompts: string[] = [];
  let handler: (args: string, ctx: Context) => Promise<void>;
  const api: API = {
    events: { emit() {} },
    on() {},
    appendEntry(customType, data) {
      entries.push({ type: "custom", customType, data });
    },
    registerCommand(_name, command) {
      handler = command.handler;
    },
  };
  let sessionId = "session-one";
  const ctx: Context = {
    cwd,
    hasUI: true,
    sessionManager: { getSessionId: () => sessionId, getEntries: () => entries },
    ui: {
      confirm: async () => true,
      select: async (title) => {
        prompts.push(title);
        return choices.shift();
      },
      notify: (message) => {
        notifications.push(message);
      },
    },
  };
  let check = registerDirectoryAccess(api, file);
  return {
    base,
    cwd,
    outside,
    third,
    file,
    ctx,
    choices,
    prompts,
    entries,
    notifications,
    check: (command: string) => check({ command }, ctx),
    command: (args: string) => handler(args, ctx),
    reload: () => {
      check = registerDirectoryAccess(api, file);
    },
    switchSession: () => {
      sessionId = "session-two";
    },
    dispose() {
      for (const path of [file, `${file}.pending`]) if (existsSync(path)) unlinkSync(path);
      for (const path of [cwd, outside, third, base]) rmdirSync(path);
    },
  };
}

describe("directory access", () => {
  test("session commands take effect immediately, survive reload, and do not transfer to another session", async () => {
    const f = fixture();
    try {
      const command = `cd "${f.outside}" && rg needle .`;
      f.ctx.hasUI = false;
      expect((await f.check(command)).deny).toBe(true);
      f.ctx.hasUI = true;
      await f.command(`allow "${f.outside}"`);
      expect((await f.check(command)).deny).toBe(false);
      expect(existsSync(f.file)).toBe(false);
      f.reload();
      expect((await f.check(command)).deny).toBe(false);
      await f.command("list");
      expect(f.notifications.at(-1)).toContain(`Session: ${f.outside}`);
      f.switchSession();
      f.ctx.hasUI = false;
      expect((await f.check(command)).deny).toBe(true);
    } finally {
      f.dispose();
    }
  });

  test("revocation survives reload and new grants do not erase other session roots", async () => {
    const f = fixture();
    try {
      await f.command(`allow "${f.outside}"`);
      await f.command(`allow "${f.third}"`);
      await f.command(`revoke "${f.outside}"`);
      f.reload();
      f.ctx.hasUI = false;
      expect((await f.check(`rg needle "${f.outside}"`)).deny).toBe(true);
      expect((await f.check(`rg needle "${f.third}"`)).deny).toBe(false);
    } finally {
      f.dispose();
    }
  });

  test.each(["", "--permanent "])("revocation removes a replaced directory grant (%s)", async (scope) => {
    const f = fixture();
    try {
      await f.command(`allow ${scope}"${f.outside}"`);
      rmdirSync(f.outside);
      symlinkSync(f.third, f.outside);
      f.ctx.hasUI = false;
      expect((await f.check(`rg needle "${f.outside}"`)).deny).toBe(true);
      f.ctx.hasUI = true;
      await f.command(`revoke ${scope}"${f.outside}"`);
      unlinkSync(f.outside);
      mkdirSync(f.outside);
      f.reload();
      f.ctx.hasUI = false;
      expect((await f.check(`rg needle "${f.outside}"`)).deny).toBe(true);
    } finally {
      if (statSync(f.outside).isDirectory() && realpathSync(f.outside) !== f.outside) {
        unlinkSync(f.outside);
        mkdirSync(f.outside);
      }
      f.dispose();
    }
  });

  test("once approval is limited to one call and rechecks all paths", async () => {
    const f = fixture();
    try {
      f.choices.push("Allow once", "Deny");
      expect((await f.check(`rg needle "${f.outside}" "${f.third}"`)).deny).toBe(true);
      expect(f.prompts).toHaveLength(2);
      expect(f.entries).toHaveLength(0);
      f.choices.push("Allow once");
      expect((await f.check(`rg needle "${f.outside}"`)).deny).toBe(false);
      expect((await f.check(`rg needle "${f.outside}"`)).deny).toBe(true);
      expect(f.prompts).toHaveLength(4);
    } finally {
      f.dispose();
    }
  });

  test("session approval persists; malformed and dynamic commands never become promptable", async () => {
    const f = fixture();
    try {
      f.choices.push("Allow for this session");
      expect((await f.check(`grep -r needle "${f.outside}"`)).deny).toBe(false);
      f.reload();
      expect((await f.check(`rg -f "${f.outside}/patterns" .`)).deny).toBe(false);
      expect((await f.check(`rg needle "${f.outside}/*"`)).deny).toBe(true);
      expect((await f.check(`cd "${f.outside}"`)).deny).toBe(true);
      expect(f.prompts).toHaveLength(1);
      const destructive = `cd "${f.outside}" && rm important`;
      expect((await f.check(destructive)).deny).toBe(false);
      expect(localDestructiveTargetDecision(destructive).deny).toBe(true);
    } finally {
      f.dispose();
    }
  });

  test("permanent grants and revocations are picked up by existing and new sessions", async () => {
    const f = fixture();
    try {
      await f.command(`allow --permanent "${f.outside}"`);
      expect(statSync(f.file).mode & 0o777).toBe(0o600);
      f.switchSession();
      f.ctx.hasUI = false;
      expect((await f.check(`rg needle "${f.outside}"`)).deny).toBe(false);
      updateAccessRoots(f.file, f.third, true);
      expect((await f.check(`rg needle "${f.third}"`)).deny).toBe(false);
      f.ctx.hasUI = true;
      await f.command(`revoke --permanent "${f.outside}"`);
      f.ctx.hasUI = false;
      expect((await f.check(`rg needle "${f.outside}"`)).deny).toBe(true);
      expect(readAccessRoots(f.file)).toEqual([f.third]);
    } finally {
      f.dispose();
    }
  });

  test("cancelled or headless commands do not grant access, and missing targets do not prompt", async () => {
    const f = fixture();
    try {
      f.ctx.ui.confirm = async () => false;
      await f.command(`allow "${f.outside}"`);
      f.ctx.hasUI = false;
      await f.command(`allow --permanent "${f.outside}"`);
      f.ctx.hasUI = true;
      expect((await f.check(`rg needle "${f.outside}/missing"`)).deny).toBe(true);
      expect(f.prompts).toHaveLength(0);
      expect(f.entries).toHaveLength(0);
      expect(existsSync(f.file)).toBe(false);
    } finally {
      f.dispose();
    }
  });

  test("canonical boundaries reject siblings and symlink escapes, including missing descendants", async () => {
    const f = fixture();
    const link = join(f.outside, "escape");
    symlinkSync(f.third, link);
    try {
      const decide = (path: string) => localBashIntegrityDecision({ command: `rg needle "${path}"` }, f.cwd, [f.outside]);
      expect(decide(join(f.outside, "missing")).deny).toBe(false);
      expect(decide(`${f.outside}-sibling`).deny).toBe(true);
      expect(decide(link).deny).toBe(true);
      expect(decide(join(link, "missing")).deny).toBe(true);
    } finally {
      unlinkSync(link);
      f.dispose();
    }
  });

  test("persistent storage fails closed for invalid data, symlinks, and concurrent writers", async () => {
    const f = fixture();
    const linked = join(f.base, "linked.json");
    try {
      writeFileSync(f.file, "not json");
      expect(() => updateAccessRoots(f.file, f.outside, true)).toThrow();
      expect(readFileSync(f.file, "utf8")).toBe("not json");
      expect(existsSync(`${f.file}.pending`)).toBe(false);
      await expect(f.check("git status")).rejects.toThrow();
      writeFileSync(f.file, JSON.stringify({ version: 1, roots: ["relative"] }));
      expect(() => readAccessRoots(f.file)).toThrow();
      writeFileSync(f.file, JSON.stringify({ version: 1, roots: [] }));
      symlinkSync(f.file, linked);
      expect(() => readAccessRoots(linked)).toThrow();
      expect(() => updateAccessRoots(linked, f.outside, true)).toThrow();
      writeFileSync(`${f.file}.pending`, "owned by another writer");
      expect(() => updateAccessRoots(f.file, f.outside, true)).toThrow();
      expect(readFileSync(`${f.file}.pending`, "utf8")).toBe("owned by another writer");
      expect(readAccessRoots(f.file)).toEqual([]);
    } finally {
      if (existsSync(linked)) unlinkSync(linked);
      f.dispose();
    }
  });
});
