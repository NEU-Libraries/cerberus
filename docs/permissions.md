# Permissions

The ACL vocabulary Cerberus shares with Atlas, and the policy that decides
whether a submitted change may be written.

Source files:

- `app/lib/permissions.rb`
- `app/services/resource_permissions.rb`

## The groups

| Constant | What it gates |
|---|---|
| `STAFF_EDIT_GROUP` | Repository staff. Atlas adds it to the edit grants of every resource, so staff can edit everything. `PermissionsForm` hides it from the grant rows, because nobody can remove it. `User#can_bypass_embargo?` also reads it — see [`docs/identity.md`](identity.md) |
| `API_GROUP` | The My DRS "Programmatic access" section and `AtlasTokensController`. A member may mint a personal-access JWT and call the Atlas API directly. This is **Cerberus-side policy only**: Atlas does not check this group |
| `ADMIN_GROUP` | The group half of the devolved-admin tier, which needs the `privileged` role **and** this group — see `User#admin_delegate?`. It matches the constant in Atlas's `Permissions` concern, so both sides gate on the same identifier |

### `UNOWNED_NUID` is the anonymous NUID on purpose

`UNOWNED_NUID` (`000000099`) is the depositor on containers nobody personally
owns. Those are the institutional hierarchy that `rake reset:data` seeds, and the
per-community genre showcases that `ShowcaseProvisioner` creates. Access to them
runs through Grouper groups, as it did in v1.

The anonymous NUID is a deliberate choice. That principal never authenticates
and holds no ability, so naming it as depositor grants nothing to anyone.

Do not let these fall back to the acting user. A depositor can edit what they
own, so the fallback would give edit rights over the container to whoever
created it, or to whoever ran the seed.

## `GrantRow`, and why a row knows if it is revocable

`GrantRow` is one group grant as the permissions editor renders it, in
`shared/_group_permissions`.

`ability` holds the wire token Atlas expects, `read` or `edit`. The human label
("View" or "Manage") comes from `ability_label`. So a row round-trips through
the form with no label-to-token translation step.

`revocable` mirrors Atlas's grant-removal rule. Only a member of a group may
remove that group's grant. Admins and devolved admins are exempt. Atlas does not
refuse a non-member's removal: `PermissionsWriteGuard` silently merges the grant
back in. So the editor renders a row the acting user cannot revoke without the
controls that would attempt it. `PermissionsForm#revocable_grant?` sets the flag
— see [`docs/authorization.md`](authorization.md).

`SetSharing` builds `GrantRow`s too, and marks every one revocable. A Set's ACL
is written through `Compilation.update`, which skips Atlas's removal guard. Only
the Set's owner reaches that tab.

## Clamping audience

`audience_intersect(inner, outer)` returns the part of `inner`'s audience that
`outer` can also see. It clamps a resource so it is never more visible than its
container.

`public` is the universal set on either side. Under a public container nothing
is clamped. A public resource clamps to exactly the container's audience.

This mirrors Atlas's `TierVisibility.audience_intersect`, which does the same
job for derivative tiers. Cerberus needs its own copy because the cascade is
Cerberus workflow. **Atlas checks each write against the parent but does not
clamp**, so the caller must decide what the narrowed value is.
`VisibilityCascadeJob` and `SetSentinelApplyJob` both call it.

### The two related predicates

`audience_subset?(inner, outer)` asks whether everyone who can see `inner` can
also see `outer`. `public` is again universal.

It stays correct without resolving Grouper membership, by erring cautious. Two
different group names count as different audiences, even when their members
overlap.

`narrowing?(current:, submitted:)` asks whether a change takes audience away. It
tests "`current` is not a subset of `submitted`". That test makes a same-size
swap count as a narrowing. Replacing one group with another removes access for
the outgoing group. So descendants that only that group could reach must be
reconsidered.

## Writing an ACL: send only the keys that change

Atlas's permissions setter merges every key. A key the payload omits keeps its
stored value, and a key sent empty is cleared
(`permissions=` in Atlas's `app/models/concerns/permissions.rb`). So a Cerberus
write carries only the slots it means to change.

`VisibilityCascadeJob` relies on this. It writes a descendant with
`{ 'read' => clamped }` alone, and the descendant keeps its edit grants and
embargo.

Two consequences follow:

- To clear a slot, send it explicitly empty. Omitting it changes nothing.
- Atlas prepends `Permissions::STAFF_EDIT_GROUP` to every `edit` it writes, so
  staff keep edit rights whatever the payload says.

`depositor` and `proxy_uploader` are attribution, not grants. No Cerberus
permissions form sends them.

## The write, and whether it may happen

`ResourcePermissions` is the half of the permissions story that can fail.

The split is deliberate. `PermissionsForm` decides what the submitted envelope
*is*, by reading params. `ResourcePermissions` decides whether Atlas may be told
about it, by reading the resource's current audience and the actor's role. So
the controller holds neither. `Transformable` hands over an envelope and flashes
whatever comes back.

A submitted ACL has one of three outcomes:

1. **It is written.** `Result.silent` carries a nil level, meaning there is
   nothing to report. This is the ordinary case, and why `Transformable#report`
   is one line.
2. **It is deferred** to `VisibilityCascadeJob`, because taking audience away
   from a Collection must reach everything inside it.
3. **It is refused.** `Result.refused` carries an `:alert` level and the message.

### Refusals

`PERMISSIONS_REFUSED` phrases Atlas's ACL invariants for a depositor. It is
keyed on the `code` of the `AtlasRb::PermissionsError`. An unknown code falls
back to Atlas's own message, so a new invariant still says something true.

`ResourcePermissions` *reports* a refusal rather than raising it. `apply!` runs
**before** the descriptive save in the same submit. Raising would discard title
and abstract edits that are valid and unrelated to the ACL.

### A past embargo date

`guarded_write` drops an embargo date that is not in the future and writes the
rest of the payload. The submit's group and visibility changes still land, and
the result carries `PAST_EMBARGO_REFUSED`.

An unchanged stored date is exempt. The form re-submits a lapsed embargo that
nobody touched, so `current_embargo:` lets that save pass.

### Who defers, and who does not

| Resource | Behaviour on a narrowing |
|---|---|
| Work | Never defers — nothing beneath it to strip |
| Collection | `NarrowingRequest` decides. It either enqueues `VisibilityCascadeJob` (a `:notice`) or refuses (an `:alert`), per `NarrowingPolicy` — see [`docs/narrowing.md`](narrowing.md) |
| Community | Never cascades. Narrowing one changes that object alone, and deliberately leaves its collections as visible as they were |

A Community has no cascade, so restricting one would leave every collection
inside it more visible than its container. The edit form offers Private to
administrators only, and routes everyone else to an administrator.
`community_narrowing_refusal` is the server-side backstop. It writes an
administrator's narrowing the ordinary way. Anyone else who reaches a narrowing
here has JavaScript off or is crafting a request, so it refuses with
`COMMUNITY_NARROWING_REFUSED`. Widening is unconstrained.

### Creating is not editing

`apply_minted!` writes the ACL for a resource that was just minted. It is
deliberately not `apply!`, because two of that method's assumptions are false
one line after a create:

- There is no cascade to run — nothing is inside a resource this new.
- `current_read` still describes the **destination**, not this resource. So the
  narrowing check would compare against the wrong audience.

It sends the submitted grants alone. The new child already carries the ACL Atlas
copied from its parent, and Atlas keeps every key the payload omits. So reading
the envelope back to merge onto would only re-send what is already there.
`depositor` and `proxy_uploader` are never sent, so the write cannot re-assert
attribution this form has no business touching.
