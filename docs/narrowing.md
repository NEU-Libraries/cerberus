# Narrowing visibility

This page covers how Cerberus decides whether someone may take audience away
from a container, and what that change would touch. It also covers the order in
which the cascade must write, and how Cerberus finds resources that are already
more visible than their container.

Source files:

- `app/services/narrowing_policy.rb`
- `app/queries/narrowing_impact.rb`
- `app/queries/narrowing_targets.rb`
- `app/queries/container_descendants_query.rb`
- `app/models/sentinel.rb`
- `app/services/visibility_audit.rb`

The ACL vocabulary these files share with Atlas — `audience_subset?`,
`audience_intersect`, `narrowing?`, and the rule that an ACL write sends only
the keys it changes — is in `docs/permissions.md`. The job that performs the cascade,
`VisibilityCascadeJob`, is in `docs/authorization.md`. The Solr `fq` fragments
every query here composes are `MembershipQuery`'s, documented in
`docs/search.md`.

Only a Collection narrowing cascades. `ResourcePermissions` never defers a
Work, and refuses a Community narrowing to anyone but an admin, without a
cascade.

## Deciding whether a narrowing may run

`NarrowingPolicy` answers one question: may this actor narrow this container,
given what the narrowing would touch? It returns a `Decision` that is either
allowed or an escalation carrying a reason.

The rule is blast radius. The two permitted cases are the two ends of the
curve. The checks run in this order:

| Case | Outcome | Why |
|---|---|---|
| The subtree is larger than `NarrowingImpact::CASCADE_LIMIT` | Escalate, `TOO_LARGE` | The run would probably not finish |
| The actor is an admin | Allowed | An admin is trusted with large consequences by definition |
| Every affected descendant belongs to the actor | Allowed | They risk only their own work. Gating it would add friction to ordinary daily work for no safety gain |
| Anything else | Escalate, `NOT_SOLE_DEPOSITOR` | The actor has enough rights to cascade over thousands of objects from many depositors, but not the authority to own the fallout |

The size check sits above the admin check on purpose. It is not a question of
authority but of whether the cascade can finish. An admin let through buys a
half-narrowed subtree, which leaks like an un-narrowed one.

Group-ACL editors and the devolved-admin tier fall in the middle band and are
refused. That is the intended outcome, not an oversight in the wording. A staff
curator holding edit on an institutional container that spans many depositors
cannot narrow it directly, and is routed to DRS staff instead.

Both escalation reasons lead to the same "ask DRS staff" route, but
`NarrowingRequest` tells the person something different for each. That is why
they are separate constants.

`Decision#affected` reports how many resources the change touches.
`NarrowingRequest` quotes it in the message shown once the cascade is
dispatched. It is named `affected`, not `count`, because a Struct member named
`count` would shadow `Struct#count`.

## Measuring what a narrowing would touch

`NarrowingImpact` takes the container's bare noid and its Solr `id` (a uuid). It
answers two aggregate questions: `count`, the affected descendants excluding
the container itself, and `depositors`, a hash of NUID to count.

Both answers come from a single `rows: 0` facet query rather than from listing
the subtree. Both questions are aggregate, and a Collection can hold thousands
of Works, so listing them here gains nothing. `NarrowingTargets` lists them
later, when there are writes to issue.

`NarrowingImpact` queries Solr directly, never through gated discovery. A
cascade has to see every descendant, whether or not the actor could discover
it. Otherwise it would skip exactly the resources that are leaking.

The filter is the subtree, restricted to `Work` and `Collection`, minus the
container itself. The container is excluded because the caller is narrowing it
deliberately, so it is not part of "what else this touches".

`AFFECTED_TYPES` names only resources that carry a read ACL of their own.
Membership also returns a Work's FileSets, whose visibility follows the Work
rather than standing alone. Counting them would overstate the impact. It would
also break the ownership test, because the metadata FileSet carries no
depositor.

Solr returns facet fields as a flat `[value, hits, value, hits, ...]` array.
`facet_pairs` reshapes it into a hash.

### The cascade cap

`CASCADE_LIMIT` is 10,000. Above it (`over_cap?`), the cascade stops and asks
for staff instead of running.

The cascade issues one PATCH per affected resource. A subtree that size makes a
job long enough that a half-finished run is the likely outcome, and a partial
narrowing is the leak this feature exists to close. Raising the limit buys that
half-finished run. Routing a large subtree to the escalation path reuses a route
that the ownership rule needs anyway.

### The ownership test

`wholly_owned_by?(nuid)` asks whether every affected descendant belongs to one
depositor. It checks that the facet holds only that NUID *and* that the facet
total equals the match count. Inspecting the facet keys alone is not enough.

