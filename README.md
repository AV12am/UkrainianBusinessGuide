# Termwatch UA

Monitoring of vendor terms (and, from stage 2, Ukrainian legislation), with a plain-language
explanation of what each change means. Build brief: stages 1 to 5. **Current stage: 1 (Module A pipeline).**

## Status

| Stage | Scope | State |
|---|---|---|
| 1 | Module A pipeline on real vendors | done (see below) |
| 2 | Module B: Rada open data adapter | not started |
| 3 | Alerts, Telegram bot | not started |
| 4 | App screens (Next.js) | not started |
| 5 | Public changelog, billing | not started |

Not built yet: Next.js app, Auth.js, BullMQ/Redis workers, Docker Compose, Prisma-backed store
(the schema in `prisma/schema.prisma` validates, but the pipeline currently runs on `FileStore`).

## Pipeline (`src/lib/pipeline.ts`)

fetch (robots.txt, crawl-delay, identifiable UA) → normalize (strip nav, cookie banners, "last updated" lines)
→ SHA-256 → **unchanged: stop, zero LLM calls** → block + word diff → for `subprocessors` sources: table row diff,
deterministic summary, **no LLM** → otherwise one LLM call on the changed fragments only, once per Change →
`Analysis` validated with zod, quotes checked to appear verbatim in the diff.

- Snapshots are append-only; the hash is stored with each one.
- Analysis is one per Change, shared by all tenants (`addAnalysis` is idempotent).
- LLM failure keeps the Change; `retryPending` retries later (max 5 attempts).
- Daily budget guard (`DAILY_LLM_BUDGET_USD`); tokens and cost are stored per Analysis.
- Plain HTTP first; `render: "auto" | "browser"` uses the optional Playwright fallback (not covered by tests yet).

## Run

```bash
npm ci
cp .env.example .env   # set TERMWATCH_CONTACT_EMAIL, optionally ANTHROPIC_API_KEY
npm test
TERMWATCH_CONTACT_EMAIL=you@example.com npm run pipeline            # all sources
TERMWATCH_CONTACT_EMAIL=you@example.com npm run pipeline -- --source github-terms
```

State is written to `.data/` (JSON plus gzipped raw HTML per snapshot).

## Adding a vendor source

Add an entry to `src/catalog/sources.ts` (`id`, `vendor`, `docType`, `url`, `rule.selector`, optional
`rule.remove` / `rule.dropBlocks` for volatile text). Fetch it by hand first and confirm `robots.txt` allows it.
For subprocessor lists use `docType: "subprocessors"`; the table needs a header with "Sub-processor" or "Name".

## Cost per change

Not measured yet (no API key was available in the build session). Cost = tokens in/out × the prices in
`.env`; each Analysis stores its own tokens and cost, so real figures appear after the first live runs.
Unchanged documents and subprocessor changes cost zero LLM calls.

Every summary must carry the disclaimer in `src/lib/disclaimer.ts`.
