/**
 * advisor — a secondary reviewer agent watching the PRIMARY session (an OMP
 * advisor/WATCHDOG port onto the dsh agent plane; see `omp://advisor-watchdog.md`
 * for the target behavior this is a scoped v1 of).
 *
 * Cadence:
 *  1. `turn/end` on a top-level (`delegationDepth === 0`) session arms
 *     `pending = true` for that session.
 *  2. The next `agent/pre-step` that enters a step (`kind: 'enter'`) for that
 *     same top-level agent renders the session-event delta since the last
 *     review, hands it to a lazily-created persistent advisor child via
 *     `followup` + `whenIdle`, and reads back its final assistant text.
 *  3. Advice that is empty or exactly `NO_ADVICE` is never injected (emission
 *     gate — silence is the default). Otherwise one `user` message sourced
 *     `{ kind: 'advisor' }` is appended to the primary's next request.
 *
 * The advisor child is NOT composed through `applyChildComposition`: joining
 * the liangshen composition would drag in this preset's own `tool-bootstrap`
 * (which strips the child to `[bash, str_replace_editor]`), the base
 * `dsh-persona` (`complete: true`, conflicting with the advisor persona), and
 * this very row — advisor-of-advisor recursion. Instead `setup(childCtx)`
 * mounts exactly a reviewer's read-only investigative tools
 * (`@deepseek-ai/dsh-tool-fs` + `@deepseek-ai/dsh-tool-fs-search`) and denies
 * everything outside the configured allow-list with `childCtx.tools.guard`
 * (an authority boundary; `restrict` only masks visibility). `write`/`edit`
 * schemas from `dsh-tool-fs` stay visible but every call is denied — extra
 * tokens, no capability leak.
 *
 * `setup` stays SYNCHRONOUS, mirroring the proven `dsh-subagent-in-process-driver`
 * template (lib/index.js:170-186): it only calls `childCtx.plugin(...)` (which
 * schedules plugin loading) plus synchronous `ctx.tools.guard`/
 * `ctx.systemPrompt.section` registrations — never an `await`, so it can never
 * race the factory's own publication wait.
 *
 * Recursion/scope safety: both listeners below check
 * `(session.header.delegationDepth ?? 0) === 0` before acting. The advisor
 * child is created at depth 1 and carries no advisor plugin (no composition
 * join), so it cannot itself be advised — recursion is impossible by
 * construction. Ordinary delegated subagents (created through
 * `applyChildComposition`, e.g. `dsh-tool-subagent`) DO join this preset's
 * scope and DO reach these listeners; the depth guard is what excludes them
 * from review.
 *
 * Failure containment: every review/create/tool-mount error is caught and
 * logged once; the turn always proceeds with no injected advice on failure.
 */

import { randomUUID } from 'node:crypto'
import { SessionId } from '@deepseek-ai/dsh-session'
import { createUserMessage } from '@deepseek-ai/dsh-llm'
import { childSessionMeta, finalAssistantOutput, resolveChildAgentOptions, resolveChildDepth } from '@deepseek-ai/dsh-subagent'
import * as dshToolFs from '@deepseek-ai/dsh-tool-fs'
import * as dshToolFsSearch from '@deepseek-ai/dsh-tool-fs-search'

/** Cordis plugin name used by loader diagnostics. */
export const name = 'advisor'

/** Deliberately no inject list: the listeners only touch services at event time. */
export const inject = []

/**
 * Grantable investigative tool names: the read-only subset of what
 * `dsh-tool-fs` + `dsh-tool-fs-search` register. `write`/`edit` are never
 * grantable here — this is a fixed read-only allow-list, not a per-advisor
 * escalation knob. Their schemas stay visible (dsh-tool-fs registers them
 * unconditionally) but the guard below always denies them (see module doc).
 */
const KNOWN_TOOL_NAMES = ['read', 'glob', 'grep']

/** Default investigative grant — read-only, matching the OMP advisor default. */
const DEFAULT_TOOLS = ['read', 'glob', 'grep']

/** Every config key this plugin accepts. */
const ALLOWED_KEYS = new Set(['tools', 'model'])

/** Exact reply that means "no intervention warranted" — the emission gate. */
const NO_ADVICE = 'NO_ADVICE'

