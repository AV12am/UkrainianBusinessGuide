import Anthropic from "@anthropic-ai/sdk";

export interface LlmRequest { system: string; user: string; maxTokens: number }
export interface LlmResponse { text: string; inputTokens: number; outputTokens: number; model: string }

/** Swappable LLM boundary. The pipeline only depends on this interface. */
export interface LlmClient { complete(req: LlmRequest): Promise<LlmResponse> }

export interface Pricing { inPerMTok: number; outPerMTok: number }

export const costUsd = (p: Pricing, inputTokens: number, outputTokens: number): number =>
  (inputTokens * p.inPerMTok + outputTokens * p.outPerMTok) / 1_000_000;

export class AnthropicLlm implements LlmClient {
  private client: Anthropic;
  constructor(apiKey: string, readonly model: string) {
    this.client = new Anthropic({ apiKey });
  }
  async complete(req: LlmRequest): Promise<LlmResponse> {
    const res = await this.client.messages.create({
      model: this.model,
      max_tokens: req.maxTokens,
      system: req.system,
      messages: [{ role: "user", content: req.user }],
    });
    const text = res.content.map((b) => (b.type === "text" ? b.text : "")).join("");
    return { text, inputTokens: res.usage.input_tokens, outputTokens: res.usage.output_tokens, model: this.model };
  }
}
