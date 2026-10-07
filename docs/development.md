# Development

How to set the environment up, run the app, run the specs, and organise a
change. Covers `bin/spec`, `bin/parallel-spec`, `bin/parallel-solr-cores`,
`bin/lib/spec-lane.sh`, `docker-compose.dev.yml`, `docker-compose.local.yml`
and `lib/request_deadline.rb`.

Everything here is procedure. The conventions a change has to satisfy — the
comment standard, the Blacklight and atlas_rb layering rules, the cross-repo gap
report — live in `CLAUDE.md`.

## Setup

The whole stack runs in Docker. You need Docker and a checkout; you do not need
Ruby on the host.

```bash
git clone git@github.com:NEU-Libraries/cerberus.git
cd cerberus
cp .env.example .env          # overrides only; see below
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

`docker-compose.dev.yml` bind-mounts `./` onto `/home/cerberus/web` in the `web`
container, so edits land live without a rebuild. On every boot the entrypoint
(`docker-entrypoint.sh`) runs `db:create` and `db:migrate`, then starts the
dartsass watcher, Solid Queue (`bin/jobs`), and Puma under rdbg.

Seed some objects to look at:

```bash
docker exec cerberus-web-1 bundle exec rake reset:data
```

Then open http://localhost:3000. Port 12345 is the rdbg listener, not the app.

### Environment variables

`.env` is gitignored and copied from `.env.example`, which is the authoritative
list and explains each entry. It carries **overrides only**. Almost every value
has a working default, so a fresh checkout boots with the file left commented
out. The exceptions are `ATLAS_RAILS_MASTER_KEY` and `WORKTREES_ROOT`, below.

You will not find the service URLs in `.env`. `ATLAS_URL` is set on the `web`
service in `docker-compose.yml`. The Solr URL defaults in `config/blacklight.yml`
and the database host in `config/database.yml`. All three name services on the
compose network, not anything host-specific. The test environment repoints
`ATLAS_URL` and `SOLR_URL` itself, in `config/environments/test.rb`.

What you are most likely to set:

| Variable | Purpose |
|---|---|
| `ATLAS` | Pins the Atlas image tag. Unset uses `latest`. `.atlas_version` holds the tag this commit was tested against, and CI pins to it. |
| `ATLAS_RAILS_MASTER_KEY` | Atlas's master key, passed to every Atlas service as `RAILS_MASTER_KEY`. It has no default: compose passes it through as given. CI supplies it from a secret. |
| `WORKTREES_ROOT` | Absolute path to the directory holding your worktrees. Only `docker-compose.local.yml` reads it, to mount that directory into the `web` container. That file fails with a named error when it is unset. |
| `REQUEST_DEADLINE_SECONDS` | Puts the per-request deadline back in development, where it is off by default. See [The request deadline](#the-request-deadline). |
| `TERMS_DOCUMENT_URL` | The full terms document, deposited as a public Work. The `/terms` page links to it. Unset, the page links the Work that `reset:data` seeds, whose path the task stores as a `SiteSetting`, because its NOID changes on every reset. Leave it unset in development; use the Work's handle URL in production. |
| `HANDLE_*`, `CERBERUS_PUBLIC_BASE`, `CERBERUS_IIIF_*` | Handle minting and gated-derivative signing. Compose supplies a dev default for each; see the comments in `.env.example`. An unset `CERBERUS_IIIF_SIGNING_SECRET` serves every derivative ungated. |

Atlas keeps its own `.env`, on the same pattern.

### Encrypted credentials

`config/master.key` is gitignored. Without it every credential resolves to
`nil`. That fails late and obscurely rather than at boot: a request signs with a
missing key and Atlas answers 401. Get the key from a maintainer before you run
anything.

### The request deadline

`RequestDeadline` (`lib/request_deadline.rb`) puts a wall-clock limit on every
request except the streaming routes in its `EXEMPT` list. Puma has no request
timeout of its own, so this is the backstop beneath the per-client deadlines.
`spec/lib/outbound_deadlines_spec.rb` asserts those per-client deadlines.
`config/initializers/request_deadline.rb` mounts the middleware first in the
stack, in every environment.

**Development runs without a deadline.** Rack::Timeout counts wall time on a
thread of its own, and a breakpoint pauses only the request thread. With a
deadline in force, a breakpoint held past the limit ends the request with
`Rack::Timeout::RequestTimeoutException` while you are still on the line. Every
other environment defaults to `RequestDeadline::DEFAULT_SECONDS` (20).

To exercise the deadline in development, set `REQUEST_DEADLINE_SECONDS` in
`.env` and restart `web`. Zero means no deadline. The middleware is mounted
either way, so the stack has the same shape whatever the deadline is.

### Host memory limits

`docker-compose.local.yml` is gitignored. It holds two things that cannot be
shared: a per-service `mem_limit` sized to your machine, and the worktrees bind
mount. Copy the example and edit the numbers to suit your host:

```bash
cp docker-compose.local.yml.example docker-compose.local.yml
```

Then include it in every `up`:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml \
  -f docker-compose.local.yml up -d
```

