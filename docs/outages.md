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

## Capabilities

| Capability | Service | What raises | What the reader sees |
|---|---|---|---|
| `repository` | Postgres | `ActiveRecord::ConnectionNotEstablished`, `ActiveRecord::ConnectionFailed` | the static 503 page; the whole site is down |
| `search` | Solr | `Blacklight::Exceptions::ECONNREFUSED`, `Blacklight::Exceptions::RepositoryTimeout`, and the RSolr errors underneath them | the outage page for search |
| `records` | Atlas | `Faraday::ConnectionFailed`, `Faraday::TimeoutError`, or `AtlasRb::ResourceError` with a 502, 503 or 504 | the outage page for records, or the outage banner |
| `uploads` | the uploads volume | `Outage::StorageUnavailable`, raised by `Outage.guard_storage` | the outage page for uploads |
| `jobs` | Solid Queue | nothing a request raises | health endpoints only |
| `images` | Cantaloupe | nothing a request raises | health endpoints only |

`jobs` and `images` have no page. A request never fails on either:
- **Jobs:** jobs are enqueued into Postgres.
- **Images:** both Cantaloupe clients, `IiifManifest` and `ZipEntryWriter`, rescue their own Faraday errors.

That is also why an unhandled `Faraday::ConnectionFailed` can safely be read as
Atlas: no other client lets one escape to a controller.

### Two choices that look wrong

**A bare Atlas 500 is not an outage.** A 500 is as likely to be a bug as a
dependency failure. Calling a bug an outage tells the reader to wait for
something that will not change. Only the gateway statuses that a proxy answers
while Atlas is down count. Atlas does not yet answer its own dependency failures
with a typed 503. That gap is reported separately.

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

**An outage that escapes a controller still gets the outage page.**
`config/initializers/outages.rb` maps the outage exceptions to 503.
`ErrorsController#service_unavailable` and `#internal_server_error` both check
`Outage.for` on the original exception. Both are needed because
`ExceptionWrapper` maps statuses by exact class name. A subclass of a mapped
exception, such as `ActiveRecord::DatabaseConnectionError`, arrives as a 500.

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
outage page. The `web` healthcheck in `docker-compose.yml` uses it.

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

`probe_records` uses `AtlasRb::Maintenance.read`, the cheapest authenticated
read. It shows that Atlas answers, not that Atlas's own Postgres, Solr and
storage are healthy. Atlas has no endpoint that reports those yet.

**The admin page cannot report a database outage.** Signing in needs the DB
session store. `/health/repository` and the log carry that case.
