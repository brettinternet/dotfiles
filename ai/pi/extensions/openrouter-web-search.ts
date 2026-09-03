import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const RESPONSES_URL = "https://openrouter.ai/api/v1/responses";


function selectModel(ctx: ExtensionContext) {
  if (ctx.model?.provider === "openrouter") return ctx.model;

  const model = ctx.modelRegistry
    .getAll()
    .find((candidate) => candidate.provider === "openrouter");
  if (!model) throw new Error("No OpenRouter model is configured in Pi");
  return model;
}

function requestHeaders(
  apiKey: string,
  providerHeaders: Record<string, string | null> | undefined,
): Record<string, string> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  };
  for (const [name, value] of Object.entries(providerHeaders ?? {})) {
    if (value !== null) headers[name] = value;
  }
  return headers;
}

function collectResponse(value: unknown): { texts: string[]; urls: string[] } {
  const texts: string[] = [];
  const urls: string[] = [];
  const visit = (node: unknown): void => {
    if (Array.isArray(node)) {
      node.forEach(visit);
      return;
    }
    if (!node || typeof node !== "object") return;

    const record = node as Record<string, unknown>;
    if (
      (record.type === "output_text" || record.type === "text") &&
      typeof record.text === "string" &&
      record.text.trim()
    ) {
      texts.push(record.text.trim());
    }
    if (typeof record.url === "string" && /^https?:\/\//u.test(record.url)) {
      urls.push(record.url);
    }
    Object.values(record).forEach(visit);
  };
  visit(value);
  return { texts, urls };
}

export default function openRouterWebSearch(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description:
      "Search the web through OpenRouter using its Perplexity search engine. Returns a grounded answer and source URLs.",
    promptSnippet:
      "Use for current information and web research. Cite the returned source URLs.",
    parameters: Type.Object({
      query: Type.String({ description: "Web search query" }),
      maxResults: Type.Optional(
        Type.Integer({
          minimum: 1,
          maximum: 20,
          description: "Maximum search results (default: 5)",
        }),
      ),
    }),
    async execute(_callId, params, signal, _onUpdate, ctx) {
      const model = selectModel(ctx);
      const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
      if (!auth.ok || !auth.apiKey) {
        throw new Error(
          `OpenRouter authentication failed: ${auth.ok ? "API key unavailable" : auth.error}`,
        );
      }

      const response = await fetch(RESPONSES_URL, {
        method: "POST",
        headers: requestHeaders(auth.apiKey, auth.headers),
        signal,
        body: JSON.stringify({
          model: model.id,
          input: params.query,
          instructions:
            "Search the web before answering. Give a concise answer grounded in the results and include source citations.",
          tools: [
            {
              type: "openrouter:web_search",
              parameters: {
                engine: "perplexity",
                max_results: params.maxResults ?? 5,
              },
            },
          ],
          tool_choice: "required",
          max_output_tokens: 4000,
        }),
      });

      if (!response.ok) {
        const detail = (await response.text()).trim().slice(0, 500);
        throw new Error(
          `OpenRouter web search failed (${response.status}): ${detail || response.statusText}`,
        );
      }

      const payload: unknown = await response.json();
      const { texts, urls } = collectResponse(payload);
      if (texts.length === 0) {
        throw new Error("OpenRouter web search returned no answer text");
      }

      const uniqueUrls = [...new Set(urls)];
      const answer = texts.join("\n\n");
      const sources = uniqueUrls.length > 0
        ? `\n\nSources:\n${uniqueUrls.map((url) => `- ${url}`).join("\n")}`
        : "";
      return {
        content: [{ type: "text", text: answer + sources }],
        details: { model: model.id, engine: "perplexity", sources: uniqueUrls },
      };
    },
  });
}