**Set the limits before you run the suite on a constrained host.** Solr runs
with `-XX:+CrashOnOutOfMemoryError`, so an exhausted heap aborts the process
rather than degrading. Without a per-service limit, one runaway container can
thrash the whole VM and the OOM killer never intervenes. The example file
explains what each number protects against.

**Compose does not pick up a plain `docker-compose.override.yml` here.** Compose
auto-merges an override only when you invoke the base file alone, and Cerberus
comes up with an explicit `-f` chain. That is why the local file has its own
name and has to be named in the chain. (Atlas has no extra `-f` files, so it
uses a plain override.)

## Running specs

Use `bin/spec`. It passes every argument straight through to rspec:

```bash
bin/spec                                    # everything, one process
bin/spec spec/models/work_spec.rb
bin/spec spec/requests --example "embargo"
bin/spec --down                             # release the test Atlas
```

`bin/spec` exists because the test Atlas sits behind the `atlas-test` compose
profile. A plain `up` does not start it, so a bare `docker exec … rspec` fails
in the preflight with `Refusing to run: nothing is listening on …`. The profile
stops a container the specs need only sometimes from holding ~340 MB around the
clock. `bin/spec` brings it up first. It also works out where your checkout
appears *inside* the container, so the same command works from a worktree.

`bin/spec` sets `SMOKE=1` whenever the argument list names something.
`SimpleCov` enforces `minimum_coverage 90` across the whole suite, so any subset
would fail on arithmetic alone; `SMOKE=1` lifts the floor. A bare `bin/spec`
runs everything and keeps the floor.

### The whole suite, sharded

```bash
bin/parallel-spec              # four workers
bin/parallel-spec -n 2         # two
bin/parallel-spec --ephemeral  # run, then release the lane
bin/parallel-spec --down       # release the lane, run nothing
```

Four workers is also the ceiling: only four test Atlas services exist, and
`rake parallel:spec` refuses more. Four workers put the suite at about 220
seconds of test time and about four minutes wall clock, against roughly 495
seconds in a single process.

A sharded run does not check the coverage floor. Each worker exits holding only
a partial merge, so `spec/rails_helper.rb` lifts the floor whenever
`TEST_ENV_NUMBER` is set. The floor stays with the unsharded run, which is what
CI executes.

Each worker owns its own Atlas instance and its own Solr core. Worker 1 uses the
plain `atlas-test` service and the `blacklight-test` core; worker *n* uses
`atlas-test-n` and `blacklight-test-n`. `bin/parallel-solr-cores` creates the
extra cores, and `bin/parallel-spec` calls it before it waits on the lane.

**That order is load-bearing.** The readiness probe is `GET /reset`. A worker
whose core is missing answers 500 there rather than 204: the reset deletes by
query against `blacklight-test-n`, and Solr 404s a core it does not have. The
cores do not survive a Solr recreate. Provisioned after the wait, they would
never exist, because the run would die in the wait before reaching the step
that creates them. If you see `only 1 of 4 test Atlas instances answered GET
/reset`, check that ordering first. `bin/parallel-solr-cores 4` provisions the
cores on their own; it runs on the host, not in the container.

### The lane is left running

Both wrappers leave the test Atlas up when they finish. Bringing it up costs
about fourteen seconds and tearing it down about eleven. That is a fifth of a
run to repay on every invocation while you iterate. A four-worker lane holds
roughly 1.3 GB idle, so release it with `bin/parallel-spec --down` when you are
done, or use `--ephemeral` to run and release in one go.

`--down` refuses while a run holds its lock. Tearing the lane down mid-run
destroys the fixtures that run has already seeded. The damage then surfaces as
a cluster of unrelated failures in whatever file happened to be executing. Set
`LANE_FORCE=1` to override, for a lock held by something genuinely gone.

### Two guards worth recognising

