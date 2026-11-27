# Open Terms Archive datasets: license record

Checked on 2026-11-27 before any import. We use **data only**. No engine code
(`opentermsarchive/engine`, EUPL/AGPL) is copied; our engine is our own.

| Dataset | Content | License (evidence) | Commit checked | Used for |
|---|---|---|---|---|
| [contrib-versions](https://github.com/OpenTermsArchive/contrib-versions) | historical versions of terms (Markdown) | **ODC-By 1.0** (`LICENSE`, README "License": attribute to *Open Terms Archive contributors*) | `8fed42f3c87f3d08471de67d003f252bfdcb1997` | replaying real changes (GitHub ToS, Atlassian Privacy Policy) |
| [contrib-declarations](https://github.com/OpenTermsArchive/contrib-declarations) | service declarations (URL + selectors) | **EUPL-1.2** (`LICENSE`, `package.json`); README states EUPL for "the code", no separate data license | `79e8a214430fefc1018423624d588477f9d035a6` | catalog expansion (isolated, see below) |
| [contrib-snapshots](https://github.com/OpenTermsArchive/contrib-snapshots) | raw snapshots | ODC-By 1.0 (`LICENSE`, README) | `a060ebfe2a8f5152fc02b6a35557fdb3c76488c0` | not used |
| [pga-versions](https://github.com/OpenTermsArchive/pga-versions) | platform governance versions | ODC-By 1.0 (`LICENSE`, README) | `7504262ac8d65ec32e864d71f97df8cd01eebc1b` | not used yet |
| [dating-versions](https://github.com/OpenTermsArchive/dating-versions) | dating services versions | ODC-By 1.0 (README; no `LICENSE` file) | `fda42b9847526253fed060ec364eddf13d8b6814` | not used |
| [france-versions](https://github.com/OpenTermsArchive/france-versions) | French services versions | ODC-By 1.0 (README; no `LICENSE` file) | `5792c567d94e4c9e72cc190cc1eb83132e495e5f` | not used |
| [demo-versions](https://github.com/OpenTermsArchive/demo-versions) | demo data | ODC-By 1.0 (`LICENSE`, README) | `13fab0c927bd117589fa5456a69cc5cabe06eb13` | not used |

## Attribution

Replay results and any text derived from these versions: "Source data: Open Terms Archive contributors
(contrib collection), ODC-By 1.0, https://github.com/OpenTermsArchive/contrib-versions".

## Handling rules

- **Versions (ODC-By):** raw version files are not committed. `npm run ota:export` writes them to `.data/ota/` (git-ignored).
  Only statistics and our own analysis output are committed under `docs/replay/`.
- **Declarations (EUPL-1.2, copyleft):** the repository license covers the whole repo, so we treat declarations as
  potentially EUPL-licensed. The curated import lives in one isolated data file, `data/ota/declarations.imported.json`,
  which stays under EUPL-1.2 with attribution to *Open Terms Archive Contributors*. It is read as data at runtime; no EUPL code is
  linked into the engine. To remove it: delete that file and `src/catalog/ota.ts`'s import. **Needs your confirmation** (see PR notes).
