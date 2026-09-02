# Administration

How an `/admin/*` surface is gated and breadcrumbed, and how the admin ledger
records what happened.

Source files:

- `app/controllers/admin/base_controller.rb`
- `app/models/admin_notice.rb`

The role predicates these gates ask about — `admin?` and `admin_delegate?` — are
in [`docs/identity.md`](identity.md). The write gates on resource controllers are
in [`docs/authorization.md`](authorization.md).

## The gate on an admin surface

Anything mounted under `/admin/*` inherits from `Admin::BaseController`, which
keeps the role gate consistent and fail-closed: only `:admin` passes.

`require_admin` and `require_admin_or_delegate` both render
`errors/forbidden` with a 403 and the application layout, so a refusal is a
friendly page rather than a raised exception.

A handful of subclasses — the devolved-admin surfaces — opt into the broader gate
per controller:

```ruby
skip_before_action :require_admin
before_action :require_admin_or_delegate
```

That is a per-controller override, not a change to the base class. The default
stays strict so a new `/admin/*` controller is admin-only unless it deliberately
opts out.

## Breadcrumbs

`Admin::BaseController` owns the shared trail, `Administration / <section>`.

| Level | Who declares it |
|---|---|
| `Administration` root | `BaseController`, prepended to every trail |
| The section | the subclass, via `breadcrumb_for <label>, <index path helper>` — for example `breadcrumb_for 'Replace a file', :admin_files_path` |
| The leaf (`new`, `edit`, `manage`, …) | the action itself |

The dashboard is the hub, declares nothing, and shows no breadcrumb.

Each admin view renders the trail itself with `= render 'admin/breadcrumb_header'`.
This follows the per-view `:container_header` pattern rather than a custom admin
layout, which would double-render the view through Blacklight's layout.

Both `breadcrumb` calls pass `match: :exact`. Loaf's default inclusive match
treats `/admin` as current on every `/admin/*` path, which would mark
"Administration" as the current crumb — a dead end instead of a link back to the
hub — and would do the same to a section on its own sub-pages.

## The admin ledger

`AdminNotice` is a write-once record that something happened, and it is the whole
of the ledger. Nothing is worked inside Cerberus: staff read a list, act on the
object's own surface, and coordinate with each other and with depositors off-site.
So there is no lifecycle on these rows and no update path.

### Why one table

Two families share it because nothing structural separates them. A request
("somebody asked for this work to be withdrawn") and an event ("a cascade
finished") are both an attributed fact with a subject and some detail. They
differ only in which question a reader is asking, which is exactly what the two
ledger tabs are: a filter on `kind`.

| Family | Constant | What it holds |
|---|---|---|
| Requests | `REQUEST_KINDS` | what a depositor may ask staff to do but cannot do themselves: `request_withdraw`, `request_move`, `request_restrict` |
| Activity | `ACTIVITY_KINDS` | what the repository did on its own account: `load_report`, `work_completion_mismatch`, `visibility_cascade`, `set_reindex`, `showcase_promotion`, `set_privatize`, `set_sentinel_apply` |
| Digest | `DIGEST` | `daily_digest` — a whole day, summed up |

The digest is its own family because it is a different size of thing. Every other
row is one event, and a page-sized summary among them buries them and reads badly
itself.

`request_action` strips the prefix off a request kind, giving the verb inside it:
`withdraw`, `move`, `restrict`.

### The payload

`payload` holds kind-specific detail rather than prose, because two renderers read
it: the ledger builds paths from the NOIDs it carries, and a mailer would build
absolute URLs from the same fields. A rendered link could serve neither, since it
fixes the host — or omits it — at write time.

`detail(key)` is the only reader. `jsonb` round-trips to string keys, so a caller
that wrote `payload: { genre: … }` reads it back as `"genre"`, and going through
one method means no caller has to know which side of the write it is on.

### Validation

`kind` must be one of `KINDS`, and `subject` and `occurred_on` must be present.

A requester and a subject NOID are required per kind rather than as `NOT NULL`
columns, because the shared table also holds activity rows, which have no
requester and often no subject. A request with nobody asking, or nothing asked
about, is a row nobody could act on.

### Ordering and filtering

| Scope | Order or filter |
|---|---|
| `newest_first` | `created_at` descending |
| `by_day` | `occurred_on` descending, then `created_at` descending |
| `oldest_first` | `created_at` ascending |
| `on_day(day)` | rows for one `occurred_on` |
| `requests`, `activity`, `digests` | one family |
| `of_kind(kind)` | one kind, falling through to everything on an unrecognised value |

Digests use `by_day` because they are ordered by the day they are about, not the
moment they were written: a re-run, or a backfill of several days at once, must
not shuffle them out of calendar order.

`of_kind` falls through to everything rather than to nothing, so a hand-typed
query string cannot render an empty page with no explanation.

`default_occurred_on` stamps the app-zone date before validation. Bucketing by a
date column rather than a `created_at` range keeps a job that runs late — or a
re-run — attributed to the day it is about.