**Only one run at a time.** A run resets its Atlas instance at startup, wiping
its database, its Solr core and its OCFL storage. Two overlapping runs delete
each other's fixtures. `spec/support/exclusive_run_lock.rb` takes an `flock` per
worker, on `/tmp/cerberus-rspec-run.lock` (or `-n.lock`) inside the `web`
container. It aborts the second run with a message naming the lock file. Because
it is `flock`, the kernel releases it when a run dies, so a held lock always
means a live run, never a stale file. A run interrupted with Ctrl-C can leave
its process alive and still holding the lock; look for that when a run will not
start. To run against a genuinely separate Atlas, point
`CERBERUS_RSPEC_LOCK_PATH` at a lock file of its own.

**A run refuses to reset the wrong Atlas.** `before(:suite)` wipes and reseeds
whichever instance `ATLAS_URL` names. That endpoint authenticates *optionally*:
it is the one call that still succeeds with no credentials.
`spec/support/spec_preflight.rb` runs first. It checks that the target is the
test instance, that the signing key is present, and that something is
listening. A misconfigured checkout then gets one message instead of a destroyed
development instance. If it fires, read the message: it names the fix.

### Conventions

- Use request specs, not controller specs, for anything involving
  authentication. Controller specs do not load Warden middleware.
- Clean seeded data up in an `after(:all)` block. Left behind, it collides with
  another file's examples; a guest user that persists into a later file is the
  typical case.
- Specs run in random order. A red run straight after a green one usually means
  ordering, so check the seed before you look for a real regression.
- Share scaffolding containers between examples where you can, but never share
  the container the spec is *of*.

## Working on a worktree

Worktrees keep a multi-file or risky change off the main checkout. Put them all
under one parent, so they are easy to enumerate and so editors and `rg` do not
crawl them as part of the primary checkout:

```bash
git worktree add "$WORKTREES_ROOT/cerberus-<branch>" -b <branch> develop
```

Set `WORKTREES_ROOT` in `.env` (see `.env.example`). Compose reads `.env`, but
your shell does not, so export the same value in your shell to use the commands
on this page as written. Name the leaf directory `<repo>-<branch>` so the same
branch name in a sibling repo stays distinct.

A fresh worktree lacks three files, because all three are gitignored:

1. **`config/master.key`.** Copy it in first: `cp config/master.key
   "$WORKTREES_ROOT/cerberus-<branch>/config/master.key"`. The spec preflight
   refuses the run without it, but copying first saves the round trip.
2. **`app/assets/builds/application.css`.** Without it every spec that renders
   the layout 500s on `Propshaft::MissingAssetError`. That masquerades as
   unrelated failures: an authz spec expecting 403 gets a 500, and dozens of
   examples go red. The tell is that the same spec passes in the main checkout.
   Build it once per worktree:
   ```bash
   docker exec -w "$WORKTREES_ROOT/cerberus-<branch>" \
     cerberus-web-1 bundle exec rails dartsass:build
   ```
3. **`docker-compose.local.yml`.** Only the main checkout's copy is ever read.
   `bin/spec` deliberately pins the compose project directory to the main
   checkout, and takes `.env`, `docker-compose.dev.yml` and
   `docker-compose.local.yml` from there. It takes `docker-compose.yml` from the
   current checkout, so a branch's own service changes do take effect.

Then run the worktree's specs from inside it:

```bash
cd "$WORKTREES_ROOT/cerberus-<branch>"
bin/spec <files>
```

**Never copy worktree files into the main checkout to test them.** That mutates
your own working tree and is a recurring footgun.

### The worktrees mount

The `web` container bind-mounts only the main checkout, so it cannot see a
worktree until `docker-compose.local.yml` mounts the worktrees parent at the
same path on both sides. That mount is what lets `docker exec -w <worktree>`
resolve at all.

**Compose drops the mount whenever it recreates `web`**: on an Atlas update, a
stack rebuild, or any `up` that omits `-f docker-compose.local.yml`. This
happens often. The symptom is `bin/spec` from a worktree failing with `OCI
runtime exec failed: … chdir to cwd … no such file or directory`. Re-run the
full `up` chain. It recreates only `web`, and the mount is additive, so it is
non-destructive. Afterwards the `web` session is fresh, so any browser login is
gone, and the worktree may need `dartsass:build` again.

## Restarting after a change

| What changed | What to run |
|---|---|
| Ruby under `app/` | Nothing. The bind mount and Rails reloading pick it up. |
| A new directory under `app/` | `docker exec cerberus-web-1 bundle exec bin/rails restart`, so Zeitwerk sees it. |
| A job, the queue config, the dartsass watcher | `docker compose … restart web`. `bin/rails restart` only reloads Puma via `plugin :tmp_restart`. |
| A gem | Rebuild the image. The bundle is baked in, not mounted. |
| SCSS, and the watcher looks stale | `docker exec cerberus-web-1 bundle exec rails dartsass:build` |