The count comparison is what catches an unattributed resource. A resource with
no depositor is indexed without `depositor_ssi`, so it never appears in the
facet. Reading only the keys would let it through as "all mine".

A blank NUID is never wholly owned, even over an empty subtree. Otherwise, a
zero count is wholly owned.

## Ordering the cascade's writes

`NarrowingTargets` yields the resources a cascade must rewrite, deepest
descendants first, with the container itself last. It is `Enumerable`. Each
`Target` carries a noid, a `klass` and a depth.

`klass` is the Solr type name, used as a label. It names the type in a failure
message. Nothing resolves it to an atlas\_rb class, because every write in the
cascade goes through the generic endpoint.

The order is a correctness requirement, not a preference. Narrowing a
descendant is always legal: a narrower child is within its still-broad parent's
audience. So Atlas's containment rule never fires mid-cascade, and the
invariant holds at every step. An interrupted run leaves a subtree that is
over-narrowed and incomplete, never one that is leaking.

Top-down inverts that. Narrowing the container first opens a window in which
every descendant exceeds it, and a crash leaves it that way.

The container needs no special case. It is the ancestor of everything else in
the set, so it has the shallowest depth and sorts last on its own.

### Where depth comes from

Depth comes free from the index. `ancestor_ids_ssim` carries a container's full
ancestor chain, so its length is how deep the container sits.

Works carry no ancestry. The field is denormalized onto containers only, and
deliberately: Works are the bulk of the graph and have no descendants. That is
also why a Work can take the deepest rank without computing anything, which
`LEAF_DEPTH = Float::INFINITY` expresses. No container can sit below a Work, and
a finite depth would only invite an off-by-one against the deepest collection.

### Why one unbounded query is safe here

`documents` fetches the whole subtree in one query, at
`ContainerDescendantsQuery::MAX_ROWS`. The caller bounds it: `NarrowingPolicy`
refuses a cascade above `NarrowingImpact::CASCADE_LIMIT`, well under that row
ceiling. So the ceiling cannot silently truncate a set that reaches a job.

`NarrowingTargets` restricts to the same `AFFECTED_TYPES` as `NarrowingImpact`,
for the same reason. It also queries Solr directly, ungated.

## Resolving a subtree

`ContainerDescendantsQuery` resolves a container's full structural-home
descendant set: itself, every descendant Collection and Community, and every
Work homed in any of them. The impressions container rollup
(`RollupContainerImpressionsJob`) uses it, and so does every other caller that
needs a subtree.

| Method | Returns |
|---|---|
| `noids` | The container's own noid plus every descendant noid, containers and Works alike |
| `container_noids` | The container's own noid plus every descendant Collection and Community noid |
| `work_noids` | Every Work noid structurally homed under this container or any descendant container |
| `container_uuids` | This container's uuid plus every descendant container's uuid — the Solr `id` values behind `subtree_fq` |
| `subtree_fq` | One Solr `fq` matching the container, every descendant container, and every Work homed anywhere in the subtree |

It takes the container's bare noid (the rollup key) and its Solr `id` (a uuid,
for member resolution). It reuses `MembershipQuery`'s `fq` fragments, the same
recipe as `CatalogController#find_children`.

`subtree_fq` lets a caller constrain any search or facet to "within this part of
the tree", without listing every member the way `noids` does. Its callers are
`NarrowingImpact`, `NarrowingTargets`, the Collection and Community Analytics
tab (`ContainerAnalytics`) and `Admin::ImpressionsController`.

`descendant_containers` and `work_noids` are memoized. So `container_noids`,
`work_noids` and `noids` share one Solr round-trip for the descendant-container
lookup, however many of them a caller uses. `ImpressionScope` calls all three on
the same instance for different report metrics.

### Two rules this class does not bend

It queries Solr directly, with no SearchBuilder and no gated discovery. Its
callers are system analytics and visibility repair, and both must count every
resource regardless of who is asking.

It follows structural home only, passing `include_linked: false`. A Work's
impressions accrue to its canonical-home subtree, never to a Collection it is
merely linked into. The linked-member overlay is for discovery only and never
changes attribution.

`MAX_ROWS` is 100,000. That is a ceiling, not a page size, so a caller that
could exceed it needs its own bound. See `NarrowingTargets` above, and the
paging in `VisibilityAudit` below.

## Narrowing across the derivative tiers

`Sentinel` is a per-tier derivative-permission policy, bound by noid
(`target_id`) to a Collection or a Compilation (Set). Its `policy` maps each
gated tier to the read groups that may fetch it. `apply_to` pushes it to Atlas's
per-tier gate through `AtlasRb::Work.set_derivative_permissions`.

