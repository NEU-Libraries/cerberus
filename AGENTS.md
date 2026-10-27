# AGENTS.md

Guidance for coding agents working on the DRS codebase.

This file holds the rules that govern how an agent works here. Two pages
written for developers hold the rest, and you must read both before your first
change:

- [`docs/conventions.md`](docs/conventions.md) — the rules every change has to
  satisfy: layering, the cross-repo gap report format, code, comments and the
  interface.
- [`docs/development.md`](docs/development.md) — the mechanics: setup, the spec
  wrappers, worktrees, verification and the migration pause.

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

When making changes to the UI, ensure that any new UI elements are accessible and follow the Bootstrap 5 design system. Run `bin/a11y-lint` on the templates you touch, and add a new page to the axe audit; [`docs/accessibility.md`](docs/accessibility.md) covers both.

## UI Design

When creating a Rails interface whole-cloth or editing one in place, invoke the **`/frontend-design`** skill rather than reaching for bare Bootstrap defaults. The skill is for raising the design quality bar — but on this project it must be paired with the **existing DRS aesthetic** so we don't ship marketing-flashy UI on what is an institutional repository surface.

**The aesthetic, in one phrase:** *restrained, librarian/archival, institutional.*

**Read [`docs/design.md`](docs/design.md) before changing any view, component or stylesheet.** It holds the rules: which container a surface gets (a `.well` is for form sections and footers only), the palette and the four coupled contrast tokens, type, the one-icon-per-concept vocabulary, tabs, buttons, hover, what not to add, and the Audit History tab as the worked example. A local `PreToolUse` hook blocks UI edits until the page has been read in the session.

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

Environment lifecycle and schema changes stay with the developer: the agent does not bring the stack up or down, run `db:migrate`, or open a Rails console. Within that boundary the agent does run a narrow, specific set of commands for verification — restarting Puma or the whole `web` container, running specs (including against a worktree), building Sass, and restoring the worktrees bind mount — exactly as that page documents. Nothing outside them.
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

When a Cerberus feature requires functionality that does not yet exist in atlas_rb or Atlas, do not make cross-repo changes. Produce a gap report for the developer instead, in the five-part format in [`docs/conventions.md`](docs/conventions.md#cross-repository-gaps). It gives the developer enough to prioritize and implement the change in the correct repository as a standalone effort.

## Environment Variables

Each application (Cerberus, Atlas) has its own `.env`, copied from `.env.example`. Never commit a `.env`. The variables that matter are tabled in [`docs/development.md`](docs/development.md#environment-variables).
## Verification

The mechanics live in [`docs/development.md`](docs/development.md) — the two spec wrappers, the test-Atlas lane, the worktree mount, and what to restart after which kind of change. What follows is what the agent owes the developer on top of them.

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

1. The agent writes the migration file(s) and commits them.
2. The agent stops and tells the developer: *"Migration `<filename>` is committed. Please run `docker exec cerberus-web-1 bundle exec rails db:migrate` so `db/schema.rb` regenerates, then let me know — I'll continue."*
3. The developer runs it. The Rails toolchain regenerates `db/schema.rb`.
4. The agent commits the regenerated `db/schema.rb` once the developer confirms, or the developer commits it themselves. Either is fine.
5. The agent continues with the next planned work.

The friction is the point. The trigger is "new migration file", not "worktree task", so it applies to in-place edits equally. [`docs/development.md`](docs/development.md#migrations-are-a-pause-point) explains what a missing `db/schema.rb` breaks for everyone who pulls the branch.

**Never edit `db/schema.rb` directly.** It is generated — `db:migrate` writes it, and a manual edit is silently overwritten the next time migrations run. Express every schema change as a migration file. A local agent hook at `.claude/hooks/schema-rb-guard.sh` enforces this for file edits as a backstop on top of this rule. To commit the *output* of a `db:migrate` the developer has just run, `git add db/schema.rb` via Bash is not gated.
## Code Conventions

The code, comment and layering rules are in [`docs/conventions.md`](docs/conventions.md). The comment standard is the one most often missed: a comment explains *why* the code below it exists, carries no dates, version stamps, planning shorthand or before/after narration, and keeps only the trap inline — the rest goes on a `docs/` page. A local agent hook reports comment density after every edit under `app/`, and names the relevant page when the file already has one.

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
