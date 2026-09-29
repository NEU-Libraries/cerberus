# Sets

A Set is a saved recipe over the repository: included collections, plus
individually added Works, minus set-aside exclusions. Atlas stores it as a
Compilation. This page covers how Cerberus resolves that recipe for display and
download, and how the two bulk actions sweep the Works it denotes.

Source files:

- `app/services/set_resolver.rb`
- `app/controllers/set_downloads_controller.rb`
- `app/controllers/concerns/set_bulk_actions.rb`
- `app/jobs/concerns/set_sweep.rb`
- `app/services/set_work_enumerator.rb`

## Resolving the recipe

`SetResolver` resolves a Set's recipe against Solr. Included collections
resolve transitively, in two steps: find the descendant containers, then their
member Works.

The recipe arrives as the three noid lists on the `AtlasRb::Compilation`
response: `included_collections`, `included_works` and `excluded_works`.
Everything else — uuid resolution, the descendant lookup, the membership `fq` —
is derived from gated Solr queries. So a recipe noun the user may not discover
is silently invisible to them.

Every step runs through the gated SearchBuilder chain. A future surface may want
step 1 ungated, so that a restricted intermediate container does not hide
permitted Works beneath it. Revisit that if the need arises.

`search` adds its filters with `with_filters`, not a merged `:fq`. Merging `:fq`
drops the gated-discovery clause the search builder adds.

`SetResolver` is deliberately not an `ApplicationService`: it has no single
`#call` product. A caller builds one per request and reads it piecemeal:

- `contents_fqs`, which `SetsController#contents_response` layers onto a builder
  seeded with the live search state. That is the shape of
  `CatalogController#find_children`.
- The chips, provenance lookups and aside-zone documents. The Set show page
  renders them around the results. The Set edit page's Definition tab
  (`sets/_definition`) renders them too.

The recipe lookups are memoized on the instance, so the chips, provenance and
aside zone share one set of Solr round-trips.

### Constructor arguments

| Argument | What it is |
|---|---|
| `compilation:` | The `AtlasRb::Compilation` response, which carries the three bare-noid recipe arrays |
| `search_service:` | The `Blacklight::SearchService` that supplies the gated search builder, typically the controller's `search_service` |

### What counts as contents

A Set's flat contents are leaf Works. Resolution enumerates the intermediate
containers, but they are not "contents". `DEFAULT_TYPE_FILTERS` restricts every
contents query to `internal_resource_tesim:Work` and excludes tombstoned
documents.

`contents_fqs` returns nil, never `[]`, when the recipe has no positive clause.
A search with no `fq` at all matches the whole index, so each caller treats nil
as "empty" instead.

`SetResolver#contents_count` is the gated tally of the Set's current contents.
The index page's Works column shows it, fetched lazily per row by
`SetsController#works_count`. It is zero for a recipe with no positive clause.

### Resolving noids to uuids

`noun_uuids` resolves all three noid lists to uuids in one gated lookup, keyed
by bare noid. Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`.
`collection_uuids` keeps the ordered `[noid, uuid]` pairs for the included
collections the user can see.

### Descendant containers

`container_sets` holds the container uuids for each chip noid: the chip itself
plus every descendant container whose ancestor chain names the chip. One
reverse-ancestry query covers all chips. Each descendant document reports which
chips cover it through its own `ancestor_ids_ssim`.

### Chips, provenance and the aside zone

`Chip` is one included collection with its gated contents tally. `live` is what
the Set currently shows from this collection; `total` is what it would show with
nothing set aside. They differ only when a set-aside Work falls inside this
collection ("4,998 of 5,000"). The private `excluded_overlap` computes that gap:
the gated count of the chip's Works that are currently set aside.

`SetResolver#provenance_for(document)` answers why a result row is in the Set.
It returns `:direct` for an individually added Work. Otherwise it returns the
noid of the first included collection whose subtree covers one of the
document's membership edges. It returns nil when nothing matches, for example
for a row reached through an edge the user cannot trace. A document's
membership edges are its structural parent (`a_member_of_ssi`) plus the linked
overlay (`a_linked_member_of_ssim`), as bare container uuids.

`SetResolver#aside_documents` returns the set-aside Works as gated Solr
documents for the aside zone. It returns only exclusions the recipe still
reaches. Atlas keeps an exclusion row when its collection is removed from the
Set, so without the positive clause a Work set aside from a departed collection
would linger there.

## Exporting a Set

`SetResolver#each_content_batch` streams the Set's resolved content Works for
bulk export, yielding gated `SolrDocument`s in pages of 200. It runs the *same*
gated contents search as the show page, so a viewer only ever exports what they
can discover. Per-member permission gating comes free, exactly as on the page.
It yields nothing when the recipe has no positive clause.

