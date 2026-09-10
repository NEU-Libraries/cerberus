# People, routing and trails

The People discovery surfaces, the breadcrumb trails every controller builds,
and the redirect that catches a DRS v1 URL. Plus the raw-XML editor, and the
background jobs that sweep or reindex a Set's Works.

Source files:

- `app/controllers/people_controller.rb`
- `app/controllers/legacy_controller.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/concerns/collection_breadcrumbs.rb`
- `app/controllers/xml_controller.rb`
- `app/jobs/set_sentinel_apply_job.rb`
- `app/jobs/set_privatize_job.rb`
- `app/jobs/set_reindex_job.rb`
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
`search_service` comes from.

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

The method is idempotent. A user-supplied `type_ssim` is left alone, though only
Person docs ever match this surface.

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

### Degrading when a lookup fails

`find_community` returns nil for an unknown or malformed NOID. The affiliation
filter then matches nothing, so the browse renders empty instead of raising.

## Breadcrumb trails

`ApplicationController` holds the builders. `breadcrumbs(id, editing:, match:,
result:)` fetches the resource once and walks its ancestors. `ancestors` carries
each ancestor's title alongside its NOID and class, so the whole trail comes out
of that single find with no per-ancestor round trip.

`result:` lets a caller that already fetched the resource — to branch on its
ancestry, say — hand it in and avoid a second `AtlasRb::Resource.find`.

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

Both degrade. A person with no affiliation, or a stale affiliation NOID, gets
the flat People trail rather than an error page. The `AtlasRb::Resource.find`
inside `breadcrumbs` runs before any crumb is added, so a failure leaves the
trail empty and the rescue can rebuild it from nothing.

### A Collection in a personal workspace

`CollectionBreadcrumbs` builds the Collection trail. A collection under a
Person's personal root is trailed away from the structural "People / Personal
Root" prefix:

| Viewer | Trail |
|---|---|
| The owner | My DRS / *collection* — their personal home |
| Everyone else, including logged out | People / *Person* / *collection* |
| Any other collection | The plain structural trail |

The concern lives outside `CollectionsController` so the XML editor can build the
same trail. Clicking the XML tab from an edit page has to keep the personal-root
prefix rather than falling back to the structural one.

`editing:` swaps the show tail — the collection as the you-are-here crumb — for
the edit tail. That tail is the collection as a link plus an "Edit Collection"
current crumb.
That keeps an edit or XML page on the same prefix as the show page.

`personal_root_owner` resolves the owning Person from the personal root's
`depositor_ssi`. A lookup failure returns nil, and the trail falls back to the
structural one. `collection_doc` reads the root's Solr document, which carries
`personal_root_bsi` and `depositor_ssi`.

The concern leans on `ApplicationController`'s `#breadcrumbs`, `#breadcrumb`,
`#add_breadcrumb_for` and `#edit_breadcrumb_tail`, and on `DepositorContext`'s
`#deposit_person`.

## Request-wide setup

`ApplicationController` sets three pieces of per-request state.

`set_current_nuid` sets `Current.nuid` to the signed-in user's NUID, or to the
configured guest NUID. It also sets `Current.account_email` from the session,
which `AccountsController` writes when someone switches account.

`current_ability` builds the Ability from `effective_user`, which
`ImpersonationSession` supplies and which is `current_user` when nobody is
impersonating. Under view-as, the page therefore renders the target's access
decisions. Acting-as leaves this as the real administrator: only writes are
re-attributed.

`attributed_nuid` is the identity Cerberus-side writes are attributed to. It
matches the deposit convention — acting-as work belongs wholly to the target, so
the target's inbox gets the follow-ups, not the administrator's.

`MaintenanceGate` is included after `set_current_nuid` rather than with the other
concerns, because its `before_action` must run second. See `docs/maintenance.md`
for what the gate does.

## Redirecting a DRS v1 URL

`LegacyController` sends an inbound `neu:` pid URL to the v2 object it became at
migration.

v1 ran on Fedora, so every object carried a `neu:` pid. v2 mints fresh NOIDs and
does not carry the pid forward. Ten years of `neu:` pid URLs live in published
papers, syllabi, finding aids, catalogue records and the search index. Without
this controller they all land on a 404.

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

### The redirect status

`REDIRECT_STATUS` is `:found`, a 302, while the mapping table is unverified. A
301 is the intended end state, because it transfers search-index equity to the
new URLs. Flip the constant to `:moved_permanently` once the migration's mappings
are confirmed.

## The raw-XML editor

`XmlController` is the raw-XML sub-tab of a resource's edit page. It has four
actions: `editor`, `validate`, `repair` and `update`.

It gates like its sibling Metadata and Permissions tabs: authenticate, then
check the `:edit` ability on the resource, mirroring the resource controllers'
`authorize_edit!`. `authorize_xml_edit!` reads whichever id param the action
carries, because `editor` carries `params[:id]` and `validate`, `repair` and
`update` carry `params[:resource_id]`.

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
destructive path is the one that must check.

A rejected save re-renders the editor holding the curator's own submission, with
a `422`. The preview pane keeps the last good render, since there is nothing
valid to draw from the rejected text.

### The editor's trail

`editor_breadcrumbs` mirrors the resource's edit page. A Collection reuses the
personal-root-aware trail from `CollectionBreadcrumbs`; a Work uses the
structural edit trail. That matches `CollectionsController#edit` and
`WorksController#edit` respectively.

## Sweeping and reindexing a Set

Three background jobs act on the Works a Set denotes. `docs/sets.md` covers who
may run a sweep, the `SetSweep` scaffolding they share, and how a partial run is
reported.

| Job | What it writes | Skips |
|---|---|---|
| `SetPrivatizeJob` | The Work's resource ACL: `public` removed from read | A Work that is already private |
| `SetSentinelApplyJob` | The Work's derivative-access policy, clamped per Work | A Work whose permissions cannot be read |
| `SetReindexJob` | Nothing in Atlas's store — Solr projections only | Nothing |

All three re-read the Set at run time rather than carrying its title, recipe or
policy through the queue. An edit made between the click and the run is the one
that takes effect.

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

Each tier is clamped against the Work it is written to. Clamping is the honest
reading of the policy as well as a wire requirement: a tier can never widen a
Work, only narrow it. A tier sharing nobody with its Work clamps to `[]`,
withheld from everyone. That is the right direction for a gate whose purpose is
to withhold.

A failure leaves a rendition *wider* than intended. So the report's lead names
what the operator still has to deal with rather than merely saying it failed.

`set_noid` is the Compilation's NOID, which is also the Sentinel's `target_id`.

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

## One item of a multipage load

`MultipageItemJob` runs once per contract-valid item. `MultipageUnzipJob` has
already created the item's pending page rows, grouped by `item_index`, and
validated its structure locally. This job owns everything that touches the
network:

1. Validate the item's MODS with `XmlValidator` — the XSD work, isolated per
   item. Kataba caches the schema across items.
2. Mint the one Work the item becomes.
3. Stamp `work_pid` onto the item's page rows.
4. Enqueue a `MultipageIngestJob` per page.

Isolating each item is the point. A transient Atlas failure retries a single
item, and a bad item fails only its own pages. Neither aborts the batch.

`docs/ingest.md` covers what happens to each page after this job fans out.
