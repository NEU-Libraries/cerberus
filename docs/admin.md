# Administration

How an `/admin/*` surface is gated and breadcrumbed, and how the admin ledger
records what happened.

Source files:

- `app/controllers/admin/base_controller.rb`
- `app/models/admin_notice.rb`
- `app/controllers/admin/tombstones_controller.rb`
- `app/controllers/admin/files_controller.rb`
- `app/controllers/admin/reindex_controller.rb`
- `app/controllers/admin/ledger_controller.rb`
- `app/controllers/admin/linked_members_controller.rb`
- `app/controllers/histories_controller.rb`
- `app/helpers/admin_finder_helper.rb`
- `app/helpers/admin/digest_helper.rb`

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

## Which gate each surface uses

Each surface picks one of three gates. Check this table before you move an
action between controllers.

| Surface | Gate | Why |
|---|---|---|
| Tombstone list and restore | `:admin` or the devolved-admin tier | Atlas grants `:restore` to both, in `apply_admin_delegate_abilities` |
| Permanent delete | `:admin` only | Atlas omits `:destroy` from the delegate abilities |
| Replace a file, roll back a version | `:admin` or the devolved-admin tier | Atlas already grants Blob `:update`, `:rollback` and `:read_versions` to that pair |
| Reindex a Work or a Set | `:admin` or the devolved-admin tier | Atlas applies no per-user check on this path at all |
| The ledger | `:admin` or the devolved-admin tier | the same audience as deposit triage |
| Linked members | `:admin` only | it edits placement, which the delegate tier does not manage |
| Rights and MODS history | `:read, :audit_event` | the same gate as the Audit History tab it is reached from |

`HistoriesController` is the odd one out. It sits outside `Admin::`, inherits
`ApplicationController`, and asks CanCan directly rather than using
`require_admin`. The role predicates behind all of these live in
[`docs/identity.md`](identity.md).

## Restoring and permanently deleting a tombstoned item

`Admin::TombstonesController` is the registry: the admin-only counterpart to the
tombstone ("Delete") action on the show pages. It lists every tombstoned Work,
Collection and Community, and offers the two ways out. Reverse the withdrawal,
or finish it.

The two gates mirror Atlas's `Ability` exactly. Restore is an operator-level
lifecycle action, so Atlas files it with `:reparent` rather than with edit
rights, and withholds it from group-ACL editors and depositors.

atlas_rb ships the backend wiring for both verbs under its operator-only `Admin`
namespace, so this controller is purely the Cerberus consumer. The acting user's
NUID reaches Atlas ambiently, because `config/initializers/atlas_rb.rb` wires
`Current.nuid`. That NUID both passes Atlas's check and stamps the audit event.

Restore is reversible — re-tombstone the item — so it needs no confirmation
marker. A purge is not, and atlas_rb makes that explicit by demanding
`confirm: :i_understand`.

`RESOURCE_ADMINS` maps a resource class to the atlas_rb `Admin` class that
restores and purges it. It doubles as the allow-list for the `type` param.

The index borrows `CatalogController`'s Solr configuration with
`copy_blacklight_config_from`, so the `TombstonedItems` SearchBuilder behaves
like the catalog's. `ReparentController` does the same.

### Reading a refusal on these two verbs

Restore and destroy are not among atlas_rb's typed-error paths — those are
re-parent, linked members, Compilation and upload. A non-2xx therefore arrives
as a plain `Faraday::Response` and never raises, which is why both actions test
`success?` themselves. A value that does not respond to `success?` counts as a
success. A transport-level failure, such as the host being down, still raises
`Faraday::Error`, and both actions log it and flash the generic alert.

One refusal earns its own message: a container that still has members.
`PURGE_HAS_CHILDREN` says that tombstoned members count, because Atlas counts
them here. The tombstone refusal counts only live members. The two differ
because a purge cannot be undone, so a member left behind is orphaned for good.
The message spells this out, since "empty it first" reads as already done to an
admin looking at a container whose children are all withdrawn.

Everything else — a 404, a 403, a transport fault — is the generic alert,
because it is the one failure the admin cannot act on.

## Replacing a file

`Admin::FilesController` replaces the bytes of a Work's Blob. The operation is
non-destructive: `Blob.update` appends a new OCFL version and preserves the Blob
NOID, so prior versions stay retrievable.

