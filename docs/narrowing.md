# Narrowing visibility

How Cerberus decides whether someone may take audience away from a container,
what such a change would touch, in what order the cascade must write it, and how
it finds resources that are already more visible than their container.

Source files:

- `app/services/narrowing_policy.rb`
- `app/queries/narrowing_impact.rb`
- `app/queries/narrowing_targets.rb`
- `app/queries/container_descendants_query.rb`
- `app/models/sentinel.rb`
- `app/services/visibility_audit.rb`

The ACL vocabulary these files share with Atlas — `audience_subset?`,
`audience_intersect`, `narrowing?`, and the whole-envelope write rule — lives in
`docs/permissions.md`. The job that performs the cascade, `VisibilityCascadeJob`,
is documented in `docs/authorization.md`. The Solr `fq` fragments every query
here composes are `MembershipQuery`'s, documented in `docs/search.md`.

## Deciding whether a narrowing may run

`NarrowingPolicy` answers one question: may this actor narrow this container,
given what the narrowing would touch? It returns a `Decision` that is either
allowed or an escalation carrying a reason.

The rule is blast radius, and the two permitted cases are the tails of the curve.

| Case | Outcome | Why |
|---|---|---|
| The subtree is larger than `NarrowingImpact::CASCADE_LIMIT` | Escalate, `TOO_LARGE` | The run would probably not finish |
| The actor is an admin | Allowed | An admin is trusted with large consequences by definition |
| Every affected descendant belongs to the actor | Allowed | They risk only their own work, and gating it would put friction on ordinary daily work for no safety gain |
| Anything else | Escalate, `NOT_SOLE_DEPOSITOR` | Enough rights to cascade over thousands of objects belonging to many depositors, without the authority to own the fallout |

Group-ACL editors and the devolved-admin tier fall in that middle band and are
refused. That is the intended outcome rather than an oversight in the phrasing:
a staff curator holding edit on an institutional container that spans many
depositors cannot narrow it directly, and is routed to DRS staff instead.

Both escalation reasons route to the same "ask DRS staff" affordance, but they
say different things to the person who hit them, which is why they are separate
constants.

`Decision#affected` reports how many resources the change touches. The
confirmation copy quotes that number.

## Measuring what a narrowing would touch

`NarrowingImpact` takes the container's bare noid and its Solr `id` (a uuid) and
answers two aggregate questions: `count`, the affected descendants excluding the
container itself, and `depositors`, a NUID-to-count hash.

Both answers come from a single `rows: 0` facet query rather than from
materializing the subtree. Both questions are aggregate, and a Collection can
hold thousands of Works, so listing them here gains nothing. `NarrowingTargets`
enumerates them later, when there are writes to issue.

The filter is the subtree, restricted to `Work` and `Collection`, minus the
container itself. The container is excluded because the caller is narrowing that
one deliberately, so it is not part of "what else this touches".

`AFFECTED_TYPES` names only resources that carry a read ACL of their own.
Membership also returns a Work's FileSets, whose visibility follows the Work
rather than standing alone. Counting them would overstate the impact, and the
metadata FileSet carries no depositor at all.

Solr returns facet fields as a flat `[value, hits, value, hits, ...]` array,
which is what `facet_pairs` reshapes.

### The cascade cap

`CASCADE_LIMIT` is 10,000. Above it the cascade stops and asks for staff instead
of running.

The cascade issues one PATCH per affected resource, so a subtree that size makes
a job long enough that a half-finished run is the likely outcome — and a partial
narrowing is the leak this feature exists to close. Routing it to the escalation
path reuses an affordance that already has to exist for the ownership rule.

### The ownership test

`wholly_owned_by?(nuid)` asks whether every affected descendant belongs to one
depositor. It compares the facet total against the match count, and does not
merely inspect the facet keys.

That comparison is what catches an unattributed resource. A resource with no
depositor is indexed without the field, so it never appears in the facet at all.
Reading only the keys would let it slide through as "all mine".

A zero count is wholly owned; a blank NUID never is.

## Ordering the cascade's writes