## Verifying a change

Decide how you will verify before you start, and say what you chose when you
report.

**Specs.** Run the ones covering what you touched: the files you changed, their
callers, and anything your change could plausibly reach. Then run the
environment check:

```bash
docker exec cerberus-web-1 bundle exec rake smoke
```

It runs four examples in about six seconds: credentials that can sign, a layout
that renders, a catalog that reaches Solr, a work that indexes on write. It
needs the test Atlas already up and does not start it, so run it after your
specs. From a cold stack, `bin/spec --tag smoke` runs the same four examples and
brings the lane up itself.

Do not run the full suite routinely. CI runs it unsharded, with the coverage
floor, on every push to `develop` and every pull request against it. Do run it
when the change is broad enough to warrant it: a bootstrap file, a shared
concern, a model everything touches.

**The browser.** For anything with a visible surface, check it in the app rather
than only in a spec. In-place edits on your own branch need nothing special: the
bind mount serves them directly. A worktree branch does: the container mounts
only the main checkout, so you must apply the branch's committed diff there
first.

A preview helper does that. It is a small tool kept outside this repo, because
the same one drives Atlas, and a copy in either `bin/` would drift from the
other. If you need to install or write one, it has to satisfy this contract:

- **Diff from the merge-base of HEAD and the branch, not from HEAD.** Otherwise
  the patch inverts commits made here after the fork.
- **Pass `--binary` and `--no-ext-diff`.** Without the first, added binary
  fixtures fail to apply with `cannot apply binary patch … without full index
  line`. Without the second, a configured external differ emits a side-by-side
  diff that `git apply` rejects as having no valid patches.
- **Restart the whole `web` container, not just Puma,** so the Solid Queue
  worker and the dartsass watcher pick the new code up too. Use `restart`, never
  `up`. `up` re-resolves the compose files and drops the worktrees mount unless
  you pass the full `-f` chain; `restart` reuses the container as it stands.
- **Reverse-apply to clean up, and refuse when the tree has drifted** from the
  patch rather than guessing at it. A file edited mid-preview is the developer's,
  not the tool's.
- **Expect the container's boot to undo part of the revert.** The entrypoint
  runs `db:migrate`, which re-dumps `db/schema.rb` from a database that still
  has the branch's migrations applied. Reverting a patch cannot un-apply a
  migration and should not try. Restore the paths the patch touched after the
  restart, or the tree comes back dirty a second after it was cleaned.

Whatever applies a preview must require a clean tree first, and you must revert
it before the next one.

**Signing in.** Every object reset recreates the stock users, so they are
reliably present. NUID `000000002` carries
`northeastern:drs:repository:staff`; NUID `000000004` is an admin. If a feature
needs a group neither has, treat that as a verification gap and ask rather than
inventing credentials.

**The browser spec lane.** It needs the `selenium` service, which sits behind
the `test` compose profile. Start it, then run the lane:

```bash
docker compose --profile test up -d selenium
docker exec cerberus-web-1 bundle exec rake browser
```

CI does not run this lane, and a default rspec run skips the `:browser` tag. A
green pipeline therefore says nothing about these specs.

The lane includes the axe accessibility audit. [`accessibility.md`](accessibility.md)
covers it, along with `bin/a11y-lint` and the opt-in commit hook.

## Migrations are a pause point

When a change adds a file under `db/migrate/`, stop and run the migration
yourself before going further:

```bash
docker exec cerberus-web-1 bundle exec rails db:migrate
```

This is deliberate friction. A branch that ships migration files without the
matching `db/schema.rb` breaks `db:setup` for everyone who pulls it. Their
`web` container then runs `db:migrate` on every boot, which applies the pending
migration and rewrites `db/schema.rb` in their working tree. That surfaces as a
chronically dirty `db/schema.rb` on develop.

**Never edit `db/schema.rb` by hand.** `db:migrate` generates it, and the next
migration run overwrites a manual edit. Express every schema change as a
migration. A Claude Code `PreToolUse` hook, `.claude/hooks/schema-rb-guard.sh`,
backstops this for agent edits. `.claude/` is gitignored, so the hook lives in
the main checkout's local configuration, not in the repository.

Rollback is per database: `rails db:rollback:primary STEP=n`. The other
database is `queue`, with its migrations in `db/queue_migrate`.
