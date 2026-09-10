[![Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/dgcliff/b2d04df150116448fb76929c8c570f9c/raw/cerberus-coverage.json)](https://github.com/NEU-Libraries/cerberus/actions/workflows/build_test.yml) [![Build and Test](https://github.com/NEU-Libraries/cerberus/actions/workflows/build_test.yml/badge.svg)](https://github.com/NEU-Libraries/cerberus/actions/workflows/build_test.yml)

# Cerberus

Rails front end for **Cerberus** — the web application behind Northeastern
University Library's Digital Repository Service (DRS).

Cerberus owns everything a person sees and does: sessions and authorization,
deposit and ingest, search and discovery, the show pages, and the admin
surfaces. It owns almost no repository content. Durable identifiers (NOIDs),
MODS metadata, the resource hierarchy and every file's bytes live in
[Atlas](https://github.com/NEU-Libraries/atlas), which Cerberus reaches only
through [atlas_rb](https://github.com/NEU-Libraries/atlas_rb).

## How it fits together

```
                Browser / SSO
                      │
                      ▼
      ┌───────────────────────────────────┐
      │             Cerberus              │  ← this repo
      │  Rails 8 · Blacklight 9 · Haml    │
      │  Solid Queue · Bootstrap 5        │
      │                                   │
      │  sessions · deposit · discovery   │
      │  show pages · admin · analytics   │
      └───────────────────────────────────┘
           │                        │
           │ reads: search,         │ reads + writes,
           │ facets, pagination     │ signing an assertion
           ▼                        ▼
      ┌─────────┐            ┌──────────────┐
      │  Solr   │            │   atlas_rb   │
      └─────────┘            └──────────────┘
           ▲                        │
           │                        │ HTTP · Bearer <ES256 JWT, iss=cerberus>
           │ indexes                ▼
           │                 ┌──────────────────────────────┐
           └─────────────────│            Atlas             │
                             │ Rails API · Valkyrie · OCFL  │
                             │ PostgreSQL · Solr            │
                             └──────────────────────────────┘
```

**Cerberus reads Solr directly and never writes it.** That asymmetry is the one
thing to internalise about this codebase. Blacklight queries Solr for search,
facets and pagination, because putting an API hop between a search box and its
index would buy nothing. Every *write* goes through atlas_rb, and Atlas is what
indexes the result. So a document that looks stale in search is an Atlas
indexing question, not a Cerberus one.

Cerberus authenticates to Atlas by **signing a short-lived assertion** — an
ES256 JWT whose `sub` is the acting user — rather than by holding a
long-lived credential. Acting-as rides a signed `obo` claim on the same token.
Atlas verifies both against Cerberus's published keyset.

## What lives where

| Concern | Home |
|---|---|
| Sessions, SSO, authorization, group and role gating | Cerberus |
| Deposit forms, batch ingest (XML, IPTC, multipage) | Cerberus |
| Search, facets, sorting, pagination | Cerberus → Solr |
| Show pages, IIIF viewer, downloads and packaging | Cerberus |
| Admin surfaces, audit rendering, usage analytics | Cerberus |
| NOIDs, MODS metadata, the resource hierarchy, file bytes | Atlas |
| Solr indexing, OCFL versioning, derivative generation | Atlas |
| Handle minting | Atlas mints; Cerberus links |

The rule that follows: **never bypass atlas_rb** for anything that is a
repository object. No direct HTTP to Atlas, and no ActiveRecord standing in for
something Atlas owns. Where a feature needs an endpoint that does not exist yet,
the answer is a gap report rather than a cross-repo change — see `CLAUDE.md`.

## Cerberus's own database

Cerberus does keep a PostgreSQL database, which surprises people who have
absorbed the rule above. It holds only what is Cerberus's own and has no
repository meaning:

| Group | Tables |
|---|---|
| Session and identity state | `sessions`, `groups`, `loaders`, `user_agents` |
| Ingest bookkeeping | `load_reports`, `xml_ingests`, `iptc_ingests`, `multipage_ingests` |
| Usage analytics | `impressions` and its daily rollups (TimescaleDB) |
| Notices and messaging | `admin_notices`, `messages`, `message_receipts` |
| Discovery furniture | `searches`, `bookmarks`, `sentinels`, `legacy_identifiers` |

No Work, Collection or Community row exists here. `app/models/work.rb` and its
siblings are presenters over Atlas responses and Solr documents, not
ActiveRecord models.

## Getting started

You need Docker and a checkout. You do not need Ruby on the host.

```bash
git clone git@github.com:NEU-Libraries/cerberus.git
cd cerberus
cp .env.example .env
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

Seed some objects to look at, then open http://localhost:3000:

```bash
docker exec cerberus-web-1 bundle exec rake reset:data
```

You will need `config/master.key` from a maintainer. It is gitignored, and
without it every credential resolves to `nil` — which fails late, as a 401 from
Atlas, rather than at boot.

**[`docs/development.md`](docs/development.md) is the full setup and workflow
guide**: host memory limits, the spec wrappers, worktrees, what to restart after
which kind of change, and the migration pause point.

## Running the specs

```bash
bin/spec                                 # everything, one process
bin/spec spec/models/work_spec.rb        # anything rspec accepts
bin/parallel-spec                        # the whole suite, four workers
bin/parallel-spec --down                 # release the test Atlas lane
```

Both wrappers start the test Atlas, which sits behind a compose profile — a bare
`docker exec … rspec` fails in the preflight until something does. Four workers
put the suite at about four minutes against roughly eight in one process. The
details, including the run lock and the reset preflight, are in
[`docs/development.md`](docs/development.md#running-specs).

## Documentation

| What you need | Where |
|---|---|
| Setting up, running things, organising a change | [`docs/development.md`](docs/development.md) |
| How one component works, while you edit it | [`docs/`](docs/README.md) |
| The conventions a change has to satisfy | [`CLAUDE.md`](CLAUDE.md) |
| The Atlas API contract | Atlas's `/docs`, and its `openapi/openapi.yaml` |
| Using the repository as a depositor or reviewer | the user guide (`cerberus-guide`) |
| Repository software, as a Rails developer new to it | the developer primer (`cerberus-primer`) |

`docs/` holds the per-component explanation that is too long to sit in a source
file — wire contracts with Atlas, retry-safety arguments, and the reason a
design rejected the obvious alternative. Each page names the files it covers,
and those files point back.

## Stack

- Ruby 3.2, Rails 8, PostgreSQL 14 via
  [TimescaleDB](https://www.timescale.com) (for the impression rollups)
- [Blacklight](https://github.com/projectblacklight/blacklight) 9 over Solr for
  discovery, with search builders in `app/models/*_search_builder.rb` and the
  configuration kept in `CatalogController`
- [atlas_rb](https://github.com/NEU-Libraries/atlas_rb) for every repository
  read and write
- [Solid Queue](https://github.com/rails/solid_queue) for background jobs —
  ingest fan-out, derivative requests, packaging, analytics rollups
- [Haml](https://haml.info) templates, [ViewComponent](https://viewcomponent.org)
  where Blacklight expects one, Bootstrap 5 and Font Awesome
- [Propshaft](https://github.com/rails/propshaft),
  [importmap-rails](https://github.com/rails/importmap-rails),
  [dartsass-rails](https://github.com/rails/dartsass-rails), Turbo and Stimulus
- [Devise](https://github.com/heartcombo/devise) for sessions, with a custom
  strategy and the NUID as the identity Cerberus asserts to Atlas
- [Cantaloupe](https://cantaloupe-project.github.io) as the IIIF image server,
  and a local [Handle.Net](https://www.handle.net) server for identifier
  resolution in development

## Related repositories

| Repo | Role |
|---|---|
| [cerberus](https://github.com/NEU-Libraries/cerberus) | Rails front end (this repo) |
| [atlas](https://github.com/NEU-Libraries/atlas) | Valkyrie-powered API backend |
| [atlas_rb](https://github.com/NEU-Libraries/atlas_rb) | Ruby client for the Atlas API |

## License

Internal Northeastern University Libraries project — contact the maintainers
for licensing.
