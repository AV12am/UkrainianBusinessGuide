import type { Source } from "../lib/pipeline.js";

/** Stage 1 seed: verified reachable on 2026-11-27 (HTTP 200, allowed by robots.txt). */
export const SOURCES: Source[] = [
  {
    id: "github-terms", vendor: "GitHub", docType: "terms", language: "en", intervalHours: 24,
    url: "https://docs.github.com/en/site-policy/github-terms/github-terms-of-service",
    rule: { selector: "main" },
  },
  {
    id: "github-subprocessors", vendor: "GitHub", docType: "subprocessors", language: "en", intervalHours: 24,
    url: "https://docs.github.com/en/site-policy/privacy-policies/github-subprocessors",
    rule: { selector: "main" },
  },
  {
    id: "atlassian-subprocessors", vendor: "Atlassian", docType: "subprocessors", language: "en", intervalHours: 24,
    url: "https://www.atlassian.com/legal/sub-processors",
    rule: { selector: "main" },
  },
  {
    // NOTE: retail card tariffs. The business (РКО) tariff page URL is still to be found.
    id: "privatbank-card-tariffs", vendor: "ПриватБанк", docType: "tariffs", language: "uk", intervalHours: 24,
    url: "https://privatbank.ua/tariffs",
    rule: { selector: "main" },
  },
];