| Action | What it does |
|---|---|
| `index` | search for the Work |
| `manage` | list its replaceable Blobs, each with version history and a replace form |
| `replace` | stage the upload, queue `FileReplacementJob`, return to `manage` |
| `rollback` | reinstate a prior version with `Blob.rollback`, then refresh derivatives |

The finder-then-manage shape mirrors `Admin::LinkedMembersController`.

`rollback` is non-destructive in the same way: it re-appends the chosen
version's bytes, then `FileDerivativeRefreshJob` rebuilds derivatives from the
reinstated bytes.

`manage` lists content Blobs only. A Delegate carries a `uri`, is derived rather
than replaced, and is filtered out.

Version history comes back in one `find_many_versions` call rather than a
versions-per-noid fan-out, because this page reads every held binary on the
Work — one per page on a multipage Work. A dropped id renders as a file with no
version table, which is what a failed history read already did.

Streaming a superseded version's content is `FileVersionsController`, which is
`ActionController::Live`. Keeping it separate means the finder and mutation
actions here are not forced into stream semantics.

The acting user's NUID flows ambiently through `Current.nuid` and propagates
into the enqueued jobs.

## Reindexing a Work or a Set

`Admin::ReindexController` re-projects a resource into Solr on demand. A reindex
re-derives the Solr document from Atlas's authoritative store. It is Solr-only —
no lifecycle transition, no audit event, no minting — and it is idempotent, so a
double-click costs time and nothing else.

The buttons sit on the Work and Set show pages, because that is where someone
notices a record has gone stale. The actions are mounted here so the role gate
stays in one place. That placement is load-bearing rather than tidy:
`AtlasRb::System.reindex` runs on the Atlas system token with the principal
pinned to the system NUID.

| Action | Shape | Why |
|---|---|---|
| `work` | one call, answered inline | it is a single resource |
| `set` | enqueues `SetReindexJob` | a Set names collections whose subtrees can run to thousands of resources |

`set` reads the Compilation before it enqueues, so an unknown or unreadable id
fails in front of the person who clicked rather than inside a job nobody is
watching. The result of the job reaches the user through their inbox.

A private Set the caller may not read raises `AtlasRb::ForbiddenError`, and the
`rescue_from` renders the standard forbidden page. That mirrors
`SetsController`, which is the surface the Set button is reached from.

## Reading the ledger

`Admin::LedgerController` renders the two things staff read together, over the
one `AdminNotice` table described above.

**Requests** is what depositors have asked staff to do but cannot do themselves.
It replaces a group-addressed inbox message, which could never show the queue at
all, because a message is dismissed per person.

**Activity** is what the repository did — loads, cascades, reindexes, showcase
promotions — plus the daily digest. Staff read the showcase rows after the fact,
to catch a work promoted onto a showcase it does not belong on, or filed under
the wrong genre.

Neither list is worked here. The tabs are a filter on `kind` and nothing more.
They are two tabs rather than two cards, because it is one sitting by one
person, and they are plain links so each list keeps its own paging with no
JavaScript.

| Parameter | Effect |
|---|---|
| `tab` | `requests`, `activity` or `digests`; anything else falls back to `requests` |
| `kind` | one `AdminNotice` kind within the tab |
| `on` | narrows the tab to one day, as `YYYY-MM-DD` |
| `page` | 50 rows a page, or one digest a page |

`on` exists so a digest's figures can link to what they counted. "1 made" on a
given day means the request made that day, not every request ever made. An
unparseable date is ignored rather than raising, because the value comes from a
query string, and a filtered page that quietly shows everything beats an error
page.

Digests page one at a time and sort by `by_day`. A digest is a page-sized report
of one whole day, so it gets a page, and paging back through them reads the way
the mailed summaries will arrive. Everything else is an event and sorts
`newest_first`.

## The daily digest's count block

`Admin::DigestHelper` assembles the digest's figures. Every figure that has
something behind it links to the surface listing what it counted, so the block
is a way into the day rather than a readout. A zero carries no link, because
there is nothing there to open.

It is split from `LedgerHelper` because the two speak different vocabularies.
`LedgerHelper` formats a row; this one assembles a summary. A view that builds
ten route helpers inline also stops being a template.

`digest_figures` returns the block in reading order, as `{ label => [figure,
…] }`. Every figure counted one day, so every link carries that day.

The deposit figures are the exception and carry no day. They are a live backlog,
not a figure for the day being summed up, so they point at the deposit triage
list that works them.

`repository_figures` holds the only two labels that are countable nouns, so they
are the only two that need agreeing with their figure. "1 reindexes" reads as a
bug.

## Linked collection placements

