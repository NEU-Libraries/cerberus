# Permissions

The ACL vocabulary Cerberus shares with Atlas, and the policy that decides
whether a submitted change may be written.

Source files:

- `app/lib/permissions.rb`
- `app/services/resource_permissions.rb`

## The groups

| Constant | What it gates |
|---|---|
| `API_GROUP` | The My DRS "Programmatic access" section. Membership means a user may mint a personal-access JWT and drive the Atlas API directly. This is **Cerberus-side policy only** — Atlas does not check this group |
| `ADMIN_GROUP` | The group half of the devolved-admin tier's `:privileged` role and group pair — see `User#admin_delegate?`. It mirrors the matching constant in Atlas's own Permissions concern, so both sides gate on the same identifier |

### `UNOWNED_NUID` is the anonymous NUID on purpose

`UNOWNED_NUID` stamps the depositor field on containers nobody personally owns:
the institutional hierarchy, and the per-community genre showcases. Reachability
there runs through Grouper, as it did in v1.

The specific choice of the anonymous NUID is load-bearing. That principal never
authenticates and carries no ability, so recording it as depositor grants
nothing to anyone.

Letting these fall through to the acting user instead would breach the
depositor-implies-edit rule. It would quietly hand edit rights over the
container to whoever created it, or to whoever ran the seed.

## `GrantRow`, and why a row knows if it is revocable

`GrantRow` is one group grant as the permissions editor renders it, in
`shared/_group_permissions`.

`ability` holds the wire token Atlas expects, `read` or `edit`, rather than the
human label. A row therefore round-trips through the form with no label-to-token
translation step.

`revocable` mirrors Atlas's grant-removal rule: a group grant may be withdrawn
only by a member of that group, operators excepted. Atlas does not refuse a
non-member's attempted removal — it merges the grant back in. A row the acting
user cannot revoke is therefore rendered without the controls that would
silently attempt it.

## Clamping audience

`audience_intersect(inner, outer)` returns the portion of `inner`'s audience
that is also visible under `outer`. It clamps a resource so it can never be more
visible than its container.

`public` is the universal set on either side. Under a public container nothing
needs clamping, and a public resource clamps to exactly the container's
audience.

This mirrors Atlas's `TierVisibility.audience_intersect`, which does the same
job on the derivative-tier axis. It is expressed here as well because the
cascade is Cerberus workflow. **Atlas validates each write against the parent
but does not clamp**, so the caller has to decide what the narrowed value should
be.

### The two related predicates

`audience_subset?(inner, outer)` asks whether everyone who can see `inner` can
also see `outer`, with `public` again universal.

It is conservative-correct without resolving Grouper membership: two different
group names count as different audiences even when their memberships happen to
overlap.

`narrowing?(current:, submitted:)` asks whether a change takes audience away. It
is phrased as "current is no longer contained by what was submitted". That
phrasing is what makes a same-size swap count as a narrowing. Replacing one
group with another removes access for the outgoing group, so descendants that
were reachable only through it have to be reconsidered.

## Writing an ACL: it must be the whole envelope

`envelope_with_read(current, read)` returns a resource's whole ACL envelope with
only `read` replaced.

It has to be the whole envelope. Atlas's permissions setter assigns
`edit_groups`, `edit_users` and the embargo **unconditionally** from the
incoming hash. A payload carrying `read` alone therefore collapses `edit_groups`
to the staff auto-prepend and blanks the embargo release date.

`depositor` and `proxy_uploader` are the exception, and are deliberately
omitted. Those are write-once, and the setter only touches them when the key is
present.

## The write, and whether it may happen

`ResourcePermissions` is the half of the permissions story that can fail.

The division of labour is deliberate. `PermissionsForm` decides what the
submitted envelope *is*, reading params. `ResourcePermissions` decides whether
Atlas may be told about it, reading the resource's current audience and the
actor's role. Keeping them apart means the controller holds neither: it hands
over an envelope and reports whatever comes back.

Three things can happen to a submitted ACL:

1. **It is written.** `Result` carries a nil level, meaning there is nothing to
   report. This is the ordinary case, and the reason the controller side is two
   lines.
2. **It is deferred** to `VisibilityCascadeJob`, because taking audience away
   from a Collection has to reach everything inside it.
3. **It is refused.**

### Refusals

`PERMISSIONS_REFUSED` phrases Atlas's ACL invariants for a depositor, keyed on
the envelope's error code. An unrecognised code falls back to Atlas's own
message, so a new invariant still says something true rather than nothing.

A refusal is *reported* rather than raised. `apply!` runs **before** the
descriptive save in the same submit. Raising would discard title and abstract
edits that are independent of the ACL and perfectly valid.

### Who defers, and who does not

| Resource | Behaviour on a narrowing |
|---|---|
| Work | Never defers — nothing beneath it to strip |
| Collection | Defers to `VisibilityCascadeJob` |
| Community | Never cascades. Narrowing one changes that object alone and deliberately leaves its collections as visible as they were |

Because a Community has no cascade, restricting one would leave every collection
inside it more visible than its container. The edit form offers Private to
administrators only, and routes everyone else to an administrator.
`community_narrowing_refusal` is the server-side backstop. An admin's narrowing
is written the ordinary way. Anyone else reaching a narrowing here is JS-off or
hand-crafting a request, so it refuses. Widening is unconstrained.

### Creating is not editing

`apply_minted!` handles an ACL written onto a resource that was just minted. It
is deliberately not `apply!`, because two of that method's assumptions are false
one line after a create:

- There is no cascade to run — nothing is inside a resource this new.
- `current_read` still describes the **destination**, not this resource, so the
  narrowing check would compare against the wrong audience.

The submitted grants are merged into the new resource's own envelope rather than
replacing it. The reason is the one `envelope_with_read` exists for: Atlas
assigns `edit_groups`, `edit_users` and embargo unconditionally, so a form
naming only read would strip the rest.

`minted_permissions` reads back the ACL Atlas gave the resource at create, as
the symbol-keyed hash the metadata setter expects. Only the grant lists are
carried. `depositor` and `proxy_uploader` are preserved by Atlas when omitted,
and echoing them would re-assert attribution this form has no business touching.
