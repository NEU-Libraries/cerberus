# CLAUDE.md

Guidance for Claude Code when working on the DRS codebase.

This file holds the conventions a change has to satisfy and the rules that
govern how Claude works here. The mechanics — setup, the spec wrappers,
worktrees, verification, the migration pause — are in
[`docs/development.md`](docs/development.md), which is written for a developer
and is worth reading first.

## System Architecture Overview

The Digital Repository Service (DRS) is split into two main applications:

- **Cerberus** (`NEU-Libraries/cerberus`) — The Rails front end. Handles user-facing discovery, deposit, and management interfaces via Blacklight and standard Rails conventions. This is the repo you are currently in.
- **Atlas** (`NEU-Libraries/atlas`) — The API backend. The Valkyrie-powered persistence layer responsible for storing and retrieving metadata and files. Cerberus delegates object persistence to Atlas, but does query Solr directly for search and pagination via Blacklight.

Communication between Cerberus and Atlas is handled through a custom Ruby client library:

- **atlas_rb** (`NEU-Libraries/atlas_rb`) — A Ruby gem that wraps the Atlas API. Cerberus includes this gem as a dependency and uses it for all interactions with the Atlas backend (creating, reading, updating, and deleting repository objects).

```
┌─────────────────────────────────┐
│         Cerberus (front end)    │
│  Rails · Blacklight · UI/Views  │
│                                 │
│  uses atlas_rb gem to talk to ──┼──► Atlas API (back end)
│  the Atlas API                  │         │
└─────────────────────────────────┘    Valkyrie · Solr · PostgreSQL
```

When making changes that involve repository objects (creating/reading/updating/deleting digital objects, files, or metadata), look for atlas_rb client calls rather than direct ActiveRecord or Solr queries — those concerns live in Atlas. Search and pagination, however, are handled by Cerberus directly via Blacklight querying Solr.

When making changes to the UI, ensure that any new UI elements are accessible and follow the Bootstrap 5 design system.

## UI Design

When creating a Rails interface whole-cloth or editing one in place, invoke the **`/frontend-design`** skill rather than reaching for bare Bootstrap defaults. The skill is for raising the design quality bar — but on this project it must be paired with the **existing DRS aesthetic** so we don't ship marketing-flashy UI on what is an institutional repository surface.

**The aesthetic, in one phrase:** *restrained, librarian/archival, institutional.* Concretely:

- **Container chrome.** Two distinct idioms, and they are not interchangeable:
  - **`.well`** — form-section blocks bracket in `.well.p-3.my-3.rounded-3`. It is a **fill only**: `background-color: $well-bg` and nothing else. **No border, no shadow.** It has never had a border and must not gain one: the fill alone is what makes it read as a panel, and `$well-bg` is pinned by contrast maths (see **Palette** below), so it cannot be lightened to compensate for a weaker edge.
  - **The bordered card shell** — `1px solid $gray-300` + `rounded-3` on a white or off-white fill, used by audit history, the admin registry, the deposit form, sets, and full-text snippets. This is the one to match when a **new** component needs a card.

  Either way: subtle shadow at most. Avoid heavy drop shadows, gradients, or coloured card backgrounds.
- **Palette.** The Cerberus tokens in `app/assets/stylesheets/_colors.scss` are deliberately desaturated from Bootstrap defaults — `$blue: #2666a6` (navy/teal), `$success: darkened $green: #18bc9c` (teal-green, not punchy emerald), `$danger: #e74c3c`, footer `#385775`. Reach for these via SCSS variables rather than hardcoding hex. When adding new tones (e.g. action-typed audit colours), derive *desaturated* values, not Bootstrap candy.

  **Four tokens are a coupled system — do not hand-tune them.** `$link-blue`, `$well-bg`, `$gray-100` and `$gray-900` are pinned to each other by two opposing WCAG rules. Ordinary links carry no underline, so a link must clear 4.5:1 against every background it sits on (pushing it *darker*) **and** 3:1 against surrounding body text (pushing it *lighter*). The window between those is a few thousandths of relative luminance wide, and two of the four current ratios are hairlines (4.51 against 4.50, 3.01 against 3.00). `spec/assets/color_contrast_spec.rb` asserts all of them; run it after touching any of the four. Darkening `$link-blue` to `$blue` looks obvious and silently trades one audit failure for another — it has been tried.

  Hue, though, is free: contrast depends on relative luminance alone, so any hue at the required lightness is fair game.