`Admin::LinkedMembersController` manages a Work's *linked* collection
placements: the leaves-only DAG overlay, `a_linked_member_of`. A linked
placement surfaces a Work in additional Collections without moving it and
without changing its permissions. The Work's structural home, `a_member_of`, is
never touched here.

| Action | What it does |
|---|---|
| `index` | search for the Work to manage |
| `manage` | list its linked collections, with add-by-search and remove affordances |
| `add` | POST a linked membership, then return to `manage` |
| `remove` | DELETE a linked membership, then return to `manage` |

Removing is distinct from withdrawing the Work. It drops a discovery placement
only; the Work and its home are untouched.

`add` and `remove` both redirect to `manage`, which re-reads the live linked
list from Atlas. That is the design's answer to atlas_rb swallowing a rejected
4xx on these two calls, so the panel always reflects Atlas truth. The `add`
flash says as much, and names the two common rejections: the Work is already a
structural member, or the target is not a Collection. The gap is filed against
atlas_rb's re-parent and linked-member error handling.

`manage` also computes `@placed_noids`, the home plus the linked collections,
because a Collection the Work already sits in cannot be added again.

Linked collection NOIDs resolve to `{noid, title}` rows through one batched
`find_many`. It is unordered and may drop an id it cannot resolve, so the result
is indexed by NOID, the given order is preserved, and a missing title falls back
to the bare NOID.

The acting admin's NUID flows ambiently through `Current.nuid`.

## The finder helpers

`AdminFinderHelper` holds the view helpers the admin finder and registry
surfaces share, including re-parent, linked members and deposit triage.

`RESOURCE_ICONS` carries the DRS semantic iconography that the breadcrumbs and
show pages already use: a Collection is an open folder, a Community is users, a
Work is a file. `finder_type_chip` renders one as a small, restrained chip of
icon plus label.

Two helpers read a title off a resource Solr document, and both fall back to
`(untitled)` so an untitled resource stays selectable. `title_tsim` is
multivalued, and both take the first value.

| Helper | Output | Use it for |
|---|---|---|
| `finder_doc_title` | plain text | a confirm dialog, a query string, a cell built by interpolation |
| `finder_doc_heading` | enhanced text | an admin table cell or a link label, where a formula's subscript should read as one |

`deposit_last_change` renders when a resource was last written, for the deposit
triage list. The column is called "last change" and not "waiting since", which
is what a triage reader actually wants to know but not what the field says.
`updated_at_dtsi` is the most recent write of any kind, so a derivative job
touching an abandoned deposit moves it. Naming the column for the field keeps it
honest, and it still sorts the list usefully: the deposit nothing has touched in
a month sinks to the top.

## The rights and MODS history pages

`HistoriesController` renders the deep diffs reached from the Audit History
tab's per-row "View" button. They are the v2 successor to DRS v1's per-object
"Rights History" and "MODS History" pages, and they are read-only.

Every data call hits Atlas's `/resources/:id/*` endpoints, so one controller
serves Work, Collection and Community without branching on type.
`load_resource!` fetches the resource for the page heading and the back-link to
its audit log.

### The rights page

`#rights` is a paginated access-control ledger. Each entry expands one audit
event's before-and-after ACL snapshot into a two-column diff.

It shows one event a page. The page is reached by a per-row deep link, so it
shows that single event's diff, and the previous and next walker steps to
adjacent changes without stacking them.

The events it shows are the initial grant at creation and every later ACL
change — `AuditEventsHelper::PERMISSION_VIEW_ACTIONS`, filtered to
`change_type == 'permissions'`. Atlas suppresses no-op permission writes, so
each one is a real transition.

An explicit `?page` wins. Otherwise, when the reader arrives by a "View" deep
link carrying `?at=<occurred_at>`, the controller lands on whichever page holds
that event, so its anchor resolves. It defaults to the first page.

### The MODS page

`#mods` diffs two MODS versions through `MODSDiff`.

| Parameter | Resolves to |
|---|---|
| `?to` | the "after" side; else the version a `?at` deep link points at; else the newest |
| `?from` | the "before" side; else the version immediately preceding `to` |

`version_ids` is newest-first, as Atlas returns them, which is why the "before"
side is the *next* entry in the list. When `to` is the earliest version,
`resolve_from` returns `nil` and the page renders no diff, because there is
nothing earlier to compare.

Matching `?at` to a version is best-effort. The correlation is by timestamp
against the version's `created`, so a miss falls back to the newest version.
