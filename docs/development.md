# Development

How to set the environment up, run the app, run the specs, and organise a
change. Covers `bin/spec`, `bin/parallel-spec`, `bin/parallel-solr-cores`,
`docker-compose.dev.yml` and `docker-compose.local.yml`.

Everything here is procedure. The conventions a change has to satisfy — the
comment standard, the Blacklight and atlas_rb layering rules, the cross-repo gap
report — live in `CLAUDE.md`.

## Setup

The whole stack runs in Docker. You need Docker and a checkout; you do not need
Ruby on the host.

```bash
git clone git@github.com:NEU-Libraries/cerberus.git
cd cerberus
cp .env.example .env          # every value in it is optional
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

`docker-compose.dev.yml` bind-mounts `./` onto `/home/cerberus/web` in the `web`
container, so edits land live without a rebuild. The entrypoint starts Puma, the
Solid Queue supervisor and worker, and the dartsass watcher.

Seed some objects to look at:

```bash
docker exec cerberus-web-1 bundle exec rake reset:data
```

Then open http://localhost:3000. Port 12345 is the rdbg listener, not the app.

### Environment variables

`.env` is gitignored and copied from `.env.example`, which is the authoritative
list and explains each entry. It carries **overrides only** — every value has a
working default, so a fresh checkout boots with the file left entirely
commented out. The service URLs a developer might expect to find there
(`ATLAS_URL`, the Solr endpoints, the database) are set in
`docker-compose.yml` instead, because they name services on the compose
network rather than anything host-specific.

What you are most likely to set:

| Variable | Purpose |
|---|---|
| `ATLAS` | Pins the Atlas image tag. Unset uses `latest`; the tag this commit was tested against is in `.atlas_version`. |
| `WORKTREES_ROOT` | Absolute path to the directory holding your worktrees. Read only by `docker-compose.local.yml`, to mount that directory into the `web` container. |
| `HANDLE_*`, `CERBERUS_IIIF_*` | Handle minting and gated-derivative signing. Both have dev defaults; see the comments in `.env.example`. |

Atlas keeps its own `.env`, on the same pattern.

### Encrypted credentials

`config/master.key` is gitignored. Without it every credential resolves to
`nil`, which fails late and obscurely rather than at boot — a request signs with
a missing key and Atlas answers 401. Get the key from a maintainer before you
run anything.

### Host memory limits

`docker-compose.local.yml` is gitignored and holds two things that cannot be
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
rather than degrading, and without a per-service limit one runaway container can
thrash the whole VM without the OOM killer ever intervening. The example file
explains what each number is protecting against.

**A plain `docker-compose.override.yml` is not picked up here.** Compose only
auto-merges an override when you invoke the base file alone, and Cerberus is
brought up with an explicit `-f` chain. That is why the local file has its own
name and has to be named in the chain. (Atlas has no extra `-f` files, so it
uses a plain override.)

## Running specs

Use `bin/spec`. It takes every argument straight through to rspec:

```bash
bin/spec                                    # everything, one process
bin/spec spec/models/work_spec.rb
bin/spec spec/requests --example "embargo"
bin/spec --down                             # release the test Atlas
```

It exists because the test Atlas sits behind a compose profile. A plain `up`
does not start `atlas-test`, so a bare `docker exec … rspec` fails in the
preflight with `Refusing to run: nothing is listening on …`. Keeping the service
profiled is what stops a container the specs need only sometimes from holding
~340 MB around the clock. `bin/spec` brings it up first, and works out where
your checkout appears *inside* the container so the same command works from a
worktree.

It also sets `SMOKE=1` whenever the argument list names something. `SimpleCov`
enforces `minimum_coverage 90` across the whole suite, so any subset would fail
on arithmetic alone; `SMOKE=1` lifts the floor. A bare `bin/spec` runs
everything and keeps it.

### The whole suite, sharded

```bash
bin/parallel-spec              # four workers
bin/parallel-spec -n 2         # two
bin/parallel-spec --ephemeral  # run, then release the lane
bin/parallel-spec --down       # release the lane, run nothing
```

Four workers put the suite at about 220 seconds of test time and about four
minutes wall clock, against roughly 495 seconds in a single process.

Each worker owns its own Atlas instance and its own Solr core. Worker 1 uses the
plain `atlas-test` service and the `blacklight-test` core; worker *n* uses
`atlas-test-n` and `blacklight-test-n`. `bin/parallel-solr-cores` creates the
extra cores and `bin/parallel-spec` calls it before waiting on the lane.

**That order is load-bearing.** The readiness probe is `GET /reset`, and a
worker whose core is missing answers 500 there rather than 204: the reset
deletes by query against `blacklight-test-n`, and Solr 404s a core it does not
have. The cores do not survive a Solr recreate, so provisioning them after the
wait made the failure self-sustaining — the run died in the wait without
reaching the step that would have fixed it. If you ever see `only 1 of 4 test
Atlas instances answered GET /reset`, check that ordering first;
`bin/parallel-solr-cores 4` provisions them on their own.

### The lane is left running

Both wrappers leave the test Atlas up when they finish. Bringing it up costs
about fourteen seconds and tearing it down about eleven, which is a fifth of a
run to repay on every invocation while iterating. A four-worker lane holds
roughly 1.3 GB idle, so release it with `bin/parallel-spec --down` when you are
done, or use `--ephemeral` to run and release in one go.

`--down` refuses while a run holds its lock, because tearing the lane down
mid-run destroys the fixtures that run has already seeded — and the damage
surfaces as a cluster of unrelated failures in whatever file happened to be
executing. Set `LANE_FORCE=1` to override, for a lock held by something
genuinely gone.

### Two guards worth recognising

**Only one run at a time.** A run resets the shared Atlas instance at startup,
wiping its database, its Solr core and its OCFL storage. Two overlapping runs
delete each other's fixtures. `spec/support/exclusive_run_lock.rb` takes an
`flock` per worker and aborts the second run with a message naming the lock
file. Because it is `flock`, the kernel releases it when a run dies — a held
lock always means a live run, never a stale file. A run interrupted with Ctrl-C
can leave its process alive still holding it, which is what to look for when a
run will not start.

**A run refuses to reset the wrong Atlas.** `before(:suite)` wipes and reseeds
whichever instance `ATLAS_URL` names, and that endpoint authenticates
*optionally* — it is the one call that still succeeds with no credentials.
`spec/support/spec_preflight.rb` checks the target and the signing key first, so
a misconfigured checkout gets one line instead of a destroyed development
instance. If it fires, read the message: it names the fix.

### Conventions

- Use request specs, not controller specs, for anything involving
  authentication. Controller specs do not load Warden middleware.
- Clean seeded data up in an `after(:all)` block. Left behind, it collides with
  another file — a guest user that persists into `users_spec.rb`, for instance.
- Specs run in random order. A red run straight after a green one usually means
  ordering, so check the seed before you look for a real regression.
- Share scaffolding containers between examples where you can, but never share
  the container the spec is *of*.

## Working on a worktree

Worktrees keep a multi-file or risky change off the main checkout. Put them all
under one parent so they are easy to enumerate and so editors and `rg` do not
crawl them as part of the primary checkout:

```bash
git worktree add "$WORKTREES_ROOT/cerberus-<branch>" -b <branch> develop
```

Set `WORKTREES_ROOT` in `.env` (see `.env.example`). Name the leaf directory
`<repo>-<branch>` so the same branch name in a sibling repo stays distinct.

Three things a fresh worktree does not inherit, because all three are gitignored:

1. **`config/master.key`.** Copy it in first: `cp config/master.key
   "$WORKTREES_ROOT/cerberus-<branch>/config/master.key"`. The spec preflight
   refuses the run without it, but copying first saves the round trip.
2. **`app/assets/builds/application.css`.** Without it every spec that renders
   the layout 500s on `Propshaft::MissingAssetError`, which masquerades as
   unrelated failures — an authz spec expecting 403 gets a 500, and dozens of
   examples go red. The tell is that the same spec passes in the main checkout.
   Build it once per worktree:
   ```bash
   docker exec -w "$WORKTREES_ROOT/cerberus-<branch>" \
     cerberus-web-1 bundle exec rails dartsass:build
   ```
3. **`docker-compose.local.yml`.** Only the main checkout's copy is ever read;
   `bin/spec` pins the compose project directory there deliberately.

Then run the worktree's specs from inside it:

```bash
cd "$WORKTREES_ROOT/cerberus-<branch>"
bin/spec <files>
```

**Never copy worktree files into the main checkout to test them.** That mutates
your own working tree and is a recurring footgun.

### The worktrees mount

The `web` container bind-mounts only the main checkout, so a worktree is
invisible to it until `docker-compose.local.yml` mounts the worktrees parent at
the same path on both sides. That is what lets `docker exec -w <worktree>`
resolve at all.

**The mount is dropped whenever `web` is recreated** — an Atlas update, a stack
rebuild, or any `up`/`restart` that omits `-f docker-compose.local.yml`. This
recurs often. The symptom is `bin/spec` from a worktree failing with `OCI
runtime exec failed: … chdir to cwd … no such file or directory`. Re-run the
full `up` chain; it only recreates `web`, and the mount is additive, so it is
non-destructive. Afterwards the `web` session is fresh, so any browser login is
gone, and the worktree may need `dartsass:build` again.

## Restarting after a change

| What changed | What to run |
|---|---|
| Ruby under `app/` | Nothing. The bind mount and Rails reloading pick it up. |
| A new directory under `app/` | `docker exec cerberus-web-1 bundle exec bin/rails restart` — Zeitwerk needs to see it. |
| A job, the queue config, the dartsass watcher | `docker compose … restart web`. `bin/rails restart` only reloads Puma via `plugin :tmp_restart`. |
| A gem | Rebuild the image. The bundle is baked in, not mounted. |
| SCSS, and the watcher looks stale | `docker exec cerberus-web-1 bundle exec rails dartsass:build` |

## Verifying a change

Decide how you will verify before you start, and say what you chose when you
report.

**Specs.** Run the ones covering what you touched — the files you changed, their
callers, and anything your change could plausibly reach. Then run the
environment check:

```bash
docker exec cerberus-web-1 bundle exec rake smoke
```

Four examples, about six seconds: credentials that can sign, a layout that
renders, a catalog that reaches Solr, a work that indexes on write. It needs the
test Atlas already up and does not start it, so run it after your specs. From a
cold stack, `bin/spec --tag smoke` is the same four examples and brings the lane
up itself.

Do not run the full suite routinely — CI runs it, with the coverage floor, on
every push. Do run it when the change is broad enough to warrant it: a bootstrap
file, a shared concern, a model everything touches.

**The browser.** For anything with a visible surface, check it in the app rather
than only in a spec. In-place edits on your own branch need nothing special —
the bind mount serves them directly. A worktree branch does need something: the
container mounts only the main checkout, so the branch's committed diff has to
be applied there first.

A preview helper does that. It is a small tool kept outside this repo, because
the same one drives Atlas and a copy in either `bin/` would drift from the
other. If you need to install or write one, this is the contract it has to
satisfy:

- **Diff from the merge-base of HEAD and the branch, not from HEAD.** Otherwise
  commits made here after the fork are inverted by the patch.
- **Pass `--binary` and `--no-ext-diff`.** Without the first, added binary
  fixtures fail to apply with `cannot apply binary patch … without full index
  line`. Without the second, a configured external differ emits a side-by-side
  diff that `git apply` rejects as having no valid patches.
- **Restart the whole `web` container, not just Puma,** so the Solid Queue
  worker and the dartsass watcher pick the new code up too. Use `restart`, never
  `up`: `up` re-resolves the compose files and drops the worktrees mount unless
  the full `-f` chain is passed, while `restart` reuses the container as it
  stands.
- **Reverse-apply to clean up, and refuse when the tree has drifted** from the
  patch rather than guessing at it. A file edited mid-preview is the developer's,
  not the tool's.
- **Expect the container's boot to undo part of the revert.** The entrypoint
  runs `db:migrate`, which re-dumps `db/schema.rb` from a database that still
  has the branch's migrations applied — reverting a patch cannot un-apply a
  migration and should not try. Restore the paths the patch touched after the
  restart, or the tree comes back dirty a second after it was cleaned.

Whatever applies a preview must require a clean tree first, and must be reverted
before the next one.

**Signing in.** Stock users are recreated on every object reset, so they are
reliably present. NUID `000000002` carries
`northeastern:drs:repository:staff`; NUID `000000004` is an admin. If a feature
needs a group neither has, treat that as a verification gap and ask rather than
inventing credentials.

There is also a browser spec lane, behind a compose profile of its own:

```bash
docker exec cerberus-web-1 bundle exec rake browser
```

## Migrations are a pause point

When a change adds a file under `db/migrate/`, stop and run the migration
yourself before going further:

```bash
docker exec cerberus-web-1 bundle exec rails db:migrate
```

This is deliberate friction. A branch that ships migration files without the
matching `db/schema.rb` breaks `db:setup` for everyone who pulls it, and every
later spec run quietly applies the pending migration and rewrites the file in
their working tree — surfacing as a chronically dirty `db/schema.rb` on develop.

**Never edit `db/schema.rb` by hand.** `db:migrate` generates it, and a manual
edit is overwritten the next time migrations run. Express every schema change as
a migration. A `PreToolUse` hook at `.claude/hooks/schema-rb-guard.sh` enforces
this for agent edits as a backstop.

Multi-database rollback is per-database: `rails db:rollback:primary STEP=n`.
