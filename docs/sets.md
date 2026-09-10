# Sets

A Set is a saved recipe over the repository — included collections,
individually added Works, and set-aside exclusions — stored in Atlas as a
Compilation. This page covers how Cerberus resolves that recipe for display and
download, and how the two bulk actions sweep the Works it denotes.

Source files:

- `app/services/set_resolver.rb`
- `app/controllers/set_downloads_controller.rb`
- `app/controllers/concerns/set_bulk_actions.rb`
- `app/jobs/concerns/set_sweep.rb`
- `app/services/set_work_enumerator.rb`

## Resolving the recipe

`SetResolver` resolves a Set's recipe against Solr. The recipe is the included
collections, plus individually added Works, minus set-aside exclusions.
Included collections resolve transitively, via a two-step reverse-ancestry
recipe: find the descendant containers, then their member Works.

The recipe arrives as the three noid lists off the `AtlasRb::Compilation`
response (`included_collections` / `included_works` / `excluded_works`).
Everything else — uuid resolution, descendant lookup, the membership fq — is
derived here from gated Solr queries. So a restricted recipe noun is silently
invisible to a user who may not discover it.

Every step runs through the gated SearchBuilder chain. A future surface may want
step 1 ungated, so a restricted intermediate container does not hide permitted
Works beneath it. Revisit if that need arises.

`SetResolver` is deliberately not an `ApplicationService`: there is no single
`#call` product. The resolver is instantiated once per render and read
piecemeal. First comes `SetResolver#contents_fqs`, for the controller to layer
onto a builder seeded with the live search state (mirroring
`CatalogController#find_children`). Then come the per-chip counts, provenance
lookups, and aside-zone documents the Set page renders around the results.
Every Solr round-trip is memoized on the instance.

### Constructor arguments

| Argument | What it is |
|---|---|
| `compilation:` | the `AtlasRb::Compilation` response, which carries the three bare-noid recipe arrays |
| `search_service:` | the `Blacklight::SearchService` supplying the gated search builder and index, typically the controller's `search_service` |

### What counts as contents

A Set's flat contents are leaf Works. Intermediate containers are enumerated
during resolution but are not themselves "contents", so `DEFAULT_TYPE_FILTERS`
excludes them, along with tombstoned documents.

`SetResolver#contents_count` is the gated tally of the Set's current contents —
the index page's Works column. It is zero for a recipe with no positive clause.

### Resolving noids to uuids

`noun_uuids` resolves all three noid lists to uuids in one gated lookup, keyed by
bare noid. Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`.
`collection_uuids` keeps the ordered `[noid, uuid]` pairs for the included
collections the user can see.

### Descendant containers

`container_sets` holds the container uuids per chip noid: the chip itself plus
every descendant container whose ancestor chain names the chip. One
reverse-ancestry query covers all chips, and each descendant document
self-reports which chips cover it via its own `ancestor_ids_ssim`.

### Chips, provenance, and the aside zone

`Chip` is one included collection with its gated contents tally. `live` is what
the Set currently shows from this collection; `total` is what it would show with
nothing set aside. They diverge only when a set-aside hole overlaps this
collection ("4,998 of 5,000"). `excluded_overlap` is the gated count of how many
of a chip's Works are currently set aside.

`SetResolver#provenance_for(document)` answers why a result row is in the Set.
It returns `:direct` for an individually added Work. Otherwise it returns the
noid of the first included collection whose subtree covers one of the
document's membership edges.
It is nil when nothing matches — for example a row reached via an edge the user
cannot trace. A document's membership edges are its structural parent
(`a_member_of_ssi`) plus the linked overlay (`a_linked_member_of_ssim`), as bare
container uuids.

`SetResolver#aside_documents` returns the set-aside Works as gated Solr
documents for the aside zone.

## Exporting a Set

`SetResolver#each_content_batch` streams the Set's resolved content Works for
bulk export, yielding gated `SolrDocument`s in pages. It is the *same* gated
contents search the show page runs, so a viewer only ever exports what they can
discover. Per-member permission gating comes free, exactly as on the page. It
does not yield at all when the recipe has no positive clause.

