# People, routing and trails

The People discovery surfaces, the breadcrumb trails every controller builds,
and the redirect that catches a DRS v1 URL. Plus the raw-XML editor, and the
background jobs that sweep or reindex a Set's Works.

Source files:

- `app/controllers/people_controller.rb`
- `app/controllers/admin/community_people_controller.rb`
- `app/services/community_affiliates.rb`
- `app/controllers/legacy_controller.rb`
- `app/models/legacy_identifier.rb`
- `app/controllers/application_controller.rb`
- `app/lib/atlas_routes.rb`
- `app/lib/modsable_types.rb`
- `app/controllers/concerns/structural_containers.rb`
- `app/controllers/xml_controller.rb`
- `app/jobs/set_sentinel_apply_job.rb`
- `app/jobs/set_privatize_job.rb`
- `app/jobs/set_reindex_job.rb`
- `app/jobs/concerns/set_sweep.rb`
- `app/jobs/multipage_item_job.rb`

## The People surfaces

`PeopleController` renders curated Person records — the Faculty & Staff identity
— as Blacklight result sets, like any other content type. It has two actions.

| Action | Route | What it renders |
|---|---|---|
| `index` | `/people` | A gated Blacklight search over Person docs, global |
| `index` | `/communities/:community_id/people` | The same search, scoped to one community's affiliated People — the Faculty & Staff browse |
| `show` | `/people/:id` | One profile: the curated header (display name, bio, ORCID) over a gated faceted search of the Works that person deposited |

The controller inherits `CatalogController`, which is where the gated
`search_service` comes from. It includes `WithoutFacetModal`, because it owns no
`facet` route for the sidebar's "See more" link (see `docs/discovery.md`).

### Affiliations from the community's side

A Person holds its own affiliations, `affiliated_community_ids`. The admin
People registry edits them from the person's side. The community's People page
in the admin hub (`/admin/communities/:noid/people`) edits the same list from the
community's side, so a change made on either shows on the other at once.

`CommunityAffiliates` lists a community's People from Solr, on the Faculty &
Staff browse's `affiliated_community_ids_ssim` filter, in name order, up to
`LIMIT`. It reads the raw index rather than a SearchBuilder, which is safe only
because the page is admin-only. Add and Remove call `Person.add_affiliation`
and `remove_affiliation`. The page shows NUIDs, as the People registry does.

### A Person is addressed by NOID

`params[:id]` is the Person's NOID. Cerberus reads the NUID server-side, off the
Person record, and never puts it in a URL or on a rendered page. NEU IT Security
requires that the site offer no NUID enumeration or scraping surface.

`deposited_works` therefore takes the NUID from the Person record it already
fetched, not from params.

### Scoping to People with a facet, not a hidden filter