/** The advisor child's entire system prompt (no persona plugin joined, so this renders alone). */
const ADVISOR_PERSONA = `You are a silent reviewing advisor watching a primary coding agent work in this workspace. You are not the primary agent: you cannot edit files, run commands, or otherwise act on the workspace — you may only inspect it with your own read-only tools (read, grep, glob) and report back one short note.

Each turn you receive the primary's transcript delta: its messages, tool calls, and tool results since your last review. Investigate anything that looks wrong using your tools, then decide:

- If the primary is on track — no material risk, no hallucinated API, no drifted-off-task edit, nothing that would change what it should do next — reply with EXACTLY the single line: ${NO_ADVICE}
- Otherwise, reply with ONE concise paragraph (a few sentences at most) naming the concrete problem and what the primary should do differently. No preamble, no restating the transcript, no hedging.

Silence is the default. Only speak when your note would change the primary's next action.`

function toolList(value) {
  if (value === undefined) return [...DEFAULT_TOOLS]
  if (!Array.isArray(value) || value.length === 0 || value.some((item) => typeof item !== 'string' || item.length === 0)) {
    throw new TypeError(`${name}: tools must be a non-empty array of non-empty strings`)
  }
  const unknown = value.filter((toolName) => !KNOWN_TOOL_NAMES.includes(toolName))
  if (unknown.length > 0) {
    throw new TypeError(`${name}: tools contains unknown name(s) ${unknown.join(', ')} — allowed: ${KNOWN_TOOL_NAMES.join(', ')}`)
  }
  return [...new Set(value)]
}

function modelOptions(value) {
  if (value === undefined) return undefined
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError(`${name}: model must be an object`)
  }
  const { provider, model, maxTokens, ...rest } = value
  if (Object.keys(rest).length > 0) {
    throw new TypeError(`${name}: model has unknown key(s) ${Object.keys(rest).join(', ')}`)
  }
  if (provider !== undefined && typeof provider !== 'string') throw new TypeError(`${name}: model.provider must be a string`)
  if (model !== undefined && typeof model !== 'string') throw new TypeError(`${name}: model.model must be a string`)
  if (maxTokens !== undefined && (!Number.isSafeInteger(maxTokens) || maxTokens <= 0)) {
    throw new TypeError(`${name}: model.maxTokens must be a positive safe integer`)
  }
  return {
    ...(provider !== undefined ? { provider } : {}),
    ...(model !== undefined ? { model } : {}),
    ...(maxTokens !== undefined ? { maxTokens } : {}),
  }
}

/** Render one content-block array to plain reviewer-facing text (text/tool-call/tool-result only). */
function renderBlocks(blocks) {
  if (blocks === undefined) return ''
  const parts = []
  for (const block of blocks) {
    if (block.type === 'text') {
      if (block.text.length > 0) parts.push(block.text)
    } else if (block.type === 'tool-call') {
      parts.push(`[tool-call ${block.name}(${block.arguments})]`)
    } else if (block.type === 'tool-result') {
      const inner = renderBlocks(block.content)
      parts.push(`[tool-result${block.isError === true ? ' error' : ''}: ${inner}]`)
    }
    // reasoning/image intentionally omitted: the advisor reviews visible
    // behavior, not the primary's private reasoning or binary attachments.
  }
  return parts.join('\n')
}

/** Render a session-event delta into one reviewer-facing transcript, or undefined if there is nothing new. */
function renderDelta(events) {
  const lines = []
  for (const event of events) {
    if (event.type === 'user/message') {
      // Never re-review advice this very plugin already injected.
      if (event.data.source?.kind === 'advisor') continue
      const text = renderBlocks(event.data.content)
      if (text.length > 0) lines.push(`USER (${event.data.source?.kind ?? 'user'}): ${text}`)
    } else if (event.type === 'assistant/message') {
      const text = renderBlocks(event.data.message.content)
      if (text.length > 0) lines.push(`ASSISTANT: ${text}`)
    } else if (event.type === 'tool/result') {
      const text = renderBlocks(event.data.message.content)
      const status = event.data.error !== undefined ? ` (error: ${event.data.error.code})` : ''
      if (text.length > 0) lines.push(`TOOL RESULT${status}: ${text}`)
    }
    // turn/step boundaries, request headers, raw chunks: not reviewer-relevant.
  }
  if (lines.length === 0) return undefined
  return lines.join('\n\n')
}