`fl` is trimmed to `PACKER_FIELDS`. The pull is paged rather than one giant
fetch. It is capped at `MAX_EXPORT_ROWS` as a coarse runaway guard, until the
deferred cumulative-size cap and async job fallback land.

### The field list is the union of both packers

`PACKER_FIELDS` asks the packers to state their own requirements, rather than
keeping a separate list that has to be remembered alongside them. They were
separate once. A packer gained an embargo check while the field list still said
"just the noid". The check then read nil on every document and withheld
nothing.
That failure is silent, and it fails towards serving content.

It is the union of both packers' fields because this resolver feeds both —
`SetZipPacker` for the content download and `MetadataExportPacker` for the
manifest. Asking for only one packer's fields reintroduces the same silent-nil
bug on whichever path was left out. `embargoed_bsi` was missing that way, so a
Work embargoed by flag rather than by release date exported as not embargoed.

### Discovery gating is not the whole rule

An embargoed Work is deliberately discoverable — public metadata, withheld
content. So it clears the gated search and arrives at the packer like any other
member. The packer has to withhold it itself, which is why the embargo fields
are in the field list. Trimming them away silently disabled the check and put
embargoed bytes into anonymous archives.

### The download controller

`SetDownloadsController` streams a Set's content as a ZIP. It is a dedicated
controller, not an action on `SetsController`, because `ActionController::Live`
streams *every* action in its controller. That is the same reason
`DownloadsController` is its own thing. It subclasses `CatalogController` so it
inherits the `GatedSearchService` and `search_service_context`: the contents
resolve through the identical gated search the Set show page uses.

Auth mirrors `SetsController#show`: no `authenticate_user!`, no curator gate. A
public Set is publicly downloadable; a private one 403s at
`AtlasRb::Compilation.find`, because Atlas is the boundary. A caught
`AtlasRb::ForbiddenError` renders the standard forbidden page, and unknown ids
surface as `JSON::ParserError` via `Authorizable`'s 404 path. The heavy lifting
is in `SetZipPacker`; the controller resolves, guards empty, and opens the
stream.

`bypass_embargo?` hands the packer the **caller's** bypass right, never the set
owner's. It reads `effective_user` rather than `current_user`, so the caller
means the identity a View-as session is standing in. With `current_user` the
archive was built as the real admin while every single-file route
(`DownloadsController`, `MediaController`, `DerivativeDownloadsController`)
resolved as the target. An admin checking what someone can reach then got a 403
from the file and the same file inside the ZIP. That defeats the only thing
View-as is for.

## Bulk actions over a Set's Works

`SetBulkActions` holds the Set edit page's two bulk actions: privatize, and
apply the Set's derivative-access policy. It also holds the Sentinel authoring
that feeds one of them.

### Who may run one

Both sweeps write the Set's *Works*, not the Set, so neither is governed by who
may curate the recipe. A grantee with edit on a Set can add a collection holding
fifty thousand Works they have no say over. They are operator-only — full admin
or the devolved tier, via `bulk_operator?`. `require_bulk_operator` is
deliberately not gated on `@owned`, because owning a Set says nothing about the
Works a recipe reaches. Atlas re-checks every per-Work write regardless; this
gate decides who is offered the button.

The view renders the two tabs on the same predicate the write path gates on. So
a tab and its pane cannot disagree about who may use it.

### There is no bulk publicize

The two actions are deliberately asymmetric in what they promise. Privatize
takes access away and is safe to offer broadly within that tier. There is no
bulk publicize to match it, because a one-click widening across a whole Set is a
disclosure foot-gun with no comparable use case. The tab is named so it does not
imply the inverse exists.

### Authoring the Sentinel

`SetBulkActions#sentinel` upserts this Set's derivative-access policy, its
Sentinel. Unlike the Collection tab, no container ceiling is handed to the
record. A Collection's ACL governs the Works inside it, so a tier more visible
than the Collection is incoherent on its face. A Set's ACL governs only who may
see the *Set object*, and its Works keep whatever visibility they had before
anyone curated them in.

