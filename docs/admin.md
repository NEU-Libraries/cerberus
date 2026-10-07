# Administration

How an `/admin/*` surface is gated and breadcrumbed, and how the admin ledger
records what happened.

Source files:

- `app/controllers/admin/base_controller.rb`
- `app/models/admin_notice.rb`
- `app/lib/tombstone_reasons.rb`
- `app/controllers/admin/tombstones_controller.rb`
- `app/helpers/admin/tombstones_helper.rb`
- `app/services/tombstoned_items.rb`
- `app/services/tombstone_registry_action.rb`
- `app/jobs/tombstone_bulk_job.rb`
- `app/javascript/controllers/bulk_select_controller.js`
- `app/models/tombstoned_search_builder.rb`
- `app/services/structural_parents.rb`
- `app/controllers/admin/files_controller.rb`
- `app/controllers/admin/file_versions_controller.rb`
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
keeps the role gate consistent and fail-closed: only `:admin` passes. Both
gates sit behind `authenticate_user!`.

`require_admin` and `require_admin_or_delegate` both render
`errors/forbidden` with a 403 and the application layout, so a refusal is a
friendly page rather than a raised exception.

The devolved-admin surfaces opt into the broader gate per controller:

```ruby
skip_before_action :require_admin
before_action :require_admin_or_delegate
```

A controller that splits its actions between the two gates adds `except:` to
both lines. `Admin::TombstonesController` keeps `destroy` admin-only this way,
and `Admin::ImpersonationsController` keeps `create_acting_as` admin-only.

The override lives in each subclass, never in the base class. The default stays
strict, so a new `/admin/*` controller is admin-only unless it deliberately opts
out.

## Breadcrumbs

`Admin::BaseController` owns the shared trail, `Administration / <section>`.

| Level | Who declares it |
|---|---|
| `Administration` root | `BaseController`, prepended to every trail |
| The section | the subclass, via `breadcrumb_for <label>, <index path helper>` — for example `breadcrumb_for 'Replace a file', :admin_files_path` |
| The leaf (`new`, `edit`, `manage`, …) | the action itself |

The dashboard is the hub. It declares no section, and `build_admin_breadcrumbs`
skips it, so it shows no breadcrumb.

Each admin view renders the trail itself with `= render 'admin/breadcrumb_header'`.
This follows the per-view `:container_header` pattern rather than a custom admin
layout, which would double-render the view through Blacklight's layout.

Both `breadcrumb` calls pass `match: :exact`. Loaf's default inclusive match
treats `/admin` as current on every `/admin/*` path. That would mark
"Administration" as the current crumb — a dead end instead of a link back to the
hub. It would do the same to a section on its own sub-pages.

## The admin ledger

`AdminNotice` is a write-once record that something happened, and it is the whole
of the ledger. Nothing is worked inside Cerberus: staff read a list, act on the
object's own surface, and coordinate with each other and with depositors off-site.
So there is no lifecycle on these rows and no update path.

### Why one table