Both uses are Cerberus orchestration. A Collection's Sentinel is the default
applied to Works created under it, through `Sentinel.apply_default`. The deposit,
XML, IPTC and multipage ingest paths all call it. It does nothing when the
Collection has no Sentinel, so every create path can call it unconditionally.
It passes no `nuid:`, so the write runs as the ambient `Current` principal: the
depositor or loader user, who holds edit rights on the fresh Work. A Set's
Sentinel is applied in bulk across the Set's Works — see `docs/sets.md`.

`tier_policy` slices the policy down to known tiers, so stray keys never reach
the API call.

### The tiers

`IMAGE_LADDER` is `small`, `medium`, `large`, `service`, `original`: lowest
resolution and widest audience first, full-resolution source and narrowest last.
The monotonicity check follows this order, so reordering the array changes what
the validation means.

`INDEPENDENT` is `audio`, `video`, `pdf`. Non-image renditions are gated
independently. There is no meaningful resolution order between an audio file
and a PDF, so no monotonicity ties them to each other or to the ladder.

`TIERS` is the two together, and is every gateable tier. `original` and the
independent media reach non-image or original binaries, which Atlas maps onto
the matching assets. Thumbnails are never gateable: they are the open display
pipe, public by construction.

### The three validations

`policy_well_formed` requires a Hash in which every present tier is a known tier
mapping to an Array. It does not check the Array's elements.

`policy_monotonic` requires visibility to narrow as image resolution grows.
Each present rung's audience must be a subset of the next-lower-resolution
present rung's, so `original ⊆ service ⊆ large ⊆ medium ⊆ small`. A permissive
higher-resolution tier would void a stricter lower one, and the enforcement
side's coarse zoom cookie relies on this order. Only the image ladder is
checked; the independent media are not.

`policy_within_resource` requires each present tier's audience to be a subset of
the container's read groups. A tier cannot be more visible than the container
it is the default for. This keeps the authored default coherent. Atlas still
enforces "tier ⊆ the actual Work" at apply time.

That last check reads `resource_read_groups`, and skips itself when it is nil.
Only `CollectionsController#sentinel` sets it. The Set tab
(`SetBulkActions#sentinel`) leaves it nil on purpose, because a Set's ACL does
not govern its Works. Leaving it unset anywhere else silently drops the
ceiling.

When a container narrows underneath a default that was coherent when written,
`VisibilityCascadeJob#clamp_sentinel` keeps the same rule true. See
`docs/authorization.md`.

The private `audience_subset?` treats `public` as the universal audience,
matching `Permissions.audience_subset?`.

## Auditing what is already too visible

`VisibilityAudit` finds resources that are more visible than the container they
sit in. It returns `Violation` structs sorted worst first: public leaks, then
the rest.

The write paths keep this invariant going forward. Atlas refuses a child that
exceeds its parent, and narrowing a Collection cascades. But neither is
retroactive, and narrowing a Community never cascades, by design. This audit is
the only thing that surfaces violations that already exist, or that arrive by a
route the guards do not cover.

It reports rather than repairs. Whether to fix a violation by narrowing the
child or widening the container is a curation decision. It depends on what the
material is, so automating it would be guessing.

It queries Solr directly and ungated. An audit has to see everything, including
the resources the auditor could not otherwise discover.

### Pairs, not ancestry

The audit checks each parent/child pair rather than walking full ancestry. The
two are equivalent — if every pair holds, the chain holds — and checking pairs
costs two scans instead of a traversal per resource.

The first scan loads every Collection and Community into a uuid-keyed hash of
noid, title, class, read audience and parent. That is small enough to hold:
containers number in the thousands, where Works number in the hundreds of
thousands. The second scan streams the Works and looks up each one's parent in
that hash. `Permissions.audience_subset?` decides each pair.

### What is skipped

A container whose parent is not in the hash produces no violation. A root
Community has no parent, so it is unconstrained.

Personal roots (`personal_root_bsi`) are skipped, and not as a convenience.
Atlas mints them public on purpose (Atlas's `PersonalRootCreator`). The People
community they sit in has no public read, so a root that merely inherited it
would lock its own owner out of their workspace with a 403. Every user would
therefore produce one expected violation, burying the real findings under one
line per account.

### Paging

`each_batch` pages with an offset at `BATCH = 500` rather than fetching once.
The Work scan covers the whole repository, and the 100,000-row caps used
elsewhere would silently truncate an audit into a false all-clear.