`fl` is trimmed to `PACKER_FIELDS`. The pull is paged rather than one giant
fetch, and stops at `MAX_EXPORT_ROWS` (10,000). That cap is a coarse runaway
guard, not a size limit. There is no cumulative-size cap and no fallback to an
async job.

### The field list is the union of both packers

`PACKER_FIELDS` is built from each packer's own `REQUIRED_DOC_FIELDS`, rather
than a separate list here that someone must remember to update. A separate list
goes stale silently. When a packer adds a check, such as the embargo check, and
the list omits its field, the check reads nil on every document and withholds
nothing. That failure is silent, and it fails towards serving content.

It is the union of both packers' fields because this resolver feeds both:
`SetZipPacker` for the content download and `MetadataExportPacker` for the
manifest. Asking for only one packer's fields brings back the same silent-nil
bug on the other path, and that packer's embargo column reads blank.

### Discovery gating is not the whole rule

An embargoed Work is deliberately discoverable: its metadata is public and its
content is withheld. So it passes the gated search and reaches the packer like
any other member. The packer must withhold it itself, which is why the embargo
fields are in the field list. Trim them away and the check stops working, and
embargoed files go into anonymous archives.

### The download controller

`SetDownloadsController#show` streams a Set's content as a ZIP. It is a
dedicated controller, not an action on `SetsController`, because
`ActionController::Live` streams *every* action in its controller.
`DownloadsController` is its own controller for the same reason.
`SetDownloadsController` subclasses `CatalogController` to inherit the
`GatedSearchService` and `search_service_context`. So the contents resolve
through the same gated search the Set show page uses.

Its access rule matches `SetsController#show`: no `authenticate_user!` and no
curator gate. A public Set is publicly downloadable. Atlas is the boundary for
a private one: it refuses the `AtlasRb::Compilation.find`, and the refusal
renders the standard forbidden page. An unknown id reads back as nil, and
`require_resource!` turns that into `Authorizable`'s 404.

The controller resolves the Set, redirects back with an alert when
`contents_count` is zero, and opens the stream. `SetZipPacker` does the heavy
lifting.

`bypass_embargo?` hands the packer the **caller's** right to bypass an embargo,
never the Set owner's. Inheriting the owner's reach would put embargoed files
into anonymous archives. It reads `effective_user`, not `current_user`, so in a
View-as session the caller is the identity being viewed as. Every single-file
route (`DownloadsController`, `MediaController`,
`DerivativeDownloadsController`) resolves as that identity too. If the ZIP were
built as the real admin, an admin checking what someone can reach would get a
403 from a file and the same file inside the ZIP. That defeats the only thing
View-as is for.

## Bulk actions over a Set's Works

`SetBulkActions` holds the Set edit page's two bulk actions: make the Set's
Works private, and apply the Set's derivative-access policy. It also holds the
Sentinel authoring that feeds the second one.

### Who may run one

Both sweeps write the Set's *Works*, not the Set, so who may curate the recipe
does not govern them. A grantee with edit on a Set can add a collection holding
fifty thousand Works they have no say over. So both actions are operator-only:
full admin or the devolved tier, through `bulk_operator?`. Atlas re-checks
every per-Work write regardless; this gate decides who is offered the button.

`require_bulk_operator` is deliberately not gated on `@owned`, because owning a
Set says nothing about the Works a recipe reaches.

`SetsController` registers `require_bulk_operator` after `authenticate_user!`,
not in the concern's `included` block. A concern's `included` callbacks run
ahead of the before_actions the class declares below the include. Registering
it there answered an anonymous POST with 403 instead of sending it to sign in.

The edit view renders the Derivative access and Visibility tabs on the same
`bulk_operator?` predicate that the write path gates on. So a tab and its pane
cannot disagree about who may use it.

### There is no bulk publicize

The two actions are deliberately asymmetric. Privatizing takes access away, and
is safe to offer to the whole operator tier. There is no bulk publicize to
match it, because a one-click widening across a whole Set is a disclosure risk
with no comparable use case. The tab is named so it does not imply the inverse
exists.

### Authoring the Sentinel

`SetBulkActions#sentinel` creates or updates this Set's derivative-access
policy, its Sentinel. Unlike the Collection tab, it hands the record no
container ceiling (`resource_read_groups`). A Collection's ACL governs the Works
inside it, so a tier more visible than the Collection is incoherent. A Set's ACL
governs only who may see the *Set object*. Its Works keep whatever visibility
they had before anyone curated them in.

The ceiling that matters here is each Work's own. That is per-Work, so
`SetSentinelApplyJob` clamps each tier at sweep time rather than at authoring
time. The ladder's order still holds (see `docs/narrowing.md`), because it is a
property of the ladder, not of any container.

