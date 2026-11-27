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
    id: "privatbank-business-tariffs", vendor: "ПриватБанк", docType: "tariffs", language: "uk", intervalHours: 24,
    url: "https://privatbank.ua/business/small-and-medium/settlement-cash-services",
    // #main holds the tariff tables; the exchange-rate widget sits outside it and changes daily.
    rule: { selector: "#main" },
  },
  {
    id: "privatbank-rko-pdf", vendor: "ПриватБанк", docType: "tariffs", language: "uk", intervalHours: 24,
    url: "https://privatbank.ua/get/table/14/pdf", format: "pdf",
  },
  {
    id: "privatbank-it-expert-pdf", vendor: "ПриватБанк", docType: "tariffs", language: "uk", intervalHours: 24,
    url: "https://privatbank.ua/get/table/272/pdf", format: "pdf",
  },
];