`NarrowingTargets` yields the resources a cascade must rewrite, deepest
descendants first, with the container itself last. It is `Enumerable`, and each
`Target` carries a noid, the Solr class name, and a depth; `Target#atlas_class`
resolves the atlas_rb class that owns that noid's metadata endpoint.

The order is a correctness requirement rather than a preference. Narrowing a
descendant is always legal — a narrower child is trivially within its still-broad
parent's audience — so Atlas's containment rule never fires mid-cascade and the
invariant holds at every intermediate step. An interrupted run leaves a subtree
that is over-narrowed and incomplete, never one that is leaking.

Top-down inverts that. Narrowing the container first opens a window in which
every descendant exceeds it, and a crash leaves it that way.

The container needs no special case. It is the ancestor of everything else in the
set, so it necessarily has the shallowest depth and sorts last on its own.

### Where depth comes from

Depth comes free from the index. `ancestor_ids_ssim` carries the full chain, so
its length is how deep a container sits.

Works carry no ancestry at all. The field is denormalized onto containers only,
and deliberately: Works are the bulk of the graph and have no descendants. That
is also why a Work can be treated as the deepest rank without computing
anything, which `LEAF_DEPTH = Float::INFINITY` expresses. Works are leaves, so no
container can sit below one, and giving them a finite depth would only invite an
off-by-one against the deepest collection.

### Why one unbounded query is safe here

`documents` fetches the whole subtree in one query at `ContainerDescendantsQuery::MAX_ROWS`.
The caller bounds it: `NarrowingPolicy` refuses a cascade above
`NarrowingImpact::CASCADE_LIMIT`, which sits well under that row ceiling. The cap
therefore cannot silently truncate a set that actually reaches a job.

`NarrowingTargets` restricts to the same types as `NarrowingImpact`, for the same
reason.

## Resolving a subtree

`ContainerDescendantsQuery` resolves a container's full structural-home
descendant set — itself, every descendant Collection and Community, and every
Work homed in any of them. It was built for the impressions container rollup
(`RollupContainerImpressionsJob`) and is now the shared subtree primitive.

| Method | Returns |
|---|---|
| `noids` | the container's own noid plus every descendant noid, containers and Works alike |
| `container_noids` | the container's own noid plus every descendant Collection and Community noid |
| `work_noids` | every Work noid structurally homed under this container or any descendant container |
| `container_uuids` | this container's uuid plus every descendant container's uuid — the Solr `id` values behind `subtree_fq` |
| `subtree_fq` | one Solr `fq` matching the container, every descendant container, and every Work homed anywhere in the subtree |

It takes the container's bare noid (the rollup key) and its Solr `id` (a uuid,
for member resolution). It reuses `MembershipQuery`'s `fq` fragments, the same
recipe as `CatalogController#find_children`.

`subtree_fq` exists so a caller can constrain an arbitrary search or facet to
"within this section of the tree" without materializing the full member list the
way `noids` does. `NarrowingImpact`, `NarrowingTargets`, and the
Collection/Community edit page's Analytics tab all use it.

`descendant_containers` and `work_noids` are memoized, so
`container_noids`, `work_noids` and `noids` share one Solr round-trip for the
descendant-container lookup however many of them a caller uses. `ImpressionScope`
calls all three on the same instance for different report metrics.

### Two rules this class does not bend

It queries Solr directly, with no SearchBuilder and no gated discovery. Its
callers are system analytics and visibility repair, both of which must count
every resource regardless of who is asking.

It follows structural home only, passing `include_linked: false`. A Work's
impressions accrue to its canonical-home subtree, never to a Collection it is
merely linked into. The linked-member overlay is discovery-only and never changes
attribution.

`MAX_ROWS` is 100,000. That is a ceiling, not a page size, so a caller that could
exceed it needs its own bound — see `NarrowingTargets` above, and the paging in
`VisibilityAudit` below.

## Narrowing across the derivative tiers

`Sentinel` is a per-tier derivative-permission policy bound by noid to a
Collection or a Compilation (Set). Its `policy` maps each gated tier to the read
groups that may fetch it, and `apply_to` pushes it to Atlas's per-tier gate.

