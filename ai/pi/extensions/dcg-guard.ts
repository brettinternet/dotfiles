// dotfiles-dcg-shell-guard
import { spawn } from "node:child_process";
import { existsSync, realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, join, relative, resolve } from "node:path";
type ApprovalContext = {
  hasUI: boolean;
  ui: { confirm(title: string, message: string): Promise<boolean> };
};

type ToolCallContext = ApprovalContext & { cwd: string };

type ApprovalEvents = {
  emit(event: string, value: unknown): void;
};

type ExtensionAPI = {
  events: ApprovalEvents;
  on(
    event: "tool_call",
    handler: (
      event: { toolName: string; input?: Record<string, unknown> },
      ctx: ToolCallContext,
    ) => Promise<{ block: true; reason: string } | undefined>,
  ): void;
};

const DCG_BIN =
  process.env.DCG_BIN ?? join(homedir(), ".local/share/mise/installs/github-dicklesworthstone-destructive-command-guard/latest/dcg");
const UNAVAILABLE = { deny: true, reason: "Blocked because the dcg safety guard is unavailable." };
const ALLOW = { deny: false, reason: "" };

type Decision = { deny: boolean; reason: string; ruleId?: string };

const GIT_COMMAND =
  /^\s*(?:(?:then|do|else)\s+)?(?:rtk\s+)?git(?:\s+-C\s+(?:"[^"]*"|'[^']*'|\S+))*\s+([a-z-]+)(?:\s+([^;&|\n]*))?\s*$/;
const DELETE_OPTION = /(?:^|\s)(?:-d|-D|--delete)(?:\s|$)/;
const FORCE_BRANCH_UPDATE = /^(?:-f|--force)\s+\S+(?:\s+\S+)?$/;
const EXEMPTED_GIT_RULES = new Set([
  "core.git:branch-force-delete",
  "core.git:restore-worktree",
  "core.git:checkout-discard",
  "core.git:reset-hard",
]);

type CommandSequence = { exempted: boolean; remainder: string[] };
type Quote = "single" | "double" | "ansi";

function splitShellSequence(command: string, allowPipes = false): string[] | undefined {
  const clauses: string[] = [];
  let start = 0;
  let quote: Quote | undefined;
  let escaped = false;

  for (let index = 0; index < command.length; index += 1) {
    const character = command[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (character === "\\" && quote !== "single") {
      escaped = true;
      continue;
    }
    if (quote) {
      const closesDouble = quote === "double" && character === '"';
      const closesSingle = (quote === "single" || quote === "ansi") && character === "'";
      if (closesDouble || closesSingle) quote = undefined;
      else if (quote !== "single" && (character === "`" || (character === "$" && command[index + 1] === "(")))
        return undefined;
      continue;
    }
    if (character === '"') {
      quote = "double";
      continue;
    }
    if (character === "'") {
      quote = index > 0 && command[index - 1] === "$" ? "ansi" : "single";
      continue;
    }
    if (character === "`" || (character === "$" && command[index + 1] === "(")) return undefined;
    if (character === "|" && !allowPipes) return undefined;

    const separatorLength =
      character === "&"
        ? command[index + 1] === "&"
          ? 2
          : allowPipes
            ? 1
            : 0
        : character === "|"
          ? command[index + 1] === "|" || command[index + 1] === "&"
            ? 2
            : 1
          : character === ";" || character === "\n"
            ? 1
            : 0;
    if (!separatorLength) continue;

    clauses.push(command.slice(start, index).trim());
    index += separatorLength - 1;
    start = index + 1;
  }

  if (quote || escaped) return undefined;
  clauses.push(command.slice(start).trim());
  return clauses.filter(Boolean);
}

function isLiteralRestore(arguments_: string): boolean {
  const trimmed = arguments_.trim();
  if (!trimmed || VARIABLE_REFERENCE.test(trimmed)) return false;
  if (trimmed.startsWith("--")) return /^--\s+\S/.test(trimmed);
  return !trimmed.startsWith("-");
}

function isExemptedGitClause(command: string): boolean {
  const match = command.match(GIT_COMMAND);
  if (!match) return false;

  const [, subcommand, arguments_ = ""] = match;
  if (subcommand === "branch") {
    return (
      DELETE_OPTION.test(arguments_) ||
      (FORCE_BRANCH_UPDATE.test(arguments_) && !VARIABLE_REFERENCE.test(arguments_))
    );
  }
  if (subcommand === "restore") return isLiteralRestore(arguments_);
  if (subcommand === "checkout") return /^--\s+\S/.test(arguments_) && !VARIABLE_REFERENCE.test(arguments_);
  if (subcommand === "reset") {
    return /^--hard(?:\s+\S+)?$/.test(arguments_) && !VARIABLE_REFERENCE.test(arguments_);
  }
  return false;
}

function parseCommandSequence(command: string): CommandSequence {
  const clauses = splitShellSequence(command, true);
  if (!clauses) return { exempted: false, remainder: [] };

  let exempted = false;
  const remainder: string[] = [];
  for (const clause of clauses) {
    if (isExemptedGitClause(clause)) {
      exempted = true;
    } else {
      remainder.push(clause);
    }
  }
  return { exempted, remainder };
}

const VARIABLE_REFERENCE = /(^|[^\\])\$(?:[A-Za-z_][A-Za-z0-9_]*|\{[^}]+\}|[0-9@*#?!$(-])/;
const RM_COMMAND =
  /(?:^|[|&(]\s*)(?:(?:command|builtin|sudo)\s+)*(?:\/[^\s]+\/)?rm\b|\bfind\b[^\n]*-exec\s+(?:\/[^\s]+\/)?rm\b|\bxargs\b[^\n]*(?:\/[^\s]+\/)?rm\b/;
const DELETE_COMMAND =
  /(?:^|[|&(]\s*)(?:(?:command|builtin|sudo)\s+)*(?:\/[^\s]+\/)?(?:rm|trash)\b|\bfind\b[^\n]*(?:-delete|-exec\s+(?:\/[^\s]+\/)?(?:rm|trash)\b)|\bxargs\b[^\n]*(?:\/[^\s]+\/)?(?:rm|trash)\b/;
const PATH_SCOPED_SEARCH_COMMANDS = new Set(["grep", "rg"]);
type SearchOptionSpec = { values: Set<string>; patterns: Set<string>; files: Set<string> };
const SEARCH_OPTION_SPECS: Record<string, SearchOptionSpec> = {
  rg: {
    values: new Set([
      "-A",
      "-B",
      "-C",
      "-E",
      "-e",
      "-f",
      "-g",
      "-j",
      "-M",
      "-m",
      "-r",
      "-t",
      "-T",
      "--after-context",
      "--before-context",
      "--context",
      "--encoding",
      "--file",
      "--glob",
      "--iglob",
      "--max-columns",
      "--max-count",
      "--max-depth",
      "--path-separator",
      "--pre",
      "--pre-glob",
      "--regexp",
      "--replace",
      "--sort",
      "--sortr",
      "--threads",
      "--type",
      "--type-add",
      "--type-clear",
    ]),
    patterns: new Set(["-e", "-f", "--file", "--regexp"]),
    files: new Set(["-f", "--file"]),
  },
  grep: {
    values: new Set([
      "-A",
      "-B",
      "-C",
      "-D",
      "-d",
      "-e",
      "-f",
      "-m",
      "--after-context",
      "--before-context",
      "--binary-files",
      "--color",
      "--context",
      "--devices",
      "--directories",
      "--exclude",
      "--exclude-dir",
      "--exclude-from",
      "--file",
      "--include",
      "--label",
      "--max-count",
      "--regexp",
    ]),
    patterns: new Set(["-e", "-f", "--file", "--regexp"]),
    files: new Set(["-f", "--exclude-from", "--file"]),
  },
};
const BASH_ARGUMENT_KEYS = new Set(["command", "timeout"]);
const ASSIGNMENT = /^[A-Za-z_][A-Za-z0-9_]*=/;
const DYNAMIC_PATH = /(^|[^\\])\$|[*?\[{]/;

function shellWords(command: string): string[] | undefined {
  const words: string[] = [];
  let word = "";
  let quote: Quote | undefined;
  let escaped = false;

  for (let index = 0; index < command.length; index += 1) {
    const character = command[index];
    if (escaped) {
      word += character;
      escaped = false;
      continue;
    }
    if (character === "\\" && quote !== "single") {
      escaped = true;
      continue;
    }
    if (quote) {
      const closesDouble = quote === "double" && character === '"';
      const closesSingle = (quote === "single" || quote === "ansi") && character === "'";
      if (closesDouble || closesSingle) quote = undefined;
      else if (quote !== "single" && (character === "`" || (character === "$" && command[index + 1] === "(")))
        return undefined;
      else word += character;
      continue;
    }
    if (character === '"') {
      quote = "double";
      continue;
    }
    if (character === "'") {
      quote = index > 0 && command[index - 1] === "$" ? "ansi" : "single";
      continue;
    }
    if (/\s/.test(character)) {
      if (word) words.push(word);
      word = "";
      continue;
    }
    if (character === "`" || (character === "$" && command[index + 1] === "(")) return undefined;
    word += character;
  }

  if (quote || escaped) return undefined;
  if (word) words.push(word);
  return words;
}

function commandWords(words: string[]): string[] {
  let index = 0;
  while (ASSIGNMENT.test(words[index] ?? "")) index += 1;
  if (words[index] === "command" || words[index] === "builtin") index += 1;
  if (words[index] === "env") {
    index += 1;
    while ((words[index] ?? "").startsWith("-") || ASSIGNMENT.test(words[index] ?? "")) index += 1;
  }
  return words.slice(index);
}

function searchPathOperands(executable: string, words: string[]): string[] {
  const spec = SEARCH_OPTION_SPECS[executable];
  const positional: string[] = [];
  const optionFiles: string[] = [];
  let patternFromOption = false;
  let filesMode = false;
  let optionsEnded = false;

  for (let index = 1; index < words.length; index += 1) {
    const word = words[index];
    if (!optionsEnded && word === "--") {
      optionsEnded = true;
      continue;
    }
    if (!optionsEnded && word.startsWith("-")) {
      const equals = word.indexOf("=");
      const option = equals === -1 ? word : word.slice(0, equals);
      const shortOption = word.length > 2 && !word.startsWith("--") ? word.slice(0, 2) : option;
      const matchedOption = spec.values.has(option) ? option : spec.values.has(shortOption) ? shortOption : undefined;
      if (!matchedOption) {
        if (option === "--files") filesMode = true;
        continue;
      }
      if (spec.patterns.has(matchedOption)) patternFromOption = true;
      let value = equals === -1 ? undefined : word.slice(equals + 1);
      if (value === undefined && shortOption === matchedOption && word.length > 2) value = word.slice(2);
      if (value === undefined) value = words[++index];
      if (value !== undefined && spec.files.has(matchedOption)) optionFiles.push(value);
      continue;
    }
    positional.push(word);
  }

  const pathOperands = patternFromOption || filesMode ? positional : positional.slice(1);
  return [...optionFiles, ...pathOperands];
}

function canonicalPath(path: string): string {
  return existsSync(path) ? realpathSync(path) : resolve(path);
}

function isWithinRoot(path: string, root: string): boolean {
  const child = canonicalPath(path);
  const parent = canonicalPath(root);
  const relation = relative(parent, child);
  return relation === "" || (!relation.startsWith("..") && !isAbsolute(relation));
}

export function localBashIntegrityDecision(input: unknown, cwd: string): Decision {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    return { deny: true, reason: "Blocked malformed Bash arguments." };
  }

  const arguments_ = input as Record<string, unknown>;
  const unknownKeys = Object.keys(arguments_).filter((key) => !BASH_ARGUMENT_KEYS.has(key));
  if (unknownKeys.length > 0) {
    return { deny: true, reason: `Blocked unknown Bash argument keys: ${unknownKeys.join(", ")}.` };
  }
  if (typeof arguments_.command !== "string" || !arguments_.command.trim()) {
    return { deny: true, reason: "Blocked Bash call without a non-empty command." };
  }

  const clauses = splitShellSequence(arguments_.command, true);
  if (!clauses) {
    return { deny: true, reason: "Blocked Bash command containing unsupported dynamic shell syntax." };
  }
  let effectiveCwd = cwd;
  for (const clause of clauses) {
    const parsedWords = shellWords(clause);
    if (!parsedWords || parsedWords.length === 0) continue;
    const words = commandWords(parsedWords);
    const executable = words[0]?.split("/").at(-1);

    if (executable === "cd") {
      if (clauses.length === 1) {
        return { deny: true, reason: "Blocked command-only `cd`; Bash calls do not preserve directory changes." };
      }
      const operands = words.slice(1).filter((word) => word !== "--");
      if (operands.length !== 1) {
        return { deny: true, reason: "Blocked `cd` with a missing or ambiguous target." };
      }
      const target = resolve(effectiveCwd, operands[0]);
      if (!isWithinRoot(target, cwd)) {
        return { deny: true, reason: `Blocked \`cd\` outside the session root: ${operands[0]}.` };
      }
      if (!existsSync(target) || !statSync(target).isDirectory()) {
        return { deny: true, reason: `Blocked \`cd\` to a nonexistent directory: ${operands[0]}.` };
      }
      effectiveCwd = target;
      continue;
    }

    if (!executable || !PATH_SCOPED_SEARCH_COMMANDS.has(executable)) continue;
    for (const word of searchPathOperands(executable, words)) {
      if (word.startsWith("~") || DYNAMIC_PATH.test(word)) {
        return { deny: true, reason: `Blocked dynamic ${executable} path: ${word}.` };
      }
      const target = resolve(effectiveCwd, word);
      if (!isWithinRoot(target, cwd)) {
        return { deny: true, reason: `Blocked ${executable} path outside the session root: ${word}.` };
      }
    }
  }

  return ALLOW;
}

export function localDestructiveTargetDecision(command: string, home = homedir()): Decision {
  for (const clause of command.split(/&&|\|\||[;\n]/)) {
    if (RM_COMMAND.test(clause)) {
      return { deny: true, reason: "Blocked `rm` by local policy. Use `trash` instead." };
    }
    if (!DELETE_COMMAND.test(clause)) continue;

    if (VARIABLE_REFERENCE.test(clause)) {
      return {
        deny: true,
        reason: "Blocked variable-derived deletion target. Use a verified literal target, or leave the path in place and report it.",
      };
    }

    const protectedPaths = [
      home,
      join(home, ".dotfiles"),
      join(home, ".config"),
      join(home, ".ssh"),
      join(home, ".gnupg"),
      join(home, ".local"),
      join(home, ".pi"),
      join(home, ".omp"),
      join(home, ".claude"),
      join(home, ".codex"),
    ];
    const namesProtectedPath = protectedPaths.some((path) => {
      const escaped = path.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      return new RegExp(`(?:^|\\s|["'])${escaped}(?=$|\\s|["'])`).test(clause);
    });
    if (/(?:^|\s)(?:--\s+)?\/(?:\s|$)/.test(clause) || namesProtectedPath) {
      return { deny: true, reason: "Blocked deletion of a protected root path." };
    }
  }

  return ALLOW;
}

function dcgDecision(command: string): Promise<Decision> {
  const { promise, resolve } = Promise.withResolvers<Decision>();
  let settled = false;
  const settle = (decision: Decision) => {
    if (settled) return;
    settled = true;
    resolve(decision);
  };

  let child;
  try {
    child = spawn(DCG_BIN, ["--robot", "test", command], {
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 30_000,
      killSignal: "SIGKILL",
    });
  } catch {
    settle(UNAVAILABLE);
    return promise;
  }

  let stdout = "";
  child.stdout?.on("data", (chunk) => {
    stdout += chunk.toString();
  });
  child.on("error", () => settle(UNAVAILABLE));
  child.on("close", (code) => {
    if (code === 0) {
      settle(ALLOW);
      return;
    }
    if (code !== 1) {
      settle(UNAVAILABLE);
      return;
    }

    let reason = "Blocked by dcg (destructive command).";
    try {
      const parsed: unknown = JSON.parse(stdout);
      if (parsed && typeof parsed === "object") {
        const result = parsed as Record<string, unknown>;
        if (typeof result.reason === "string") reason = result.reason;
        if (typeof result.rule_id === "string") {
          reason += ` [${result.rule_id}]`;
          settle({ deny: true, reason, ruleId: result.rule_id });
          return;
        }
      }
    } catch {
      // The exit code remains authoritative when diagnostic JSON is unavailable.
    }
    settle({ deny: true, reason });
  });
  return promise;
}

export async function applyUserApproval(
  decision: Decision,
  command: string,
  ctx: ApprovalContext,
  events?: ApprovalEvents,
  recheck: (command: string) => Promise<Decision> = dcgDecision,
): Promise<Decision> {
  if (!decision.deny || !decision.ruleId) return decision;

  if (EXEMPTED_GIT_RULES.has(decision.ruleId)) {
    const sequence = parseCommandSequence(command);
    if (sequence.exempted) {
      const remainderDecisions = await Promise.all(sequence.remainder.map(recheck));
      const deniedRemainder = remainderDecisions.find((remainderDecision) => remainderDecision.deny);
      if (!deniedRemainder) return ALLOW;
      decision = deniedRemainder;
    }
  }

  if (!decision.ruleId?.startsWith("core.git:") || !ctx.hasUI) return decision;

  events?.emit("herdr:blocked", {
    active: true,
    label: "Destructive Git approval required",
  });
  try {
    const approved = await ctx.ui.confirm("Allow destructive Git operation?", `${decision.reason}\n\nCommand:\n${command}`);
    return approved ? ALLOW : { deny: true, reason: "Blocked by user." };
  } finally {
    events?.emit("herdr:blocked", { active: false });
  }
}

export default function dcgGuard(pi: ExtensionAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    let decision: Decision = localBashIntegrityDecision(event.input, ctx.cwd);
    if (decision.deny) return { block: true, reason: decision.reason };

    const command = String(event.input?.command ?? "");
    decision = localDestructiveTargetDecision(command);
    if (decision.deny) return { block: true, reason: decision.reason };

    try {
      decision = await dcgDecision(command);
    } catch {
      decision = UNAVAILABLE;
    }
    decision = await applyUserApproval(decision, command, ctx, pi.events);
    if (decision.deny) return { block: true, reason: decision.reason };
  });
}