- **Typography & numerics.** Bootstrap defaults for body. For tabular data (audit rows, NUIDs, file sizes, timestamps), turn on `font-variant-numeric: tabular-nums` and consider a monospace chip — identifiers should *look like* identifiers, not body words.
- **Iconography.** Font Awesome solid set is already wired in. Match existing usage: `fa-folder-open` (Collection), `fa-users` (Community), `fa-file*` (Work / files). New iconography should be semantic + restrained.
- **Tabs / nav.** The Edit pages use Bootstrap `nav-tabs` with `data-controller="tab-hash"`. Add new tabs by extending that pattern; don't introduce a different navigation idiom.
- **Don't.** Don't introduce Tailwind, a different CSS framework, or a different design system. Don't add new web fonts. Don't add maximalist effects (gradient meshes, grain overlays, animated heroes) — they fight the institutional register the rest of the site sets.

**Reference example — the Audit History tab.** When in doubt about how to combine "use the skill" with "match this aesthetic", read these:

- `app/views/audit_events/_history.html.haml` — card-shell + header-strip pattern, gated render, partial dispatch.
- `app/views/audit_events/_event_*.html.haml` — per-action partials sharing helper-rendered cells, varying only the action chip's class.
- `app/helpers/audit_events_helper.rb` — formatting helpers (timestamp split, NUID chip, action descriptor table with a generic fallback for unknown verbs).
- `app/assets/stylesheets/cerberus.scss` (search `audit-history` / `audit-event-table`) — left rail via `::before` + tinted action chips driven by a `--audit-action-color` CSS custom property, so adding a new tone is one map entry + one CSS line. Tones are derived via `color-mix(in srgb, ..., white)` for the chip background; full tone for icon + label.

That component is the worked example of the register to land on: a forensic ledger that fits next to Blacklight's search UI without looking like a different product. Use it as a starting point when designing comparable admin / metadata / audit surfaces.

## Project Status

Cerberus, atlas_rb, and Atlas are all under active development and **not yet feature-complete**. Expect missing endpoints, partially wired flows, and binding gaps as work proceeds.

When you encounter a TODO, a missing capability, or behavior that does not match expectations, produce a structured gap report (see "Cross-Repo Gap Reporting" below) rather than working around it silently or making cross-repo changes. Gap reports are the primary mechanism for capturing things still to do, or places where reality needs to be remedied to match expectations — they let the developer prioritize the fix in the correct repo.

Treat the Atlas OpenAPI spec and atlas_rb YARD docs as snapshots of what currently exists, not the eventual contract.

## Cerberus — Front End

**Core stack:** Ruby on Rails, Blacklight, atlas_rb gem, Bootstrap 5

Cerberus is responsible for:
- User authentication and authorization
- Deposit and ingest workflows
- Search and discovery UI (via Blacklight)
- Presentation/show pages for repository objects
- Admin interfaces

### Development Setup

Setup, the spec wrappers, worktree mechanics and the migration pause are all in [`docs/development.md`](docs/development.md). Read that before running anything.

Environment lifecycle and schema changes stay with the developer: Claude does not bring the stack up or down, run `db:migrate`, or open a Rails console. Within that boundary Claude does run a narrow, specific set of commands for verification — restarting Puma or the whole `web` container, running specs (including against a worktree), building Sass, and restoring the worktrees bind mount — exactly as that page documents. Nothing outside them.
### Blacklight

The search/discovery interface is powered by Blacklight, which queries Solr directly. Blacklight configuration — facets, search fields, sort fields — lives in `CatalogController` and associated search builder classes. Keep Blacklight configuration changes in those files, not scattered across the app.