`sentinel_groups` offers every group (`Group.for_select`), not the acting user's
own memberships. That looks like it diverges from
`PermissionsForm#groups_for_permissions_picker`, but it is the same rule with
one branch removed. That helper gives the full list to an admin or devolved
admin, and personal memberships to everyone else. Everyone else cannot reach
this tab.

`sentinel_policy_from_params` builds the per-tier policy from the ladder form.
Its "no added restriction" mode omits the tier rather than writing
`['public']`. That matches the Collection tab's behaviour on a *private*
collection, and it is the only coherent choice for a Set. An omitted tier
follows each Work's own visibility at apply time, so one policy can span a Set
that mixes public and restricted Works. Atlas would refuse `['public']` on every
private Work in the sweep.

A rejected policy re-renders the edit page holding the *submitted* policy, with
the Derivative access pane open (`@open_tab`). A redirect would discard every
selection the curator made.

`apply_sentinel` refuses to enqueue until a policy has been saved, then enqueues
`SetSentinelApplyJob`. `privatize` enqueues `SetPrivatizeJob`. Both redirect to
the edit page with `tab:` naming the pane they ran from, since Turbo's fetch
drops a URL fragment on a redirect. The notice says a message will arrive when
the sweep finishes.

## Sweeping the Works

`SetSweep` is the scaffolding both Set bulk sweeps share: resolve the Set, walk
the Works it denotes, apply a per-Work change, and tell whoever asked what
happened.

The two sweeps differ only in the change they make to each Work and the words
they report it in. Everything else is shared, and must stay shared: how a Set
is read at run time, which errors abort and which are collected, and how a
truncated walk is disclosed. Both are operator actions over content someone
else deposited, and both are judged by whether a partial run is obvious
afterwards.

`sweep_set(set_noid:, nuid:, &step)` walks the Set's Works. It yields each NOID
to the caller's per-Work step, which returns a symbol naming what it did. `nuid`
is the acting operator, and scopes the walk.

`sweep_set` collects anything the step raises (`AtlasRb::Error` or
`Faraday::Error`) against that Work, and the walk continues. The exception is
`AtlasRb::StaleResourceError`. It escapes to the job's `retry_on`, because
re-running an idempotent sweep only re-skips the Works already done.

`Outcome` records what one sweep did: `counts`, `failures` and `truncated`.
`counts` tallies outcomes by the symbol the step returned, so a sweep names its
own outcomes without this concern knowing them. It is named `counts`, not
`tally`, because a Struct is Enumerable and `tally` would shadow
`Enumerable#tally`.

### Reporting a partial run

`sweep_report_tail(set_noid, outcome, failures_lead)` writes the lines every
sweep report ends with: the truncation notice, the named failures, and a link
back to the Set. `failures_lead` is how this sweep describes what a failure left
behind, which is the only part that differs. The link is a path, not a URL,
because a job has no request to take a host from.

Failures are named rather than counted. In both sweeps a Work that did not
change still carries the access the operator meant to take away. That is the
one outcome the operator must not have to discover for themselves.

### Listing the Works a Set denotes

`SetWorkEnumerator` returns the NOIDs of the Works a Set currently denotes, for
the bulk actions that sweep them. It pages through
`AtlasRb::Compilation.contents`.

Atlas resolves the recipe here, not Cerberus, because a job has no request and
`SetResolver` needs a request-bound gated search service. The endpoint also
applies the Set's set-asides server-side and drops tombstoned Works, so neither
has to be re-derived here.

The enumerator collects the full list before anything mutates it. The contents
endpoint is gated on read. A sweep that wrote as it paged would move Works out
of its own result set and silently skip them. Collecting first costs one NOID
string per Work, the cheapest thing in the payload. The documents themselves are
never held, per the batch-job memory budget rule.

`nuid:` is the acting operator, whose discovery scopes the walk. A full Atlas
admin sees every Work; anyone else sees public Works plus their own groups'.

`MAX_WORKS` (10,000) bounds one sweep, matching `SetResolver::MAX_EXPORT_ROWS`.
A recipe that names several large collections can denote far more Works than
anyone means to touch in one click. So the caller reports the truncation,
rather than running for an hour and leaving the reader to guess.
`SetWorkEnumerator#call` returns a `Result` carrying the NOIDs and whether
`MAX_WORKS` cut the walk short.

`call` removes duplicates before it applies the cap, so a Work the recipe
reaches twice costs one slot. Landing exactly on the cap still counts as
truncated when pages remain. Testing only for overflow would report a clean run
over an untouched remainder.

`PER_PAGE` is 100, because Atlas caps `per_page` at 100. The walk stops on the
last page that the response's `pagination.pages` names, rather than paying an
empty request to find the end. A response without `pagination` reads as zero
pages, so the walk stops after the first page.
