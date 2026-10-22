# Outages

What a reader sees when a service behind Cerberus stops answering, and how
monitors find out. Cerberus names what the reader lost ("Search is temporarily
unavailable"), never the service that failed. The service names appear only in
the log and on the admin health page.

Source files:

- `app/services/outage.rb` (which exception means which capability, and the copy)
- `app/controllers/concerns/infrastructure_outages.rb` (the 503 page)
- `lib/error_pages_app.rb` and `lib/error_pages/` (the static fallback)
- `config/initializers/outages.rb` (outage exceptions map to 503)
- `app/services/health_check.rb` (the probes)
- `app/controllers/health_controller.rb` (`/health`, for Nagios)
- `app/controllers/admin/health_controller.rb` (the admin health page)
- `app/services/maintenance_mode.rb` (the unreachable state; see also [`maintenance.md`](maintenance.md))
- `app/services/job_queue_stats.rb`, `app/services/latency_histogram.rb`, `app/services/atlas_latency.rb` and `config/initializers/latency_histograms.rb` (the usage figures on the admin health page)

## Capabilities

| Capability | Service | What raises | What the reader sees |
|---|---|---|---|
| `repository` | Postgres | `ActiveRecord::ConnectionNotEstablished`, `ActiveRecord::ConnectionFailed` | the static 503 page; the whole site is down |
| `search` | Solr | `Blacklight::Exceptions::ECONNREFUSED`, `Blacklight::Exceptions::RepositoryTimeout`, and the RSolr errors underneath them | the outage page for search |
| `records` | Atlas | `Faraday::ConnectionFailed`, `Faraday::TimeoutError`, `AtlasRb::BackendUnavailableError`, or `AtlasRb::ResourceError` with a 502, 503 or 504 | the outage page for records, or the outage banner |
| `uploads` | the uploads volume | `Outage::StorageUnavailable`, raised by `Outage.guard_storage` | the outage page for uploads |
| `jobs` | Solid Queue | nothing a request raises | health endpoints only |
| `images` | Cantaloupe | nothing a request raises | health endpoints only |

`jobs` and `images` have no page. A request never fails on either:
- **Jobs:** jobs are enqueued into Postgres.
- **Images:** both Cantaloupe clients, `IiifManifest` and `ZipEntryWriter`, rescue their own Faraday errors.

That is also why an unhandled `Faraday::ConnectionFailed` can safely be read as
Atlas: no other client lets one escape to a controller.

### Two choices that look wrong

**A bare Atlas 500 is not an outage.** Atlas answers its own dependency
failures with a typed 503, `error: "backend_unavailable"`, which atlas_rb raises
as `AtlasRb::BackendUnavailableError`. A 500 is therefore a bug. Calling a bug an
outage tells the reader to wait for something that will not change. The gateway
statuses count too, because a proxy answers them while Atlas itself is down.

`BackendUnavailableError` names the failed dependency, but the reader still
sees "records". The reader lost records, whichever part of Atlas failed.
`BackendUnavailableError` is deliberately not a `ResourceError`, so it never
reaches `Authorizable`'s refusal handler.

**`Outage.for` uses `is_a?`, never `case`/`when`.** `SystemCallError.===` matches
on the errno alone. `Blacklight::Exceptions::ECONNREFUSED === Errno::ECONNREFUSED.new`
is therefore true, so `when` would claim a refusal from any socket as a search
outage. `rescue_from` matches with `===` too, so the handler in
`InfrastructureOutages` re-raises anything that `Outage.for` does not claim.
`spec/requests/outage_pages_spec.rb` pins this.

## Rendering

`InfrastructureOutages` is included in `ApplicationController`. It renders
`errors/outage` with status 503 and `Retry-After: 60`.

**A database outage gets the static page.** The layout signs the reader in
from the DB session, so rendering it would raise again inside the handler.
`render_outage` serves `lib/error_pages/503.html` without a layout instead.

`Authorizable` handles `AtlasRb::ResourceError` as a refusal. It hands a gateway
status to `render_outage` before anything else, and that line must stay first
in its handler.

### The exceptions app

`config.exceptions_app` routes errors through `ErrorsController`, so error
pages share the layout. The layout needs the database and Atlas, so an outage
can fail the error page as well. Without a fallback, Rails then answers with its
plain-text failsafe message.

`ErrorPagesApp` wraps the routed app. If the routed page raises, it serves the
static page for the status from `lib/error_pages/`. If there is no page for that
status, it serves `503.html`.

**The static pages must not live in `public/`.** Rails serves `public/` ahead of
the routes. A `public/404.html` would shadow the routed 404 page. That is why
the old static pages were removed. `spec/lib/error_pages_app_spec.rb` checks
that `public/` stays empty of them.

**An outage that escapes a controller still gets the outage page.** The usual
case is a Postgres outage on a page that writes the session. The controller
finishes, and then the session store fails to save in middleware, outside any
`rescue_from`.

- **Mapping:** `config/initializers/outages.rb` maps the outage exceptions to 503, with their subclasses. `ExceptionWrapper` looks the status up by exact class name, and a failed connect raises `ActiveRecord::DatabaseConnectionError`, not the `ConnectionNotEstablished` that `Outage` names.
- **Status check:** `ErrorsController#service_unavailable` and `#internal_server_error` both check `Outage.for` on the original exception, so an outage gets the outage page whichever status it arrives with.

**Development shows the debug page here instead.** `consider_all_requests_local`
skips the exceptions app, so a middleware failure in development renders Rails'
debug page. An outage raised inside a controller still gets the outage page in
development, because `rescue_from` runs there too.

## Atlas unreachable

`MaintenanceMode` already holds writes shut when Atlas does not answer (see
[`maintenance.md`](maintenance.md#the-two-failure-modes-need-opposite-answers)).
It marks that held window `unreachable`. Then:

- **Banner:** the outage banner replaces the maintenance banner. Only pages that do not need Atlas still render, so the banner says what the reader cannot do.
- **Writes:** `MaintenanceGate` renders the records outage page, not the maintenance page.
- **Admin maintenance page:** it says Atlas is not answering, and offers neither a form nor a close button. Either would be a write to the Atlas that is down.

## Health endpoints

| Path | For | Answers |
|---|---|---|
| `/up` | Swarm and compose | 200 once Puma is serving. It checks no dependency. |
| `/health` | Nagios, or a person with `curl` | 200 or 503, with a JSON body naming each capability `ok` or `unavailable` |
| `/health/<capability>` | Nagios, one service each | 200 or 503, with the body `ok` or `unavailable` |
| `/admin/health` | admins | every service by name, its response time and its error |

**`/up` must not check a dependency.** If it did, a Solr outage would make the
orchestrator restart every `web` container, including the ones serving the
outage page. The `web` and `atlas` healthchecks in `docker-compose.yml` use
each app's own `/up`.

**`/health` is public, so it names no service.** It shows no hostname, version
or error text. `HealthController` inherits `ActionController::API`, so no
session, sign-in or layout sits between the monitor and the answer. That keeps
`/health/repository` answering while Postgres is down.

The per-capability paths suit the stock `check_http` plugin:

```
check_http -H <host> -S -u /health/search -e "HTTP/1.1 200" -s ok -w 2 -c 5
```

### The probes

`HealthCheck.call` caches each result for 10 seconds, because otherwise each
anonymous request would fan out to every service. The admin page passes
`fresh: true`, because the person who opens it is usually watching a service
come back.

The database probes run on the caller's thread. The rest run in threads, each
joined with a 5-second deadline. A probe that has not answered by then is
reported down, and its thread is left to finish. One atlas_rb read can take more
than 30 seconds with retries, which is longer than Nagios waits.

`probe_records` reads Atlas's own report through `AtlasRb::Health.read`, so an
Atlas whose Puma answers while its Postgres, Solr or storage is down reads as
down. The admin page lists each Atlas dependency in the Detail column. An Atlas
older than the endpoint answers 404. The probe then falls back to
`AtlasRb::Maintenance.read`, so Cerberus can still deploy ahead of Atlas.

**The admin page cannot report a database outage.** Signing in needs the DB
session store. `/health/repository` and the log carry that case.

## Usage figures

The admin health page also shows how hard the app is working, in two cards
below the service table.

### Background jobs

`JobQueueStats` reads the Solid Queue tables directly. It reports what is
waiting per queue, the age of the oldest waiting job, and the counts of
running, scheduled, blocked and failed jobs, with the live workers. Mission
Control at `/jobs` holds the per-job detail, so the card links there rather
than repeating it.

**The age of the oldest waiting job is the figure to watch.** A deep queue that
is draining is normal. A waiting job that is twenty minutes old means the
workers have stopped taking work.

**The live-worker count can lag a restart.** A worker killed without
deregistering keeps its row until the supervisor prunes it.
`JobQueueStats` counts heartbeats from the last two intervals (two minutes), not
Solid Queue's five-minute alive threshold, so a ghost lingers for at most two
minutes. In development, every `web` restart leaves one.

The test environment runs the `:test` job adapter, so the queue tables do not
exist there. `spec/services/job_queue_stats_spec.rb` stubs `read_tables`, the
one method that reads them.

### Atlas response times

`config/initializers/latency_histograms.rb` subscribes to atlas_rb's
`request.atlas_rb` event, which fires once per round trip. A retried call
fires once per attempt. `AtlasLatency` adds each call to a `LatencyHistogram`,
which keeps one Redis hash per minute:

- **Fields:** a count per latency bucket (`le_5` … `le_10000`, then `le_inf`), the summed time, failures (an exception or a 5xx) and timeouts.
- **Keys:** `cerberus:latency:<env>:atlas:<minute>`, expiring after two hours. The environment is in the key because development and the specs share one Redis.
- **Reading:** the page sums the last 60 minute-keys, then interpolates p50, p95 and p99 inside the bucket that holds each rank.

**Redis, not `Rails.cache` and not process memory.** Every Puma worker and
every Swarm replica writes to the same keys, so the figures cover the whole
app. Development's cache store is a memory store, which would split them per
process. The histogram therefore connects to `REDIS_URL` itself.

**The percentiles are approximate.** They are only as fine as the bucket edges,
and a call slower than the last edge is reported at that edge. When history or
per-route figures are wanted, the plan is the TimescaleDB design, which stores
one row per request.

**A Redis outage must not slow Atlas calls down.** Each write would otherwise
wait for the one-second connect timeout. After any Redis error,
`LatencyHistogram` stops writing for 30 seconds, and the page says "Redis did
not answer" rather than showing zeros.

**The card shows Atlas's own figures as a second row.** `AtlasLatency.served`
reads `AtlasRb::Metrics.latency` as the signed-in admin, for the same 60-minute
window. Atlas times each request from when it starts the action until it
returns. Cerberus's row also includes the time a call waits inside Cerberus, so
the gap between the two rows is that waiting.

- **Why both rows:** under load the gap can be most of the figure. A dev load test with four clients at once measured a p95 of about 400 ms in Cerberus against 100 ms in Atlas.
- **Timeouts:** Atlas's row shows "n/a", because Atlas never sees a call that timed out on the Cerberus side.
- **Failures:** if Atlas can't give its figures, because its Redis is down, Atlas itself is down, or the reader isn't an admin, `served` returns `nil` and the row says so. Cerberus's row is unaffected.
- **Slowest actions:** the card lists Atlas's five slowest `controller#action` routes by p95, from the same report.

The health probes and the admin page's own `/metrics/latency` read are left
out, because neither is the app's traffic: a monitor polls the probes, and the
page reads the metrics on every load. The recorder is also off in the test environment, so the suite neither
writes timing data nor depends on Redis.