### atlas_rb — API Client Gem

Cerberus interacts with the Atlas backend exclusively through the `atlas_rb` gem. When working on features that create, read, update, or delete repository objects:

- Find the relevant atlas_rb client calls — do not bypass the gem with direct HTTP requests or database queries against Atlas's store.
- The gem source lives at `NEU-Libraries/atlas_rb`. If you need to understand the API contract, that is where to look.
- Configuration for the Atlas connection (base URL, credentials, etc.) will be in Cerberus's `.env`.
- If a change appears to require modifications to Atlas or atlas_rb, do not make those changes directly. Instead, produce a structured gap report for the developer (see "Cross-Repo Gap Reporting" below).

## Atlas — API Backend

**Core stack:** Ruby on Rails (API mode), Valkyrie, Solr, PostgreSQL

Atlas is the authoritative persistence layer for the DRS. It is responsible for:
- Storing and retrieving repository object metadata (via Valkyrie → PostgreSQL)
- Indexing objects into Solr for search
- Managing file storage via Valkyrie's storage adapters
- Exposing a REST API consumed by Cerberus (through atlas_rb)

### Valkyrie Architecture

Atlas uses Valkyrie as its data mapper, abstracting persistence across PostgreSQL (primary metadata store) and Solr (search index). Solr and PostgreSQL consistency is handled internally by Atlas — from Cerberus's perspective, a single atlas_rb call such as `AtlasRb::Collection.create(params[:parent_id])` is all that is needed; Atlas takes care of the rest.

## atlas_rb — Client Gem

The `atlas_rb` gem (`NEU-Libraries/atlas_rb`) is the interface contract between Cerberus and Atlas. Refer to the gem's YARD documentation and README for available resource classes, methods, and usage examples. Any required changes to Atlas or atlas_rb should be handled as standalone work in their respective repositories, separate from Cerberus — use the gap reporting process below.

### Cross-Repo Gap Reporting

When a Cerberus feature requires functionality that does not yet exist in atlas_rb or Atlas, do not make cross-repo changes. Instead, produce a structured gap report for the developer with the following format:

- **Cerberus feature:** What you are building and why the gap blocks it.
- **What is needed:** The specific method, endpoint, or capability that is missing.
- **Atlas status:** Does the backend endpoint already exist? Check the Atlas OpenAPI spec at `https://raw.githubusercontent.com/NEU-Libraries/atlas/develop/openapi/openapi.yaml`.
- **Gap type:** "binding-only" (Atlas endpoint exists but atlas_rb lacks a wrapper) or "new endpoint" (Atlas itself needs new functionality).
- **Suggested implementation:** A brief sketch of the atlas_rb method signature and/or Atlas endpoint, if applicable.

This report gives the developer enough information to prioritize and implement the change in the correct repository as a standalone effort.

## Environment Variables

