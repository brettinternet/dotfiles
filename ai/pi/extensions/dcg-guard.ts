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
  on(event: "session_start", handler: (_event: unknown, ctx: ToolCallContext) => Promise<void>): void;
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
  /^\s*(?:(?:then|do|else)\s+)?(?:rtk\s+)?git((?:\s+-C\s+(?:"[^"]*"|'[^']*'|\S+))*)\s+([a-z-]+)(?:\s+([^;&|\n]*))?\s*$/;
const GIT_DIRECTORY_OPTION = /(?:^|\s)-C\s+("[^"]*"|'[^']*'|\S+)/g;
const DELETE_OPTION = /(?:^|\s)(?:-d|-D|--delete)(?:\s|$)/;
const FORCE_BRANCH_UPDATE = /^(?:-f|--force)\s+(\S+)(?:\s+\S+)?$/;
const EXEMPTED_GIT_RULES = new Set([
  "core.git:branch-force-delete",
  "core.git:restore-worktree",
  "core.git:checkout-discard",
  "core.git:reset-hard",
]);
const WORKTREE_LIFECYCLE_COMMAND = /\b(?:hwt\s+(?:remove|rm)|git\s+worktree\s+remove|worklease\s+release)\b/;
const PROTECTED_WORKSPACE_LABEL = /(?:^|[-_\s])(?:keep|user-owned)(?:$|[-_\s])/i;

export type GitOwnership = {
  managedRoots: Map<string, string>;
  repoRoots: Map<string, string>;
  managedBranches: Set<string>;
  protectedBranches: Set<string>;
};

type CommandSequence = { clauses: Array<{ command: string; cwd: string }>; valid: boolean };
type Quote = "single" | "double" | "ansi";
type GitCommand = { subcommand: string; arguments: string; cwd: string };
type GitCheckout = { branch?: string; gitDir: string; repoKey: string; root: string };

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

function unquote(value: string): string {
  const first = value[0];
  return (first === '"' || first === "'") && value.at(-1) === first ? value.slice(1, -1) : value;
}

function parseGitCommand(command: string, cwd: string): GitCommand | undefined {
  const match = command.match(GIT_COMMAND);
  if (!match) return undefined;

  let gitCwd = cwd;
  for (const directoryMatch of match[1].matchAll(GIT_DIRECTORY_OPTION)) {
    if (directoryMatch[1].startsWith("~") || DYNAMIC_PATH.test(directoryMatch[1])) return undefined;
    gitCwd = resolve(gitCwd, unquote(directoryMatch[1]));
  }
  return { cwd: gitCwd, subcommand: match[2], arguments: match[3] ?? "" };
}

function branchKey(repoKey: string, branch: string): string {
  return `${repoKey}\0${unquote(branch)}`;
}

function deletedBranches(arguments_: string): string[] | undefined {
  if (VARIABLE_REFERENCE.test(arguments_)) return undefined;
  const words = shellWords(arguments_);
  if (!words) return undefined;

  let optionsEnded = false;
  const branches: string[] = [];
  for (const word of words) {
    if (!optionsEnded && word === "--") {
      optionsEnded = true;
    } else if (!optionsEnded && ["-d", "-D", "--delete"].includes(word)) {
      continue;
    } else if (!optionsEnded && word.startsWith("-")) {
      return undefined;
    } else {
      branches.push(word);
    }
  }
  return branches.length > 0 ? branches : undefined;
}

function targetsManagedBranch(git: GitCommand, repoKey: string, ownership: GitOwnership): boolean {
  const forcedBranch = git.arguments.match(FORCE_BRANCH_UPDATE)?.[1];
  if (forcedBranch && !VARIABLE_REFERENCE.test(git.arguments)) {
    const key = branchKey(repoKey, forcedBranch);
    return ownership.managedBranches.has(key) && !ownership.protectedBranches.has(key);
  }

  const branches = DELETE_OPTION.test(git.arguments) ? deletedBranches(git.arguments) : undefined;
  return Boolean(
    branches?.every((branch) => {
      const key = branchKey(repoKey, branch);
      return ownership.managedBranches.has(key) && !ownership.protectedBranches.has(key);
    }),
  );
}

async function isOwnedCleanup(
  command: string,
  cwd: string,
  ownership: GitOwnership,
  resolveCheckout: (path: string) => Promise<{ branch?: string; repoKey: string; root: string } | undefined>,
): Promise<boolean> {
  const git = parseGitCommand(command, cwd);
  if (!git || !["branch", "restore", "checkout", "reset"].includes(git.subcommand)) return false;
  const checkout = await resolveCheckout(git.cwd);
  if (!checkout) return false;
  if (git.subcommand === "branch") return targetsManagedBranch(git, checkout.repoKey, ownership);
  if (ownership.managedRoots.get(checkout.root) !== checkout.repoKey) return false;

  if (git.subcommand === "restore") return true;
  if (git.subcommand === "checkout") return /^--\s+\S/.test(git.arguments);
  return git.subcommand === "reset" && /^--hard(?:\s+\S+)?$/.test(git.arguments);
}

function parseCommandSequence(command: string, cwd: string): CommandSequence {
  const commands = splitShellSequence(command, true);
  if (!commands) return { clauses: [], valid: false };

  const clauses: Array<{ command: string; cwd: string }> = [];
  let effectiveCwd = cwd;
  for (const clause of commands) {
    const words = shellWords(clause);
    const executable = words ? commandWords(words)[0] : undefined;
    if (
      ["pushd", "popd", "source", ".", "eval"].includes(executable ?? "") ||
      (words?.includes("cd") && executable !== "cd") ||
      /(?:^|\s)(?:function\s+|[A-Za-z_][A-Za-z0-9_]*\s*\(\s*\)\s*\{|[{}()])(?:\s|$)/.test(clause)
    ) {
      return { clauses: [], valid: false };
    }

    const directoryChange = clause.match(/^cd\s+("[^"]*"|'[^']*'|\S+)$/);
    clauses.push({ command: clause, cwd: effectiveCwd });
    if (
      executable === "cd" &&
      (!directoryChange || directoryChange[1].startsWith("~") || DYNAMIC_PATH.test(directoryChange[1]))
    ) {
      return { clauses: [], valid: false };
    }
    if (directoryChange) effectiveCwd = resolve(effectiveCwd, unquote(directoryChange[1]));
  }
  return { clauses, valid: true };
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

function commandOutput(command: string, arguments_: string[], cwd?: string): Promise<string | undefined> {
  return new Promise((resolveOutput) => {
    let child;
    try {
      child = spawn(command, arguments_, { cwd, stdio: ["ignore", "pipe", "ignore"], timeout: 10_000 });
    } catch {
      resolveOutput(undefined);
      return;
    }

    let stdout = "";
    child.stdout?.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.on("error", () => resolveOutput(undefined));
    child.on("close", (code) => resolveOutput(code === 0 ? stdout.trim() : undefined));
  });
}

async function gitCheckout(path: string): Promise<GitCheckout | undefined> {
  const root = await commandOutput("git", ["-C", path, "rev-parse", "--show-toplevel"]);
  if (!root) return undefined;
  const [repoKey, gitDir, branch] = await Promise.all([
    commandOutput("git", ["-C", root, "rev-parse", "--path-format=absolute", "--git-common-dir"]),
    commandOutput("git", ["-C", root, "rev-parse", "--path-format=absolute", "--absolute-git-dir"]),
    commandOutput("git", ["-C", root, "symbolic-ref", "--quiet", "--short", "HEAD"]),
  ]);
  if (!repoKey || !gitDir) return undefined;
  return {
    branch,
    gitDir: canonicalPath(gitDir),
    repoKey: canonicalPath(repoKey),
    root: canonicalPath(root),
  };
}

async function protectRepositoryBranches(
  ownership: GitOwnership,
  repoRoot: string,
  repoKey: string,
): Promise<void> {
  for (const branch of ["main", "master", "trunk"]) {
    ownership.protectedBranches.add(branchKey(repoKey, branch));
  }
  const [currentBranch, remoteHead] = await Promise.all([
    commandOutput("git", ["-C", repoRoot, "branch", "--show-current"]),
    commandOutput("git", ["-C", repoRoot, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"]),
  ]);
  if (currentBranch) ownership.protectedBranches.add(branchKey(repoKey, currentBranch));
  if (remoteHead) ownership.protectedBranches.add(branchKey(repoKey, remoteHead.replace(/^origin\//, "")));
}

export function isLinkedGitCheckout(checkout: { gitDir: string; repoKey: string }): boolean {
  return checkout.gitDir !== checkout.repoKey;
}

export function resetGitOwnership(ownership: GitOwnership): void {
  ownership.managedRoots.clear();
  ownership.repoRoots.clear();
  ownership.managedBranches.clear();
  ownership.protectedBranches.clear();
}

async function refreshGitOwnership(ownership: GitOwnership, cwd: string): Promise<void> {
  resetGitOwnership(ownership);

  const sessionCheckout = await gitCheckout(cwd);
  if (sessionCheckout) {
    const linked = isLinkedGitCheckout(sessionCheckout);
    const worktreeList = linked
      ? await commandOutput("git", ["-C", sessionCheckout.root, "worktree", "list", "--porcelain"])
      : undefined;
    const listedPrimaryRoot = worktreeList?.match(/^worktree (.+)$/m)?.[1];
    const primaryRoot = canonicalPath(listedPrimaryRoot ?? sessionCheckout.root);
    ownership.repoRoots.set(primaryRoot, sessionCheckout.repoKey);
    ownership.repoRoots.set(sessionCheckout.root, sessionCheckout.repoKey);
    await protectRepositoryBranches(ownership, primaryRoot, sessionCheckout.repoKey);
    if (linked) {
      ownership.managedRoots.set(sessionCheckout.root, sessionCheckout.repoKey);
      if (sessionCheckout.branch) {
        ownership.managedBranches.add(branchKey(sessionCheckout.repoKey, sessionCheckout.branch));
      }
    }
  }

  const herdrBin = process.env.HERDR_BIN_PATH ?? "herdr";
  const workspaceJson = await commandOutput(herdrBin, ["workspace", "list"]);
  if (!workspaceJson) return;

  try {
    const parsed = JSON.parse(workspaceJson) as {
      result?: {
        workspaces?: Array<{
          label?: string;
          worktree?: { checkout_path?: string; is_linked_worktree?: boolean; repo_key?: string; repo_root?: string };
        }>;
      };
    };
    const protectedRepos = new Set<string>();
    for (const workspace of parsed.result?.workspaces ?? []) {
      const worktree = workspace.worktree;
      if (!worktree?.checkout_path || !worktree.repo_key || !worktree.repo_root) continue;

      const repoKey = canonicalPath(worktree.repo_key);
      const repoRoot = canonicalPath(worktree.repo_root);
      const checkoutPath = canonicalPath(worktree.checkout_path);
      ownership.repoRoots.set(repoRoot, repoKey);
      ownership.repoRoots.set(checkoutPath, repoKey);
      if (!protectedRepos.has(repoKey)) {
        protectedRepos.add(repoKey);
        await protectRepositoryBranches(ownership, repoRoot, repoKey);
      }

      if (!worktree.is_linked_worktree) continue;
      const branch = await commandOutput("git", ["-C", checkoutPath, "symbolic-ref", "--quiet", "--short", "HEAD"]);
      if (PROTECTED_WORKSPACE_LABEL.test(workspace.label ?? "")) {
        if (branch) ownership.protectedBranches.add(branchKey(repoKey, branch));
        continue;
      }
      ownership.managedRoots.set(checkoutPath, repoKey);
      if (branch) ownership.managedBranches.add(branchKey(repoKey, branch));
    }
  } catch {
    // Unknown or unavailable Herdr state leaves ownership unproven.
  }
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
  ctx: ApprovalContext & { cwd?: string },
  events?: ApprovalEvents,
  recheck: (command: string) => Promise<Decision> = dcgDecision,
  ownership?: GitOwnership,
  resolveCheckout: (
    path: string,
  ) => Promise<{ branch?: string; repoKey: string; root: string } | undefined> = gitCheckout,
): Promise<Decision> {
  if (!decision.deny || !decision.ruleId) return decision;

  if (EXEMPTED_GIT_RULES.has(decision.ruleId) && ctx.cwd && ownership) {
    const sequence = parseCommandSequence(command, ctx.cwd);
    if (sequence.valid) {
      const ownershipChecks = await Promise.all(
        sequence.clauses.map((clause) => isOwnedCleanup(clause.command, clause.cwd, ownership, resolveCheckout)),
      );
      if (ownershipChecks.some(Boolean)) {
        const remainder = sequence.clauses.filter((_clause, index) => !ownershipChecks[index]);
        const remainderDecisions = await Promise.all(remainder.map((clause) => recheck(clause.command)));
        const deniedRemainder = remainderDecisions.find((remainderDecision) => remainderDecision.deny);
        if (!deniedRemainder) return ALLOW;
        decision = deniedRemainder;
      }
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
  const ownership: GitOwnership = {
    managedRoots: new Map(),
    repoRoots: new Map(),
    managedBranches: new Set(),
    protectedBranches: new Set(),
  };

  pi.on("session_start", async (_event, ctx) => {
    await refreshGitOwnership(ownership, ctx.cwd);
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    let decision: Decision = localBashIntegrityDecision(event.input, ctx.cwd);
    if (decision.deny) return { block: true, reason: decision.reason };

    const command = String(event.input?.command ?? "");
    const refreshedOwnership = WORKTREE_LIFECYCLE_COMMAND.test(command);
    if (refreshedOwnership) await refreshGitOwnership(ownership, ctx.cwd);
    decision = localDestructiveTargetDecision(command);
    if (decision.deny) return { block: true, reason: decision.reason };

    try {
      decision = await dcgDecision(command);
    } catch {
      decision = UNAVAILABLE;
    }
    if (!refreshedOwnership && decision.ruleId && EXEMPTED_GIT_RULES.has(decision.ruleId)) {
      await refreshGitOwnership(ownership, ctx.cwd);
    }
    decision = await applyUserApproval(decision, command, ctx, pi.events, dcgDecision, ownership);
    if (decision.deny) return { block: true, reason: decision.reason };
  });
}