/** Register the primary-session advisor watcher. */
export function apply(ctx, config) {
  const source = config === undefined ? {} : config
  if (typeof source !== 'object' || source === null || Array.isArray(source)) {
    throw new TypeError(`${name}: config must be an object`)
  }
  const unknownKeys = Object.keys(source).filter((key) => !ALLOWED_KEYS.has(key))
  if (unknownKeys.length > 0) {
    throw new TypeError(`${name}: unknown config key(s) ${unknownKeys.join(', ')} — allowed keys: ${[...ALLOWED_KEYS].sort().join(', ')}`)
  }
  const allowedTools = new Set(toolList(source.tools))
  const modelOverride = modelOptions(source.model)

  let warned = false
  const warnOnce = (message) => {
    if (warned) return
    warned = true
    try {
      ctx.logger.warn(message)
    } catch {
      // Logger unavailable — the guard exists only to avoid spamming.
    }
  }

  /** Per-primary-session watcher state. */
  const states = new Map()
  const stateFor = (sessionId) => {
    let state = states.get(sessionId)
    if (state === undefined) {
      state = { pending: false, reviewedThrough: 0, child: undefined, creating: undefined }
      states.set(sessionId, state)
    }
    return state
  }

  ctx.on('session/event', (session, event) => {
    if ((session.header.delegationDepth ?? 0) !== 0) return
    if (event.type !== 'turn/end') return
    stateFor(session.id).pending = true
  })

  /** Lazily create (once) and return this primary's persistent advisor child agent. */
  async function ensureChild(agent, state, signal) {
    if (state.child !== undefined) return state.child
    if (state.creating !== undefined) return state.creating
    state.creating = (async () => {
      try {
        const childDepth = resolveChildDepth(agent, undefined)
        const handle = await agent.ctx.agents.create({
          sessionId: SessionId(randomUUID()),
          meta: childSessionMeta(agent, childDepth, 0),
          agentOptions: resolveChildAgentOptions(agent, modelOverride, childDepth),
          signal,
          setup(childCtx) {
            childCtx.plugin(dshToolFs, {})
            childCtx.plugin(dshToolFsSearch, { sampleOverCapGlobResults: false })
            childCtx.tools.guard((execution) => (
              allowedTools.has(execution.name) ? undefined : `advisor tools are read-only: "${execution.name}" is not granted`
            ))
            childCtx.systemPrompt.section({ name: 'advisor:persona', order: 0, text: ADVISOR_PERSONA })
          },
        })
        state.child = handle.agent
        return state.child
      } catch (error) {
        warnOnce(`${name}: advisor child creation failed, reviews are disabled for this session: ${String((error && error.message) || error)}`)
        return undefined
      } finally {
        state.creating = undefined
      }
    })()
    return state.creating
  }

  /** Run one review cycle for the primary `agent`; returns trimmed advice text, or undefined for silence. */
  async function review(agent, state, signal) {
    const events = agent.session.events
    const delta = events.slice(state.reviewedThrough)
    state.reviewedThrough = events.length
    const transcript = renderDelta(delta)
    if (transcript === undefined) return undefined

    const child = await ensureChild(agent, state, signal)
    if (child === undefined) return undefined

    const before = child.session.events.length
    child.followup(createUserMessage({
      content: [{ type: 'text', text: transcript }],
      source: { kind: 'user' },
    }))
    await child.whenIdle()
    const output = finalAssistantOutput(child.session.events.slice(before))
    const text = renderBlocks(output).trim()
    if (text.length === 0 || text === NO_ADVICE) return undefined
    return text
  }

  ctx.on('agent/pre-step', async ({ agent, signal }, next) => {
    const decision = await next()
    if (decision.kind !== 'enter') return decision
    if ((agent.session.header.delegationDepth ?? 0) !== 0) return decision
    const state = stateFor(agent.session.id)
    if (!state.pending) return decision
    state.pending = false

    try {
      const advice = await review(agent, state, signal)
      if (advice === undefined) return decision
      return {
        ...decision,
        messages: [...decision.messages, {
          id: `advisor-${agent.session.id}-${agent.session.events.length}`,
          role: 'user',
          content: [{ type: 'text', text: `[Advisor] ${advice}` }],
          source: { kind: 'advisor' },
        }],
      }
    } catch (error) {
      warnOnce(`${name}: review failed, skipping: ${String((error && error.message) || error)}`)
      return decision
    }
  }, { prepend: true })
}