Both uses are Cerberus orchestration. A Collection's Sentinel is the default
applied to Works created under it, via `apply_default`, which is a no-op when the
Collection has no Sentinel so every create path can call it unconditionally; it
acts as the ambient `Current` principal, the depositor or loader user, which
holds edit rights on the fresh Work. A Set's Sentinel is bulk-applied across the
Set's Works — see `docs/sets.md`.

`tier_policy` slices the policy down to known tiers, so stray keys never reach
the API call.

### The tiers

`IMAGE_LADDER` is `small`, `medium`, `large`, `service`, `master` — lowest
resolution and widest audience first, full-res source and narrowest last.

`INDEPENDENT` is `audio`, `video`, `pdf`. Non-image renditions gate
independently: there is no meaningful resolution ordering between an audio file
and a PDF, so no monotonicity ties them to each other or to the ladder.

`TIERS` is the two together, and is every gateable tier. `master` and the
independent media reach non-image or original binaries, which Atlas maps onto the
matching assets. Thumbnails are never gateable — they are the open display pipe,
public by construction.

### The three validations

`policy_well_formed` requires a Hash whose every present tier is a known tier
mapping to an Array of read-group strings.

`policy_monotonic` requires visibility to narrow as image resolution grows: each
rung's audience must be a subset of the next-lower-resolution rung's, so
`master ⊆ service ⊆ large ⊆ medium ⊆ small`. A permissive higher-res tier would
void a stricter lower one, and the enforcement side's coarse zoom cookie relies
on this ordering. Only the image ladder is checked; the independent media are
not.

`policy_within_resource` requires each present tier's audience to be a subset of
the container's read groups: a tier cannot be more visible than the container it
defaults for. This keeps the authored default coherent. Atlas still enforces
tier ⊆ the actual Work at apply time.

That last check reads `resource_read_groups`, which the authoring controller
sets. It is nil on the create path and on bulk-apply, and the check is skipped
when it is. `VisibilityCascadeJob#clamp_sentinel` keeps the same rule true when a
container narrows underneath a default that was coherent when written — see
`docs/authorization.md`.

`audience_subset?` here treats `public` as the universal audience, matching
`Permissions.audience_subset?`.

## Auditing what is already too visible

`VisibilityAudit` finds resources that are more visible than the container they
sit in, and returns `Violation` structs sorted worst first: public leaks, then
the rest.

The write paths keep this invariant going forward — Atlas refuses a child that
exceeds its parent, and narrowing a Collection cascades — but neither is
retroactive, and narrowing a Community never cascades by design. This audit is
the only thing that surfaces violations that already exist, or that arrive by a
route the guards do not cover.

It reports rather than repairs. Whether a violation should be fixed by narrowing
the child or widening the container is a curation decision that depends on what
the material is, so automating it would be guessing.

It queries Solr directly and ungated. An audit has to see everything, including
the resources the auditor could not otherwise discover.

### Pairs, not ancestry

The audit checks each parent/child pair rather than walking full ancestry. The
two are equivalent — if every pair holds, the chain holds — and pairwise costs
two scans instead of a traversal per resource.

The first scan loads every Collection and Community into a uuid-keyed hash of
noid, title, class, read audience and parent. That is small enough to hold:
containers number in the thousands, where Works number in the hundreds of
thousands. The second scan streams the Works and looks each one's parent up in
that hash.

### What is skipped

A root Community has no parent and is unconstrained, so it produces no violation.

Personal roots are skipped, and not as a convenience. Atlas mints them public on
purpose: the People community they sit in has no public read, so a root that
merely inherited it would 403 its own owner out of their workspace — see
`PersonalRootCreator`. Every user therefore produces one expected violation, and
left in they would bury the real findings under one line per account.

### Paging

`each_batch` pages with an offset at `BATCH = 500` rather than fetching once. The
Work scan is the whole repository, and the 100,000 row caps used elsewhere would
silently truncate an audit into a false all-clear.