Requests and activity share it because nothing structural separates them. Take
a request ("somebody asked for this work to be withdrawn") and an event ("a
cascade finished"). Both are an attributed fact with a subject and some detail.
They differ only in which question a reader is asking. That is exactly what the
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

`payload` holds kind-specific detail rather than prose, because two renderers
read it. The ledger builds paths from the NOIDs it carries, and a mailer would
build absolute URLs from the same fields. A rendered link could serve neither,
since it fixes the host — or omits it — at write time.

`detail(key)` is the only reader. `jsonb` round-trips to string keys, so a caller
that wrote `payload: { genre: … }` reads it back as `"genre"`. Going through
one method means no caller has to know which side of the write it is on.

### Validation

`kind` must be one of `KINDS`, and `subject` and `occurred_on` must be present.

A request also needs `actor_nuid` (the requester) and `subject_noid`. These are
validated per kind, with `if: :request?`, rather than declared `NOT NULL`. The
shared table also holds activity rows, which have no requester and often no
subject. A request with nobody asking, or nothing asked
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
moment they were written. A re-run, or a backfill of several days at once, must
not shuffle them out of calendar order.

`of_kind` falls through to everything rather than to nothing, so a hand-typed
query string cannot render an empty page with no explanation.

`default_occurred_on` stamps the app-zone date before validation. Bucketing by a
date column, rather than a `created_at` range, keeps a job that runs late
attributed to the day it is about. The same is true of a re-run.

## Which gate each surface uses

Each surface picks one of three gates. Check this table before you move an
action between controllers.

| Surface | Gate | Why |
|---|---|---|
| Tombstone list, restore and bulk restore | `:admin` or the devolved-admin tier | Atlas grants `:restore` to both, in `apply_admin_delegate_abilities` |
| Permanent delete and bulk delete | `:admin` only | Atlas omits `:destroy` from the delegate abilities, so a wider gate here only buys a 403 from Atlas |
| Replace a file, roll back a version | `:admin` or the devolved-admin tier | Atlas grants Blob `:update` to every standard user, and its rollback checks `:update`. It grants `:read_versions` to the delegate tier |
| Reindex a Work or a Set | `:admin` or the devolved-admin tier | Atlas applies no per-user check on this path at all |
| The ledger | `:admin` or the devolved-admin tier | the same audience as deposit triage |
| Linked members | `:admin` only | it edits placement, which the delegate tier does not manage |
| Associated works | `:admin` or the devolved-admin tier | Atlas grants `:associate` to both. A delegate's reads stay group-gated, so a Work they cannot read gets the forbidden page, and an edge to one shows its bare NOID |
| Communities registry | `:admin` or the devolved-admin tier | it only lists and links, through the gated search, so a delegate sees what they may discover. Its People link is `:admin` only, as the page it opens is |
| A community's people (`Admin::CommunityPeopleController`) | `:admin` only | Atlas grants Person `:update` to admins and the system principal alone. It is a hub page rather than a tab on the community's Edit page, because people who may edit a community's details must not be offered its people |
| Rights and MODS history | `:read, :audit_event` | the same gate as the Audit History tab it is reached from. Only `:admin` holds it, through `can :manage, :all` |

`HistoriesController` is the odd one out. It sits outside `Admin::`, inherits
`ApplicationController`, and asks CanCan directly rather than using
`require_admin`. The role predicates behind all of these live in
[`docs/identity.md`](identity.md).

## The removal reason

The library's withdrawal policy requires a note on every withdrawn item, and it
fixes the wording: five notes, held in `TombstoneReasons::ALL`. Atlas keeps the
same list and answers `422 invalid_reason` for any other value. So a change to
the wording needs an Atlas release as well.

The note is chosen in the Delete dialog on the show pages
(`shared/_tombstone_modal`):

- **An admin or a delegated admin** chooses from all five. The choice is
  required.
- **Anyone else** who may delete the item, such as its depositor or proxy
  uploader, records the curator's note (`TombstoneReasons::CURATOR`). The form
  sends it as a hidden field, but `Tombstoning#removal_reason` replaces any
  other value with it. A crafted request therefore cannot record "legal order".
- **A cancelled deposit** records no note. The deposit's Cancel, My DRS and the
  triage "Cancel deposit" use the same tombstone route but send no `reason`,
  because a Work that was never published has not been withdrawn from view.

Atlas returns the note as `tombstone_reason` and clears it on restore. The gone
page joins it to the date from `tombstoned_at`: *"Sample Report" was removed
from view at Northeastern University Library's discretion on September 30,
2026.* An item withdrawn with no note says only that it has been removed. The
tombstone row on the History tab shows the note too, because Atlas records it on
the audit event.

## Deleting a container that is not empty

Atlas refuses to tombstone a Collection or Community that still holds a live
member, so a plain Delete appears only on an empty one. For a container that
holds items, `CascadeTombstoning` offers a delete that withdraws it and
everything live beneath it.

| Who | May delete a non-empty |
|---|---|
| `:admin` | Collection or Community |
| The devolved-admin tier | Collection only. A community holds other people's collections and showcases |
| Anyone else with tombstone rights | Neither, so they keep the empty-only Delete |

The confirmation (`shared/_tombstone_modal` with `cascade:`) counts what it will
withdraw by type, through `TombstoneTargets#counts`. It asks for the removal
reason, says there is no one-step restore, and keeps its button disabled until
the title is typed (`confirm-title` Stimulus controller). Formatting and spacing
do not count, because a title can carry sub- and superscript markup. The server
repeats every check: role, title, reason, and a size limit
(`TombstoneTargets::LIMIT`, the narrowing cascade's). Above the limit there is
no form, only a pointer to the development team.

`TombstoneCascadeJob` does the work. `TombstoneTargets` walks the subtree
deepest first, as the narrowing walk does, widened to communities and limited to
what is not already withdrawn, and the job tombstones each with the one reason.
Linked members are not part of the structural subtree, so they stay untouched. A
lock conflict is retried in place, not through `retry_on`, because a re-run
would rebuild the walk without what it had already withdrawn. A container
refuses while a member beneath it failed, so a failure leaves the path above it
live, not half-withdrawn.

### The top-level communities cannot be deleted

The repository root and the People Community have no parent, and the whole
tree hangs from them. Atlas refuses to withdraw, purge or move either one
(`top_level_community`), on the API only: a developer at the console still can.
`CommunitiesController` offers no Delete on either, and refuses the tombstone
request before anything else. That order matters for the cascade, because
`TombstoneCascadeJob` withdraws the container last. If the request reached the
job, Atlas would refuse the root only after everything beneath it was gone. The
Move tool refuses the root the same way (`Admin::ReparentController::ROOT_REFUSED`).

### There is no cascading restore

On purpose. A restore that put everything back would have to tell this delete's
tombstones from items withdrawn earlier, for policy, and must not resurrect
those. Restoring is rare and consequential enough to want the development team.
So the job records one `tombstone_cascade` ledger entry, through
`CompletionNotice`, whose payload lists every NOID it withdrew, with its type,
and anything it could not. A developer restores from that list, parents first,
because Atlas refuses to restore a child under a tombstoned parent. The
registry's bulk restore can do the same from the page: search for the
container's PID, select everything, and restore. See "Bulk restore and bulk
delete" below.

The Requests & activity row shows only the summary. The list is in the
`AdminNotice` payload, under `withdrawn`, as `{ "noid", "type" }` pairs, with
`failures`, `reason`, `subject_type` and `subject_title` beside it.

#### Restoring a cascade at the console

The job withdraws deepest first and appends each item as it goes, so the list
runs leaf to container. Restoring it in reverse puts each parent back before its
children, which is the order Atlas requires. Run it as an admin, so Atlas
records who restored each item:

```ruby
notice = AdminNotice.where(kind: 'tombstone_cascade', subject_noid: '<container noid>').last
notice.detail(:withdrawn).reverse_each do |item|
  response = AtlasRb::Admin::Resource.restore(item['noid'], nuid: '<admin nuid>')
  puts "#{item['type']} #{item['noid']}: #{response.status}"
end
```

Restore only what the list names. An item withdrawn before the cascade is
absent from it on purpose, and its own tombstone still stands. A container that
had live members the job could not withdraw is on `failures`, not `withdrawn`,
and was never tombstoned. Each restore clears that item's removal reason and
records a restore on its History tab.

## Restoring and permanently deleting a tombstoned item

`Admin::TombstonesController` is the registry: the staff counterpart to the
tombstone ("Delete") action on the show pages. It lists every tombstoned Work,
Collection and Community, and offers the two ways out. Restore reverses the
withdrawal; permanent delete finishes it. Only a full admin sees the delete
button.

The two gates mirror Atlas's `Ability` exactly. Restore is an operator verb, so
Atlas grants it alongside `:reparent` in `apply_admin_delegate_abilities`, not
through edit rights. Atlas keeps it out of `UPDATE_ALIASES`, so group-ACL
editors and depositors never hold it.

atlas_rb ships the backend wiring for both verbs under its operator-only `Admin`
namespace, so this controller is purely the Cerberus consumer. The acting user's
NUID reaches Atlas ambiently, because `config/initializers/atlas_rb.rb` wires
`Current.nuid`. That NUID both passes Atlas's check and stamps the audit event.

Restore is reversible — re-tombstone the item — so it needs no confirmation
marker. A purge is not, and atlas_rb makes that explicit by demanding
`confirm: :i_understand`.

Atlas restores and purges every type through one generic endpoint, which
atlas_rb binds as `AtlasRb::Admin::Resource.restore` and `.destroy`. So the
controller needs no per-type class. `RESTORABLE_TYPES` is only the allow-list
for the `type` param: Work, Collection and Community. It still has to refuse a
FileSet or a Blob, which the generic endpoint would otherwise accept.

The index borrows `CatalogController`'s Solr configuration with
`copy_blacklight_config_from`. The `TombstonedItems` service searches through
`TombstonedSearchBuilder`, which behaves like the catalog's builder except that
it inverts the tombstone filter. It cannot simply add `tombstoned_bsi:true`,
because the inherited `-tombstoned_bsi:true` clause would contradict it and
return nothing. So its last processor step drops that clause and adds the
inclusion. The Move tool (`Admin::ReparentController`) borrows the configuration
the same way.

`TombstonedItems` pages 50 rows at a time by default; `per_page` picks 10, 20,
50 or 100, and any other value falls back to 50. With no search it sorts by
`tombstoned_at_dtsi` descending, the withdrawal time, so the item just withdrawn
in error comes first. A record tombstoned before Atlas stored that field has no
value until it is reindexed, and sorts last.
The `q` param searches titles and PIDs, and ranks by relevance instead. v1 holds
more than 8,000 tombstoned items, so a migrated registry needs the search.

### A search lists a container's descendants

Purging a container means purging everything it holds first, tombstoned members
included. So when a search matches a Collection or Community, the listing adds
every tombstoned item beneath it. The admin can start from the container's PID
and see the whole subtree on one page.

Only Collections and Communities carry `ancestor_ids_ssim`, tombstoned or not.
Works never do, because a re-parent would then have to reindex every Work beneath
the moved container. So `TombstonedItems` finds the descendants in two raw index
reads, the same two Atlas's `DescendantWorksQuery` uses:

1. `{!terms f=ancestor_ids_ssim}` over the matched containers' NOIDs returns
   every container beneath them, at any depth. The values are bare NOIDs.
2. `{!terms f=a_member_of_ssi}` over the matched containers and those nested
   ones returns their members, Works included. The values are `id-<uuid>`.

Linked membership is a separate field, so a Work linked into the container is not
swept in. Atlas refuses to create anything under a tombstoned container, so
everything beneath one is itself tombstoned and the listing is complete. The
search's own matches are capped at `MATCH_LIMIT`, so a broad query cannot fan out
without bound.

When the reads find descendants, the listing becomes an identity filter
(`MembershipQuery.identity_fq`) over the matches and their descendants, sorted
by withdrawal time like the unfiltered list. When it finds none, the search runs
as a plain relevance-ranked query.

### The withdrawal date filter

`from` and `to` narrow the list by withdrawal date, both inclusive, as a range
on `tombstoned_at_dtsi` in whole UTC days. The upper bound is the start of the
day after `to`, exclusive. A date the controller cannot parse is ignored rather
than refused. Atlas also indexes the date as the string `tombstoned_at_ssi`;
filter on the date field, which compares as a date.

### Bulk restore and bulk delete

Each row has a checkbox, and the header has a select-all for the visible page.
Checking any row reveals a well with Bulk restore and, for a full admin, Bulk
delete. The checkboxes sit outside the well's form, because each row already
holds its own Restore and Delete forms and forms cannot nest. They join the bulk
form through the HTML `form` attribute.

`POST /admin/tombstones/bulk` queues `TombstoneBulkJob` and returns at once. The
gates are the single-item ones: restore is open to the delegate tier, delete is
:admin only. The action takes at most one page at the largest page size.

Atlas refuses to restore a child under a tombstoned parent, and refuses to purge
a container that still holds members. So the job orders the selection by depth
within the selection, following each item's `a_member_of_ssi`. Restores run
shallowest first, and deletes deepest first. An item that is no longer
tombstoned when the job runs is skipped and listed as such.

Both the single-item actions and the job call Atlas through
`TombstoneRegistryAction`, which retries a 409 lock conflict and turns each
response into `:ok` or `:failed`, or the refusal the admin can act on:
`:tombstoned_parent` for a restore, `:has_children` for a purge. The job records one
`tombstone_bulk` ledger entry, through `CompletionNotice`, with `done`,
`failures` and `skipped` in its payload, and the admin gets the same summary in
their inbox.

### The Parent column

Each row names its structural parent, the Collection or Community it sits in.
`StructuralParents` reads them in one Solr query per page, from each document's
`a_member_of_ssi` (`MembershipQuery::STRUCTURAL_FIELD`). A Work carries no
ancestor chain, but its direct parent is all the column needs. The query must
return `alternate_ids_tesim`, because `SolrDocument#to_param` reads the NOID from
it. Without it every parent link falls back to the uuid and 404s.

The query uses the raw index, `Blacklight.default_index`, rather than a
SearchBuilder. The catalog's default filter drops tombstoned documents, and a
tombstoned parent is the one an admin most needs to see, because it has to be
restored before its child can be. Such a parent is named and marked "tombstoned" but not linked, since its page is the
gone page (`Admin::TombstonesHelper#tombstone_parent_cell`). A top-level
Community has no parent and shows a dash. A failed read leaves every cell a
dash rather than failing the registry.

### Reading a refusal on these two verbs

Restore and destroy are outside atlas_rb's typed-error middleware,
`RaiseOnResourceError`, which fires only on a narrow set of write paths
(re-parent, linked members, associations, Compilations, and a few others). Both
bindings return the raw `Faraday::Response`, so a non-2xx never raises. That is
why `TombstoneRegistryAction` tests `success?` itself: drop the check and a refused
restore reports as done. A value that does not respond to `success?` counts as a
success. A transport-level failure, such as the host being down, still raises
`Faraday::Error`. `TombstoneRegistryAction` logs it and reports `:failed`.

A restore refused because the item's parent is still tombstoned earns its own
message. Atlas answers with a 422 whose `code` is `tombstoned_parent`, so the
row flashes `RESTORE_PARENT_TOMBSTONED`, and the bulk job's ledger entry tells
the admin to restore the parent first. Any other failed restore flashes the
generic `RESTORE_FAILED`.

A failed purge earns its own message in one case: a container that still has
members. Atlas answers with a 422 whose body carries the machine token
`has_children` on `code` and the human message on `error`. That is the reverse
of the re-parent and linked-member envelopes, so `TombstoneRegistryAction`
reads `code`.
`PURGE_HAS_CHILDREN` says that tombstoned members count, because Atlas counts
them here. The tombstone refusal counts only live members. The two differ
because a purge cannot be undone, so a member left behind is orphaned for good.
The message spells this out, since "empty it first" reads as already done to an
admin looking at a container whose children are all withdrawn. The purge
confirmation carries the same caveat for a Collection or Community
(`tombstone_purge_confirm`).

That is the one purge failure the admin can act on. Everything else — a 404, a
403, a transport fault — gets the generic `PURGE_FAILED`.

## Replacing a file

`Admin::FilesController` replaces the bytes of a Work's Blob. The operation is
non-destructive: `Blob.update` appends a new OCFL version and preserves the Blob
NOID, so prior versions stay retrievable.

| Action | What it does |
|---|---|
| `index` | search for the Work |
| `manage` | list its replaceable Blobs, each with version history and a replace form |
| `replace` | refuse a file of a different type, else stage the upload, queue `FileReplacementJob`, and return to `manage` |
| `rollback` | reinstate a prior version with `Blob.rollback`, then refresh derivatives |

The finder-then-manage shape mirrors `Admin::LinkedMembersController`.

`rollback` is non-destructive in the same way: it re-appends the chosen
version's bytes, then `FileDerivativeRefreshJob` rebuilds derivatives from the
reinstated bytes.

`manage` lists content Blobs only. A Delegate carries a `uri`, is derived rather
than replaced, and is filtered out.

`replace` refuses a replacement whose MIME type differs from the current Blob's.
Atlas can rename a Blob and re-derive its type on replace, but the old type's
derivatives would stay behind: a Word file's PDF rendition, or an image's size
tiers. No job can remove them, because Atlas has no system-principal Blob
delete. Both sides are sniffed as ingest sniffs them, so `.jpg` against `.jpeg`
is not a mismatch, and an unknown type on either side is allowed. To change a
file's type, a curator adds it to the Work as a new file.

`FileReplacementJob` passes the upload's filename to `Blob.update`, so each
revision records the name it was uploaded under. The version table shows that
name per row, from the `original_filename` on each version descriptor. A
rollback restores the revision's own name, so it passes none.

Version history comes back in one `find_many_versions` call rather than a
versions-per-noid fan-out. That is because this page reads every held binary on
the Work — one per page on a multipage Work. The result is unordered and may
drop an id, so `version_history` indexes it by `blob_id`. A dropped id renders as
a file with no version table.

`Admin::FileVersionsController` streams a superseded version's content through
`ActionController::Live`. Keeping it separate means the finder and mutation
actions here are not forced into stream semantics. It shares the same gate.

It checks the version id against the Blob's own history before any bytes move.
The streaming binding cannot raise on Atlas's 404 for an unknown version,
because chunks reach the client before the status is known. Without the check,
the error body would arrive as the file's contents, under a 200 and the download
filename.

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
| `work` | one call, answered inline | it is a single resource, and Atlas's subtree walk stops at Works anyway |
| `set` | enqueues `SetReindexJob` | a Set names collections whose subtrees can run to thousands of resources |

`work` flashes success on a 204, "no resource found" on a 404, and a failure
otherwise, then returns to the Work's show page.

`set` reads the Compilation before it enqueues. So an unknown or unreadable id
fails in front of the person who clicked, rather than inside a job nobody is
watching. The result of the job reaches the user through their inbox.

A private Set the caller may not read raises `AtlasRb::ForbiddenError`, and the
`rescue_from` renders the standard forbidden page. That mirrors
`SetsController`, which is the surface the Set button is reached from.

## Reading the ledger

`Admin::LedgerController` renders three tabs over the one `AdminNotice` table
described above, one per family.

**Requests** is what depositors have asked staff to do but cannot do themselves.
It is a ledger rather than a group-addressed inbox message, because a message is
dismissed per person and so cannot show the queue.

**Activity** is what the repository did: loads, cascades, reindexes, showcase
promotions and Set sweeps. Staff read the showcase rows after the fact. They are
looking for a work promoted onto a showcase it does not belong on, or filed
under the wrong genre.

**Digests** is the daily digest, one day to a page.

No list is worked here. The tabs are a filter on `kind` and nothing more. They
are tabs rather than separate cards, because staff read them in one sitting.
They are plain links, so each list keeps its own paging with no JavaScript.

`index` resolves every actor NUID on the page in one `NuidResolver.names_for`
call. The per-row actor helper reads from `Rails.cache`, so priming it here is
the difference between one batch and one request per distinct NUID.

| Parameter | Effect |
|---|---|
| `tab` | `requests`, `activity` or `digests`; anything else falls back to `requests` |
| `kind` | one `AdminNotice` kind within the tab; an unknown kind shows the whole tab |
| `on` | narrows the tab to one day, as `YYYY-MM-DD` |
| `page` | 50 rows a page, or one digest a page |

`on` exists so a digest's figures can link to what they counted. On a given day,
"1 made" means the request made that day, not every request ever made.
`requested_day` parses it with `Date.iso8601` and ignores an unparseable date
rather than raising, because the value comes from a query string. A filtered
page that quietly shows everything beats an error page.

Digests page one at a time (`DIGESTS_PER_PAGE`) and sort by `by_day`. A digest
is a page-sized report of one whole day, so it gets a page. Paging back through
them reads the way the mailed summaries will arrive. Every other row is an event
and sorts `newest_first`.

## The daily digest's count block

`Admin::DigestHelper` assembles the digest's figures. Every figure that has
something behind it links to the surface listing what it counted. So the block
is a way into the day rather than a readout. A zero carries no link, because
there is nothing there to open.

It is split from `Admin::LedgerHelper` because the two speak different
vocabularies. `LedgerHelper` formats a row; this one assembles a summary. A view
that builds that many route helpers inline also stops being a template.

`digest_figures` returns the block in reading order, as `{ label => [figure,
…] }`: Requests, Loads, Deposits, Repository, Showcases. `digest_figure` returns
each figure as its text and a path, or `nil` for a zero. Every figure counted
one day, so every link carries that day.

The deposit figures are the exception and carry no day. They are a live backlog,
not a figure for the day being summed up, so they point at the deposit triage
list that works them.

`repository_figures` holds the only two labels that are countable nouns. They
are the only two that need agreeing with their figure: "1 reindexes" reads as a
bug. "reindex" is spelled out rather than passed to `pluralize`, because the
inflector reads it as a Latin -ex and returns "reindices".

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
list from Atlas. So the panel shows what Atlas holds, not what the call claimed.
The `add` flash hedges for the same reason, and names the two common
rejections: the Work is already a structural member, or the target is not a
Collection.

atlas_rb raises `AtlasRb::LinkedMemberError` when Atlas rejects either call with
a 422, and `AtlasRb::ForbiddenError` on a 403. This controller rescues neither.
`Authorizable` turns the 403 into the forbidden page, but a 422 is unhandled.

`manage` also computes `@placed_noids`, the home plus the linked collections,
because a Collection the Work already sits in cannot be added again.

Linked collection NOIDs resolve to `{noid, title}` rows through one batched
`find_many`. It is unordered and may drop an id it cannot resolve. So the result
is indexed by NOID, the given order is preserved, and a missing title falls back
to the bare NOID.

The acting admin's NUID flows ambiently through `Current.nuid`.

## The finder helpers

`AdminFinderHelper` holds the view helpers the admin finder and registry
surfaces share: the Move tool, linked members, deposit triage and the tombstone
registry, among others.

`RESOURCE_ICONS` carries the DRS semantic iconography that the breadcrumbs and
show pages already use. A Collection is `fa-folder-open`, a Community is
`fa-users`, a Work is `fa-file-lines`. `finder_type_chip` renders one as a small,
restrained chip of icon plus label, and falls back to `fa-cube` for any other
type.

Two helpers read a title off a resource Solr document, and both fall back to
`(untitled)` so an untitled resource stays selectable. `title_tsim` is
multivalued, and both take the first value.

| Helper | Output | Use it for |
|---|---|---|
| `finder_doc_title` | plain text | a confirm dialog, a query string, a cell built by interpolation |
| `finder_doc_heading` | enhanced text | an admin table cell or a link label, where a formula's subscript should read as one |

`deposit_last_change` renders when a resource was last written, for the deposit
triage list. The column is called "last change" and not "waiting since". That
second phrase is what a triage reader actually wants to know, but not what the
field says. `updated_at_dtsi` is the most recent write of any kind, so a
derivative job touching an abandoned deposit moves it. Naming the column for
the field keeps it honest, and it still sorts the list usefully. The deposit
nothing has touched in a month sinks to the top. A document with no stamp shows
a dash.

## The rights and MODS history pages

`HistoriesController` renders the deep diffs reached from the Audit History
tab's per-row "View" button, at `/resources/:id/rights_history` and
`/resources/:id/mods_history`. They succeed DRS v1's per-object "Rights History"
and "MODS History" pages, and they are read-only.

Every data call hits Atlas's `/resources/:id/*` endpoints, so one controller
serves Work, Collection and Community without branching on type.
`load_resource!` fetches the resource for the page heading and the back-link to
its audit log.

### Three types, not any type

`load_resource!` also gates on the type. It raises `ResourceNotFound`, a 404,
for an unknown id or for any type outside `ModsableTypes::TYPES`. "Type-agnostic" means one controller serves
the three, not that any Atlas id may address it.

Nothing upstream refuses the others. Atlas answers `/resources/:id`,
`/history` and a MODS-version list for every resource type, so a FileSet, Blob,
Delegate or Person NOID would read cleanly and then raise in the view. Both
pages render a back link to the resource's **edit** page, and only these three
have one. By then the reads have already run.

The XML editor carries the same gate, for the same reason. See
`docs/people-and-routing.md`.

### The rights page

`#rights` is a paginated access-control ledger. Each entry expands one audit
event's before-and-after ACL snapshot into a two-column diff.

It shows one event a page (`PER_PAGE = 1`). The page is reached by a per-row
deep link, so it shows that single event's diff. The previous and next walker
steps to adjacent changes without stacking them.

The events it shows are the initial grant at creation and every later ACL
change: events whose `change_type` is `permissions` and whose `action` is in
`AuditEventsHelper::PERMISSION_VIEW_ACTIONS` (`create`, `update`). Atlas suppresses no-op permission writes, so
each one is a real transition.

An explicit `?page` wins. Otherwise, when the reader arrives by a "View" deep
link carrying `?at=<occurred_at>`, `page_for` lands on whichever page holds
that event, so its anchor resolves. With neither, or with an `at` that matches
nothing, it shows the first page.

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