The ceiling that matters here is each Work's own. That is per-Work, and
therefore applied at sweep time — `SetSentinelApplyJob` clamps — rather than at
authoring time. Monotonicity still holds, because that is a property of the
ladder, not of any container.

`sentinel_groups` offers every group, not the acting user's own memberships.
That looks like it diverges from `PermissionsForm#groups_for_permissions_picker`,
but it is the same rule with the other branch removed. That helper hands the
full list to an admin or devolved admin, and falls back to personal memberships
for everyone else. And everyone else cannot reach this tab at all.

`sentinel_policy_from_params` builds the per-tier policy from the ladder form.
Its "no added restriction" mode omits the tier rather than writing `['public']`.
That is the Collection tab's behaviour on a *private* collection, and it is the
only coherent choice for a Set. An omitted tier rides each Work's own visibility
at apply time, so one policy can span a Set that mixes public and restricted
Works.

`apply_sentinel` refuses to enqueue until a policy has been saved, then enqueues
`SetSentinelApplyJob`; `privatize` enqueues `SetPrivatizeJob`. Both redirect back
to the tab they were run from with a notice saying a message will arrive when the
sweep finishes.

## Sweeping the Works

`SetSweep` is the scaffolding both Set bulk sweeps share. The shared steps are:
resolve the Set, walk the Works it denotes, apply a per-Work change, and tell
whoever asked for it what happened.

The two sweeps differ only in the change they make to each Work and the words
they report it in. Everything else is the same, and needs to stay the same.
That covers how a Set is re-read at run time, which errors abort and which are
collected, and how a truncated walk is disclosed. Both are operator actions over
content someone else deposited, and both are judged by whether a partial run is
obvious afterwards.

`Outcome` records what one sweep did. `counts` tallies outcomes by the symbol the
per-Work step returns, so a sweep names its own outcomes without this concern
knowing them.

`sweep_set(set_noid:, nuid:, &step)` walks the Set's Works, yielding each NOID to
the caller's per-Work step, which returns a symbol naming what it did. `nuid` is
the acting operator, scoping the walk.

### Reporting a partial run

`sweep_report_tail(set_noid, outcome, failures_lead)` writes the trailing lines
every sweep report ends with: the truncation disclosure, the named failures, and
a link back to the Set. `failures_lead` is how this sweep describes what a
failure left behind, which is the only part that differs.

Failures are named rather than counted. The reason: in both sweeps a Work that
did not change is a Work still carrying the access the operator meant to take
away. That is the one outcome they must not have to discover for themselves.

### Listing the Works a Set denotes

`SetWorkEnumerator` returns the NOIDs of the Works a Set currently denotes, for
the bulk actions that sweep them.

Atlas resolves the recipe rather than Cerberus doing it, because a job has no
request and `SetResolver` needs a request-bound gated search service. The
endpoint also honours the Set's set-asides — Atlas applies the recipe's
exclusions server-side — and drops tombstoned Works. So neither has to be
re-derived here.

The list is collected before anything mutates it. Collecting first costs one NOID
string per Work, which is the cheapest thing in the payload. The documents
themselves are never held, per the batch-job memory budget rule.

`nuid:` is the acting curator, whose discovery scopes the walk. A full Atlas
admin sees every Work; anyone else sees public Works plus their own groups'.

`MAX_WORKS` bounds one sweep, mirroring `SetResolver::MAX_EXPORT_ROWS`. A recipe
that names several large collections can denote far more Works than anyone means
to touch in one click. So the caller reports the truncation, rather than running
for an hour and leaving the reader to guess. `SetWorkEnumerator#call` returns a
`Result` carrying the NOIDs and whether `MAX_WORKS` cut the walk short.

`total_pages` trusts the pagination when Atlas sends it. The walk then stops on
the last page, instead of paying one empty request to discover the end.
