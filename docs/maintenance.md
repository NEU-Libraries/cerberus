# Maintenance windows

How Cerberus reads Atlas's read-only maintenance flag, and how it refuses a
write while the window is open.

Source files:

- `app/services/maintenance_mode.rb`
- `app/controllers/concerns/maintenance_gate.rb`
- `app/controllers/admin/maintenance_controller.rb`
- `lib/tasks/maintenance.rake`

## Atlas owns the window

Atlas owns the flag and enforces it. While the window is open, Atlas refuses
every write it receives with a 503 carrying `error: "read_only_mode"`. atlas_rb
raises that as `AtlasRb::ReadOnlyModeError`.

`MaintenanceMode` is the read side: what Cerberus consults to render its banner
and to refuse a write before it leaves the app. `MaintenanceGate` is the refusal
itself. Both are a courtesy layer over Atlas's floor. Neither is the boundary.

The gate exists for two reasons. A librarian meets a page that explains the
window rather than an exception, and a write never travels to Atlas just to be
turned back.

## Reading the window

`MaintenanceMode.window` returns an `AtlasRb::Mash` carrying `read_only`,
`source`, `since`, `message` and `retry_after`.

| Method | Answers |
|---|---|
| `read_only?` | whether the repository is refusing writes |
| `message` | the operator's note for the banner |
| `retry_after` | seconds Atlas asks a refused caller to wait |

`window` caches each read in `Rails.cache` for
`config.x.cerberus.maintenance_ttl` (`CERBERUS_MAINTENANCE_TTL`, default 5
seconds, set in `config/application.rb`). Under a null cache store every call
reads Atlas. That is correct but chatty. Test uses a null store, as does
development with caching off. In test it also keeps one example's window from
leaking into the next.

`reset_cache!` drops the cached state. Every write calls it, so the request that
flips the flag sees its own effect rather than waiting out the TTL.

`acting_nuid` supplies the NUID the read is made as. It uses `Current.nuid`,
which is set per request. A rake task or job has none, so it falls back to
`config.x.cerberus.guest_nuid`.
The read sits on Atlas's authenticated read floor, which the guest fixture
satisfies.

### The two failure modes need opposite answers

`fetch_window` fails open in one direction and closed in the other.

| Failure | Answer | Why |
|---|---|---|
| **Transport** — `Faraday::ConnectionFailed`, `Faraday::TimeoutError`; nothing answered at all | hold the window (`read_only: true`, a 60-second `retry_after`, and a generic message) | this happens while Atlas is being replaced, which is exactly when a window is likely to be open and when Cerberus could not render a page anyway |
| **An HTTP response we cannot read** — any other `StandardError`, or a `nil` read | assume no window | Atlas is up and talking but told us nothing about a window; most often it is a build older than the endpoint |

An Atlas build without the endpoint answers 404, which atlas_rb reads back as
`nil` rather than raising. `fetch_window` therefore ends in `|| no_window`, or
every `read_only?` would raise `NoMethodError` on the nil.

Failing closed on the second case would be far worse than the ugly error a
refused write would produce. It would put the whole site into maintenance mode
on any Atlas hiccup, and it would make Cerberus impossible to deploy ahead of
Atlas.

Atlas is the boundary either way. A write during a window it did not tell us
about is still refused, and `MaintenanceGate`'s `AtlasRb::ReadOnlyModeError`
rescue turns that into the same page.

## Opening and closing the window

`open!(message:, retry_after:, source:)` and `close!(source:)` write the flag
through `AtlasRb::Maintenance.write`. Both drop the cache in an `ensure`. Every
keyword is optional, and `source:` defaults to `'operator'`.

`source:` is either `'operator'` or `'deploy'`, and says which door is acting.
`Admin::MaintenanceController` always acts as `'operator'`. The
`maintenance:open` and `maintenance:close` rake tasks take `SOURCE=`, and the
deploy orchestrator runs them with `SOURCE=deploy`.
Atlas records it and enforces one rule with it. A `deploy` close is refused when
an operator opened the window. A deploy that finishes therefore cannot end a
window a human opened by hand. An operator close clears either.

Atlas answers that refusal with **200 and the unchanged state**, not an error. A
caller that needs to know whether the close landed must read `read_only` off the
return value. `maintenance:close` does, and aborts when the window is still
open.

## Refusing a write

`ApplicationController` includes `MaintenanceGate`, which runs
`block_writes_in_maintenance!` as a `before_action` on every request that is not
exempt. GET and HEAD are exempt, as is anything in `SESSION_ONLY_WRITES`.

The gate keys on the HTTP method rather than an action list, which makes it
fail-closed by construction. A controller added later inherits the refusal
without being enumerated anywhere. The usual objection to method filtering —
that a GET can write — does not apply, because this is not the boundary.

`rescue_from AtlasRb::ReadOnlyModeError` is the backstop. Anything the method
gate lets through still fails, and fails with the same page rather than an
unhandled exception. That covers a GET-shaped write, and an allowlisted action
that turns out to reach Atlas.

### The response renders, it does not redirect

`render_maintenance_notice` renders `errors/service_unavailable` with status 503,
passing the operator's note as the `message` local. It sets `Retry-After` from
`MaintenanceMode.retry_after` when Atlas supplied one. `ErrorsController` also
renders that template for a plain 503, with no locals, so the template must not
require any.

Turbo renders a non-2xx body in place, so the notice lands in the frame the
librarian submitted from. A redirect would need a 303 and would lose that
context.

### What stays open: `SESSION_ONLY_WRITES`

Cerberus's own database keeps taking writes throughout a window. The session
store is what sign-in needs, and an app-wide read-only database would lock out
the operator running the window.

`SESSION_ONLY_WRITES` therefore allows a small set of non-GET requests that
write nothing but the Cerberus session row. Every entry has to be justified by
"this reaches no Atlas write".

| Entry | Justification |
|---|---|
| `devise/sessions#create`, `#destroy` | sign-in reads Atlas (`GET /user`) and writes a session row; sign-out only clears one |
| `accounts#switch` | records which of a person's accounts is acting |
| `download_queue#create`, `#destroy`, `#destroy_all` | the queue lives in the session, and downloads keep working, so assembling one should too |
| `admin/impersonations#destroy` | exiting only — see below |
| `catalog#index` | Blacklight routes search at GET *and* POST. A long query arrives as a POST, so without this a window would refuse searching |
| `catalog#track` | records the result counter in the session so next and previous work from a record page |
| `atlas#process_login` | the NUID sign-in shim, absent in production. Reads Atlas the same way devise does |

### The near-misses that are deliberately absent

Each of these is the sibling of an allowed action and must not be added.

| Action | Why it is not exempt |
|---|---|
| `accounts#prefer` | it writes Atlas's `preferred_account` |
| `atlas#process_find_or_create` | it provisions a user in Atlas |
| Starting an impersonation — neither `view_as` nor `act_as` | both record a session-start `AuditEvent` in Atlas first and fail closed if it does not land, so neither can work during a window whatever this gate does. Refusing them here makes the message clear and saves a round trip |

`admin/impersonations#destroy` is exempt because it is exiting only.
`end_impersonation` tears the session down before it emits the end event, and
rescues `AtlasRb::Error` from that emit. An admin must always be able to leave a
session they have already left. The end event itself is lost during a window: an
impersonation exited inside one leaves no end row in the ledger.

The maintenance surface is not listed either. `Admin::MaintenanceController`
opts out with `skip_before_action`, next to the code the exemption protects.
Closing a window from the browser is the escape hatch. If the gate covered this
controller, a window held by an unreachable Atlas could only be closed from a
shell.
