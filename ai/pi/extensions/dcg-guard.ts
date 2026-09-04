// dotfiles-dcg-shell-guard
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
type ExtensionAPI = {
  on(
    event: "tool_call",
    handler: (event: { toolName: string; input?: Record<string, unknown> }) => Promise<{ block: true; reason: string } | undefined>,
  ): void;
};

const DCG_BIN =
  process.env.DCG_BIN ?? join(homedir(), ".local/share/mise/installs/github-dicklesworthstone-destructive-command-guard/latest/dcg");
const UNAVAILABLE = { deny: true, reason: "Blocked because the dcg safety guard is unavailable." };
const ALLOW = { deny: false, reason: "" };

type Decision = { deny: boolean; reason: string };

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
        }
      }
    } catch {
      // The exit code remains authoritative when diagnostic JSON is unavailable.
    }
    settle({ deny: true, reason });
  });
  return promise;
}

export default function dcgGuard(pi: ExtensionAPI): void {
  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const command = String(event.input?.command ?? "");
    if (!command.trim()) return;

    let decision: Decision;
    try {
      decision = await dcgDecision(command);
    } catch {
      decision = UNAVAILABLE;
    }
    if (decision.deny) return { block: true, reason: decision.reason };
  });
}