Each application (Cerberus, Atlas) has its own `.env`, copied from `.env.example`. Never commit a `.env`. The variables that matter are tabled in [`docs/development.md`](docs/development.md#environment-variables).
## Verification

The mechanics live in [`docs/development.md`](docs/development.md) — the two spec wrappers, the test-Atlas lane, the worktree mount, and what to restart after which kind of change. What follows is what Claude owes the developer on top of them.

**Plan the verification before starting the work,** and say what you chose when you report. Naming the specs you judged sufficient is part of the report, so the developer can see the reasoning rather than just the result.

**Run the specs covering what you touched, then `rake smoke`.** Choosing them is your call: the files you changed, their callers, and anything your change could plausibly reach. Do not run the full suite as a matter of routine — CI runs it, with the coverage floor, on every push. Do run it when the change is broad enough to warrant it (a bootstrap file, a shared concern, a model everything touches), and say so when you do.

**Restart when the change needs it.** `docker exec cerberus-web-1 bundle exec bin/rails restart` reloads Puma. A change reaching the Solid Queue supervisor or worker, the dartsass watcher, or anything else the entrypoint launches needs a full `docker compose … restart web`, because `bin/rails restart` only reloads Puma via `plugin :tmp_restart`.

**After any UI change, verify it in the browser with Playwright MCP** before considering the task complete.

When capturing screenshots with `browser_take_screenshot`, always pass `filename: /tmp/playwright-mcp/<name>.png`. The Playwright MCP permits only two write roots — `/tmp/playwright-mcp` (its throwaway output dir) and the repo checkout — so a **bare `/tmp/<name>.png` is *denied*** ("outside allowed roots"), and a bare or relative filename resolves against the checkout, dropping the screenshot into the working tree where it needs manual cleanup and risks being staged. `/tmp/playwright-mcp` is where `browser_snapshot` already writes and is throwaway.

**Authenticated verification.** Use the stock users, which are recreated on every object reset (see Atlas's [`MaintenanceController#reset`](https://github.com/NEU-Libraries/atlas/blob/develop/app/controllers/maintenance_controller.rb#L27)) and so are reliably present. NUID `000000002` carries `northeastern:drs:repository:staff`; NUID `000000004` is an admin. If a feature needs a different group or role than either holds, report that as a verification gap and ask the developer rather than inventing credentials.
## Worktree Workflow

- Before editing, confirm you are in the correct worktree. Never apply a change to develop or to an unrelated worktree.
- Run a worktree's specs with `bin/spec` from inside the worktree. Never copy worktree files into the main checkout, and don't invent other ad-hoc verification steps.
- Before declaring a worktree complete, run rubocop, `rake smoke`, and the specs covering the patch. The version-bump gate re-runs rubocop and `rake smoke` for itself; CI owns the full suite.
- Bump the version exactly once per worktree, as the last commit. If more than one bump lands, soft-reset and consolidate.
## Migrations are an architectural pause point

When a change adds a file under `db/migrate/`, **stop and ask the developer to run `db:migrate` before continuing.** The flow:

1. Claude writes the migration file(s) and commits them.
2. Claude stops and tells the developer: *"Migration `<filename>` is committed. Please run `docker exec cerberus-web-1 bundle exec rails db:migrate` so `db/schema.rb` regenerates, then let me know — I'll continue."*
3. The developer runs it. The Rails toolchain regenerates `db/schema.rb`.
4. Claude commits the regenerated `db/schema.rb` once the developer confirms, or the developer commits it themselves. Either is fine.
5. Claude continues with the next planned work.

The friction is the point. The trigger is "new migration file", not "worktree task", so it applies to in-place edits equally. [`docs/development.md`](docs/development.md#migrations-are-a-pause-point) explains what a missing `db/schema.rb` breaks for everyone who pulls the branch.

**Never edit `db/schema.rb` directly.** It is generated — `db:migrate` writes it, and a manual edit is silently overwritten the next time migrations run. Express every schema change as a migration file. A `PreToolUse` hook at `.claude/hooks/schema-rb-guard.sh` enforces this for `Edit` / `Write` / `MultiEdit` as a backstop on top of this rule. To commit the *output* of a `db:migrate` the developer has just run, `git add db/schema.rb` via Bash is not gated.
## Code Conventions

- Standard Ruby/Rails conventions: snake_case, RESTful controllers, thin controllers with logic in service objects or models.
- Do not add direct ActiveRecord queries or raw HTTP calls in Cerberus for anything that should go through atlas_rb.
- Keep Blacklight configuration in `CatalogController` and search builder classes.

### Comments explain the *why* of the code below them

A comment earns its place only if it explains why the code immediately below it exists, and it must still make sense to a reader two years from now with **no access to git history or planning docs**. Keep them to ~2–3 sentences.

Do **not** write temporal or working-artifact comments:

- **No** dates, app-version stamps (`2.9.x`), or `(Hit/Fixed YYYY-MM-DD)` markers.
- **No** workstream/planning shorthand: `piece N`, `Q<n>`, "gap report", "position paper", "carve-out" (as a planning label), named initiatives, or `~/projects/gap_reports` pointers.
- **No** before/after narration — "used to", "no longer", "previously", "was X, now Y". Describe the *current* design and its reason; the old design lives in git.

Do keep genuine non-obvious rationale, wire-contract / API constraints, and real gotchas — but **de-date them**: keep the lesson, drop the incident (e.g. "merging `:fq` drops the gated-discovery clause — use `with_filters`" is good; the date it bit us is not). This is a *why*-comment standard, not a no-comments rule.

### Most of the *why* lives in `docs/`, not in the file

Read **`docs/README.md`** before adding a file header. Cerberus keeps knowledge in three places — code, specs, and `docs/*.md` — and the third holds the per-component explanation that used to accumulate as long headers: routing tables, retry-safety arguments, Atlas wire contracts, and why a design rejected the obvious alternative.

What that leaves in the source file is the **trap**. Ask: would someone editing *this line* break something without this comment? A wire-contract gotcha, an ordering constraint, a rule that looks redundant but is not, and every `rubocop:disable` justification stay inline. Everything else goes on a page, and the file keeps a one-line pointer to it.

Target comments under ~35% of a file's non-blank lines, and know that it is a target rather than a gate — if a comment would cost someone a bug, keep it and go over. Files under 25 lines of code are exempt, having no denominator to earn a budget with. A `PostToolUse` hook reports the number after every edit under `app/`, and names the relevant page when the file already has one.

Prefer a spec to a page whenever the claim is testable. A spec fails when someone breaks it; prose does not.

## Code Intelligence

The `ruby-lsp` plugin is installed and gives the `LSP` tool. Prefer it over `rg` for Ruby navigation, but know where it is blind — the fallback is `rg` plus Read. Positions are 1-based line **and** character, so read the file to find the spot, then call `LSP`.

**Use it for:**

- `documentSymbol` — an outline of one file. The cheapest way to see a large helper or controller.
- `goToDefinition` / `findReferences` — both cover `app/` and `spec/`.
- `hover` — the signature plus the doc comment. This is what earns the plugin its place here: hover on an `AtlasRb::*` call renders the gem's whole YARD block (params, return value, which statuses raise), so you do not have to open the gem to read the contract.

**Hover needs a call site.** Hover on the name in a `def` line returns nothing. Put the cursor where the method is *called*.

**Do not call these — the server does not implement them:** `prepareCallHierarchy`, `incomingCalls`, `outgoingCalls`, `goToImplementation`. Each one costs a round trip to learn that again. For "who calls this", use `findReferences`.

**`workspaceSymbol` is a weak search, not a lookup.** It matches fuzzily, and it leaks host gems that are not in the bundle. Use `rg` when you know the name.

**It indexes a gem's `lib/`, never a gem's `app/`.** `AtlasRb::*` resolves, and so does `Blacklight::SearchBuilder`. But `Blacklight::Catalog`, `Blacklight::SearchService`, and every Blacklight component and view sit in the gem's `app/` tree and return "No definition found" — that is most of the surface this app overrides. For Blacklight internals, read the gem.

**Read gem source in the container, not on the host.** The LSP server runs on the host under RVM, so its results point at host RVM paths. The two bundles match today, but the container is what Cerberus actually runs.

**Do not kill the ruby-lsp process to force a reindex.** It respawns, but the client stays desynced and every later `LSP` call fails for the rest of the session. Use `/reload-plugins`.

## Repositories

| Repo | Role |
|------|------|
| [NEU-Libraries/cerberus](https://github.com/NEU-Libraries/cerberus) | Rails front end (this repo) |
| [NEU-Libraries/atlas](https://github.com/NEU-Libraries/atlas) | Valkyrie-powered API backend |
| [NEU-Libraries/atlas_rb](https://github.com/NEU-Libraries/atlas_rb) | Ruby client gem for Atlas API |

## Useful References

- [Valkyrie documentation](https://github.com/samvera/valkyrie)
- [Blacklight documentation](https://github.com/projectblacklight/blacklight/wiki)
- [Samvera community](https://samvera.org/)