`scope_to_people` defaults the Type facet to `type_ssim:Person`. The scope uses
the facet rather than a hidden `fq`. So it renders as a constraint chip ("Type ›
Person"), and reads as applied in the Type facet. That is the same behaviour the
genre landing pages have. `type_ssim:Person` selects exactly the Person docs.

The method is idempotent. It leaves a user-supplied `type_ssim` alone, so a
hand-edited query string can widen the browse to other types. The search is
still gated.

It runs as a `prepend_before_action` because Blacklight memoizes `search_state`,
and `search_state` dups params when it is constructed. A mutation made later, in
the action body, is snapshotted away.

### Keeping the embedded search on the People surface

`PeopleController` overrides `search_action_url` so the facet links,
search-within box and pagination of the embedded search stay on the People
surface. That is `/people`, `/communities/:id/people`, or `/people/:id`, instead
of escaping to `CatalogController#index`. The override picks the target from
whichever id param the request carries.

### What a profile lists

`deposited_works` restricts the result set to Works. `depositor_ssi` is also
stamped on the Collections and Communities a person *created*, and a profile
lists scholarly output rather than containers.

`.with(search_state)` threads the live query, facets, sort and page through, so
the profile is browsable rather than a fixed list.

`solr_phrase` strips the quote and backslash characters that could otherwise
break out of a quoted Solr phrase.

### The workspace Add menu

`show` also offers the Add menu for the person's personal root, because the
workspace's show page redirects here. That makes this the only in-app route for
a proxy depositor into someone else's workspace. `assign_workspace_add` gates it
like every Add, on `:edit` over the root Collection. A failed permissions read
hides the menu.

### Degrading when a lookup fails

`find_community` returns nil for an unknown or malformed NOID. The affiliation
filter keys on the NOID from the URL, not on the fetched community, so it then
matches nothing and the browse renders empty.

## Breadcrumb trails

`ApplicationController` holds the builders. `breadcrumbs(id, editing:, match:,
result:)` fetches the resource once and walks its ancestors. `ancestors` carries
each ancestor's title alongside its NOID and class, so the whole trail comes out
of that single find with no per-ancestor round trip.

`result:` lets a caller that already fetched the resource — to branch on its
ancestry, say — hand it in and avoid a second `AtlasRb::Resource.find`.

### Turning an Atlas type into a path

`AtlasRoutes::ROUTES` maps an Atlas type name to the Rails route that serves
it. `ApplicationController#resource_path` and `#edit_resource_path` read it and
are both helper methods, so the breadcrumb builders, the XML editor and the
history pages all reach a path the same way.

The map is stated rather than derived, and what it buys is `route_for`'s raise:
an Atlas type nobody has mapped says so at the map, instead of reaching
`public_send` with a route helper that does not exist. Downcasing the class name
would in fact work for every type currently in it.

It also records the vocabulary split, which is real even though nothing
exercises it: Atlas's `Compilation` is the UI's Set — `SetsController`,
`set_path`, no `compilation_path` anywhere. Nothing can hand the map that string,
because the generic resolver answers 404 for a Compilation NOID (it serves
Valkyrie-backed types only) and Solr does not index Compilations. So no Set NOID
reaches a surface that builds a path this way. The entry stays because its
route is correct if either of those changes.

Use these two only where the type arrives as *data* — from
`AtlasRb::Resource.find(...).klass`, or from a Solr document's
`internal_resource_tesim`. A controller that knows its own type declares it with
`atlas_resource` and reads `show_path` / `edit_path` back, which needs no map at
all. See `docs/edit-surfaces.md`.

`route_for` raises `ArgumentError` on a type it has not been taught, rather than
returning a default. `Person` is mapped, but People have no public edit page, so
no `edit_person_path` exists. `edit_resource_path('Person', id)` therefore raises
`NoMethodError` from `public_send`.

That raise is a backstop, not the gate. A surface that resolves an arbitrary
NOID should refuse a type it cannot serve before it builds a path — see [Only
three types may reach it](#only-three-types-may-reach-it) for the XML editor's
version of that check.

### `match:` and the prefix problem

`match:` is forwarded to loaf. The default, `:inclusive`, is loaf's own, and is
kept for existing callers. Cross-resource trails pass `:exact`.

The reason is prefix matching. `/communities/:id` is a prefix of
`/communities/:id/people`, and `/works/:id` is a prefix of `/works/:id/edit`.
Under inclusive matching loaf marks the ancestor as the current crumb, so it
stops being a link and the trail loses its way back.

`edit_breadcrumb_tail` is the tail of an edit-page trail. The resource becomes a
link to its show page, with `match: :exact` for that reason, followed by a
non-link "Edit `<Klass>`" you-are-here crumb.

### The People trails

`PeopleController` builds two trails, and both lead through the community rather
than through the flat People index.

- `build_profile_breadcrumbs` leads Northeastern University / Communications /
  Faculty & Staff / *name*, using the person's first affiliated community.
- `build_faculty_staff_breadcrumbs` mirrors it for the browse, ending on a
  "Faculty & Staff" you-are-here crumb.

Both degrade on a failed community read. A person with no affiliation gets the
flat People / *name* trail. On the profile, `person_trail` rescues
`AtlasRb::ResourceError` (a gated community refuses the read), `Faraday::Error`
and `JSON::ParserError`, and falls back to the same flat trail. The browse
rescues only `Faraday::Error` and `JSON::ParserError`, and falls back to the lone
"Faculty & Staff" crumb. The `AtlasRb::Resource.find` inside `breadcrumbs` runs
before any crumb is added, so a failure leaves the trail empty and the rescue
can rebuild it from nothing.

Neither path handles a stale community NOID, one Atlas answers with a 404.
`Resource.find` returns `nil` on a 404 rather than raising, and `breadcrumbs`
then calls `resource` on `nil`.

The profile trail is `StructuralContainers#person_trail`, which the trail under
a personal root reuses. So a Work's trail extends its owner's profile trail
exactly, and the two cannot drift.

### Content under a personal root

Atlas keeps the People Community and each personal root in every ancestor chain
below them, and flags each entry with `system_container` or `personal_root`.
Neither container is content, so `StructuralContainers#ancestor_trail` replaces
both with the owner's profile trail and keeps every Collection below the root:

```
Northeastern University / Faculty & Staff / Mickey Gasper / Baseball stuff / monograph-3.pdf
```

It runs inside `ApplicationController#breadcrumbs`, so every trail gets it: show
and edit pages for Works and Collections, the upload page, and the XML editor.
Every viewer sees the same trail, the owner included.

The whole chain is searched for the root, not just the item's parent, because a
workspace nests Collections to any depth. The root's own edit page is the one
case with no flagged ancestor: there the root is the item, so the item's own
`personal_root` flag starts the owner trail.

**The owner comes from the root, not from the item's depositor.** A proxy or a
seed can deposit into someone else's workspace. `personal_root_owner` reads the
Person whose Solr document has `personal_root_id_ssi` equal to the root. That
document also carries the display name, NOID and affiliations the trail needs
(`PERSON_FIELDS`).

If no Person answers, the structural entries are still dropped. The raw chain
is exactly the trail this exists to avoid.

### The two structural show pages redirect

| Page | Redirects to |
|---|---|
| The People Community (`CommunitiesController#show`) | `/people` |
| A personal root (`CollectionsController#show`) | The owner's profile, or `/people` if no Person answers (`personal_root_home`) |

**The People check reads Solr before the Atlas find.** Atlas refuses that
Community to everyone but full admins, so a check on the Atlas response would
redirect only the admin and leave everyone else on a 403. `system_container?` is
an ungated Solr read of `system_container_bsi` for that reason, and it answers
one boolean about a known id.

The edit pages do not redirect, so an administrator can still reach both
containers' settings.

## Request-wide setup

`ApplicationController` sets up the identity every request runs under.

`set_current_nuid` sets `Current.nuid` to the signed-in user's NUID, or to the
configured guest NUID (`config.x.cerberus.guest_nuid`). It also sets
`Current.account_email` from the session, which `AccountsController` writes when
someone switches account. It stays `nil` otherwise, so atlas_rb sends no account
claim and Atlas resolves the preferred account.

`current_ability` builds the Ability from `effective_user`, which
`ImpersonationSession` supplies and which is `current_user` when nobody is
impersonating. Under view-as, the page therefore renders the target's access
decisions. Acting-as leaves this as the real administrator: only writes are
re-attributed.

`attributed_nuid` is the identity Cerberus-side writes are attributed to:
`Current.on_behalf_of` during an acting-as session, else `Current.nuid`. It
matches the deposit convention. Acting-as work belongs wholly to the target, so
the target's inbox gets the follow-ups, not the administrator's.

`MaintenanceGate` is included after `set_current_nuid` rather than with the other
concerns, because its `before_action` must run after it. Reading the maintenance
window from Atlas is an authenticated read, and `Current.nuid` is what the signed
assertion carries. See `docs/maintenance.md` for what the gate does.

## Redirecting a DRS v1 URL

`LegacyController` sends an inbound `neu:` pid URL to the v2 object it became at
migration.

v1 ran on Fedora, so every object carried a `neu:` pid. v2 mints fresh NOIDs and
does not carry the pid forward. Ten years of `neu:` pid URLs live in published
papers, syllabi, finding aids, catalogue records and the search index. Without
this controller they all land on a 404.

The routes catch five v1 prefixes — `/files`, `/collections`, `/communities`,
`/downloads` and `/sets` — with a `neu:` constraint, and send all of them to
`show`. They must precede the v2 resource routes in `config/routes.rb`, because
four of the prefixes are also v2 routes and Rails matches in declaration order.
The constraint makes that safe: a v2 NOID never contains a colon.

A hit redirects. A pid that never existed 404s. There is no `410 Gone` branch,
because every v1 object migrates. That includes the hand-rolled integer pids, one
of which, `neu:1`, is the root Northeastern University Community.

### The path prefix does not decide the destination

The inbound path prefix is only how the URL is caught. `object_type` on the
mapping row decides where the request goes, because the prefixes do not
correspond. A v1 CoreFile at `/files/:pid` is a v2 Work at `/works/:noid`.

That also means the request never has to ask Atlas what kind of thing a NOID
names. That matters when the caller is a crawler working through a decade of
links.

Migration tooling outside this app writes the rows, so an `object_type` the
model never validated can arrive. `destination_for` logs it and returns `nil`,
which takes the same 404 path as an unknown pid. The 404 renders directly, with
"page" as the missing thing, rather than through `ResourceNotFound`, which would
call it "the legacy you requested".

### The redirect status

`REDIRECT_STATUS` is `:found`, a 302, while the mapping table is unverified.
Browsers and intermediaries cache a 301 hard, so a wrong row would outlive its
fix. A 301 is the intended end state, because it transfers search-index equity
to the new URLs. Flip the constant to `:moved_permanently` once the migration's
mappings are confirmed.

## The raw-XML editor

`XmlController` is the raw-XML sub-tab of a resource's edit page. It has four
actions: `editor`, `validate`, `repair` and `update`.

It gates like its sibling Metadata and Permissions tabs: authenticate, then
check the `:edit` ability on the resource, mirroring the resource controllers'
`authorize_edit!`. `authorize_xml_edit!` reads whichever id param the action
carries, because `editor` carries `params[:id]` and `validate`, `repair` and
`update` carry `params[:resource_id]`.

### Only three types may reach it

`require_modsable_resource!` refuses a type that has no MODS editing surface,
before anything reads or renders. `ModsableTypes::TYPES` is the set: Work,
Collection and Community. Atlas names the same set with its own `Modsable`
concern, and atlas_rb's `mods_versions` doc names the same three.

The `:edit` gate above it is not enough on its own, and neither is the read
succeeding:

| Step | Why it admits a FileSet, Blob, Delegate or Person |
|---|---|
| `authorize_xml_edit!` | Atlas answers `/resources/:id/permissions` for **every** resource type, so a hand-typed NOID of any type passes |
| The MODS read | atlas_rb defines `Resource.mods` on the base class, so every subclass answers it and the read returns |
| The breadcrumb tail | `ApplicationController#edit_breadcrumb_tail` builds the resource's show and edit paths, and none of the four has both — so this is where the request would 500 |

Without the gate, each of the four reaches that last step and 500s. A FileSet,
Blob or Delegate has no entry in `AtlasRoutes::ROUTES`, so `route_for` raises. A
Person has a `person_path` but no title, so the crumb builder refuses a nil
name. Nothing in the UI links to any of them, and nothing else refuses them.

The set is stated rather than inferred. Only these three take a MODS write —
theirs is the `update` that accepts `origin:` — and a curator sent back after
saving needs a show route to land on. `ModsableTypes.include?` takes a type
*name* rather than a class, so a caller hands over whatever Atlas or Solr gave
it, and a type atlas_rb does not map answers false rather than raising.

`require_modsable_resource!` raises `ResourceNotFound`, a 404, for an unknown id
or an unserved type.

`resolved_resource` memoizes the one `AtlasRb::Resource.find` per request. The
gate needs the payload before any action runs, and every action needs it again.

### Resolving the type

The sites that dispatch on the resolved type — `ModsableTypes.include?` and
`XmlController#record_errors` — call `AtlasRb::Resource.class_for`, not
`AtlasRb.const_get`. The gem owns that mapping over a stated closed set,
`Resource::TYPE_MAP`. It accepts every spelling the stack produces: Atlas's wire
key (`file_set`), Solr's `internal_resource` (`FileSet`), and the
capitalized wire key (`File_set`). It raises `ArgumentError` on anything else.

Do not reach into the `AtlasRb` namespace by string. Capitalizing Atlas's wire
key gives `"File_set"`, which is not a constant, so `const_get` raises
`NameError`. The naming convention that appears to hold is not promised.

### Repair offers, it does not apply

A surface labelled "Edit raw XML" that rewrote bytes on their way to storage
would be lying about what it stores. So `repair` hands the cleaned document back
into the editor for the curator to read and save themselves.

The simple Metadata form takes the opposite path on purpose. Someone who typed a
title is not looking at XML, and should get their title back without being asked
about codepoints.

Two offers share the action — control characters and double-escaped entities —
because they share every part of the answer but one line. The same buffer
arrives, the same stream reseats it, and neither writes anything. `kind` says
which was pressed, and an unrecognised value falls back to the control
characters rather than doing nothing the curator can see. See
`docs/metadata-text.md` for both repairs.

### Save validates

`update` re-runs the validation `validate` runs, and refuses on failure. Nothing
forces a curator through Validate first, and nothing should have to: the
destructive path is the one that must check. Atlas stores malformed MODS
truncated at the parse error, discarding every element after it. It raises no
error and records an ordinary-looking audit entry.

Both actions validate with `MODSRecordValidator`: the schema, a title, and the
keywords `DescriptivePolicy.keywords_required?` asks for on that type.

A valid save writes through `AtlasRb::Resource.put_mods` with `origin:
'xml_editor'`, then redirects to the resource's show page.

A rejected save re-renders the editor holding the curator's own submission, with
a `422`. Reverting the textarea would throw away the work that prompted the
save. The preview pane shows the stored record's render, since there is nothing
valid to draw from the rejected text.

### The editor's trail

The editor's trail is the resource's edit-page trail: `breadcrumbs(id, editing:
true)`, handed the resource the editor already resolved. Content under a
personal root gets the same owner trail as its edit page.

## Sweeping and reindexing a Set

Three background jobs act on the Works a Set denotes. `docs/sets.md` covers who
may run a sweep, the `SetSweep` scaffolding they share, and how a partial run is
reported.

| Job | What it writes | Skips |
|---|---|---|
| `SetPrivatizeJob` | The Work's resource ACL: `public` removed from read | A Work that is already private, or whose permissions cannot be read (both counted as already private) |
| `SetSentinelApplyJob` | The Work's derivative-access policy, clamped per Work | A Work whose permissions cannot be read |
| `SetReindexJob` | Nothing in Atlas's store — Solr projections only | Nothing |

All three re-read the Set at run time rather than carrying its title, recipe or
policy through the queue. An edit made between the click and the run is the one
that takes effect. Each reports to the actor's inbox through
`CompletionNotice.deliver`, under its own `AdminNotice` kind.

The two sweeps retry `AtlasRb::StaleResourceError`, which Atlas surfaces only
once its own optimistic-lock retries are exhausted. Re-running is safe because
each sweep is idempotent. `SetReindexJob` retries `Faraday::TimeoutError`,
because atlas_rb sets no Faraday timeout on the system connection and a large
included collection can hold the thread. Its `TimeoutError` re-raise has to stay
above the `Faraday::Error` rescue, or `retry_on` never sees it.

### Privatize writes the resource ACL, not the derivative gate

`SetPrivatizeJob` is the v1 "make these Core Files private" sweep. It writes the
Work's own ACL, which is the outer gate. A Work's FileSets follow the Work — see
`NarrowingTargets` in `docs/narrowing.md`. And the download path authorizes
`:read` on the resource before it consults the per-asset stamp.

Privatizing the Work therefore closes its blobs too, and a derivative tier left
naming `public` underneath is inert rather than a hole.

Group grants are kept. They grant nothing extra while an item is public, and they
are what a later flip back to Private falls back to. That is the same reasoning
`PermissionsForm#mass_permissions` applies to a single resource.

### Applying a Set's Sentinel

`SetSentinelApplyJob` is the proactive sweep over content that already exists,
and it is the counterpart to the Collection Sentinel rather than a duplicate of
it. A Collection's Sentinel stamps *new* deposits at create and is deliberately
not retroactive, so nothing else fixes the renditions of Works already in place.
Authoring or editing a Collection Sentinel still triggers no sweep.

Each tier is clamped against the Work it is written to, with
`Permissions.audience_intersect`. Clamping is the honest reading of the policy
as well as a wire requirement. Atlas refuses a tier naming a group the Work does
not grant (`tier_exceeds_resource`), and on a private Work the only legal value
is the empty list. A tier can never widen a Work, only narrow it. A tier sharing nobody with its Work clamps to `[]`,
withheld from everyone. That is the right direction for a gate whose purpose is
to withhold.

A failure leaves a rendition *wider* than intended. So the report's lead names
what the operator still has to deal with rather than merely saying it failed.

The write is a whole-object replace, on purpose. Atlas reads an absent tier as
riding the Work's own visibility, which is what a Sentinel that does not name the
tier means.

`set_noid` is the Compilation's NOID, which is also the Sentinel's `target_id`.
With no Sentinel for the Set, the job does nothing.

### Reindexing drives the recipe, not the contents

`SetReindexJob` walks the Set's recipe rather than its resolved contents, and
that distinction is the point of the job.

`SetResolver` answers "what is in this Set" out of Solr. So a resource whose Solr
document is missing is invisible to it — precisely the resource most in need of a
reindex. Atlas's subtree walk reads the authoritative store instead, so
it has no such blind spot.

Driving the recipe also sidesteps the resolver's export row cap and its need for
a request-bound, gated search service. A job has no request.

The trade is deliberate over-reach: walking the recipe also reindexes the
included containers themselves, and any Work the Set has set aside. A reindex is
Solr-only and idempotent, so that costs time, not correctness.

A branch that fails is recorded and the walk continues. One unreachable branch
must not abandon the rest of the recipe. Failures are named rather than counted.
A branch that failed to reindex is still stale, and the operator has moved on by
the time the report arrives.

atlas_rb does not translate a 404 on the subtree path. The empty body surfaces as
a `JSON::ParserError`, so `failure_reason` reports it as "no resource found".

## One item of a multipage load

`MultipageItemJob` runs once per contract-valid item. `MultipageUnzipJob` has
already created the item's pending page rows, grouped by `item_index`, and
validated its structure locally. This job owns everything that touches the
network:

1. Validate the item's MODS with `MODSRecordValidator` — the XSD work plus
   the required title and keyword, isolated per item. Kataba caches the schema
   across items.
2. Mint the one Work the item becomes, with the idempotency key it was handed,
   so a retry never double-mints.
3. Apply the parent Collection's default Sentinel with `Sentinel.apply_default`.
4. Stamp `work_pid` onto the item's page rows.
5. Enqueue a `MultipageIngestJob` per page.

Isolating each item is the point. A transient Atlas failure retries a single
item, and a bad item fails only its own pages. Neither aborts the batch.

The job skips an item it has already processed. Page rows are created pending
with no `work_pid`, so a `work_pid` means a prior attempt minted and stamped,
and a failed row means a prior attempt rejected the item. When the
`Faraday::Error` retries run out, `fail_item_rows` fails only this item's open
rows and lets the report finalize.

`docs/ingest.md` covers what happens to each page after this job fans out.
