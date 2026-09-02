# Authorization

How Cerberus gates a write, how it reports a resource it may not touch or
cannot find, and how a narrowed audience reaches everything inside a container.

Source files:

- `app/controllers/concerns/authorizable.rb`
- `app/controllers/concerns/permissions_form.rb`
- `app/jobs/visibility_cascade_job.rb`

The ACL vocabulary these files speak — the grant lists, `GrantRow`, audience
clamping, and the write/defer/refuse policy — is in
[`docs/permissions.md`](permissions.md). This page is about the controller and
job layer above it.

Atlas is the real authorization boundary. Cerberus's own gates are UX and
defense in depth; see `Ability`'s class comment. Every rule on this page is a
courtesy layer over a check Atlas makes again.

## Gating a resource controller's writes

`Authorizable.authorize_resource_writes!` declares deny-by-default write gating
for the standard REST resource controllers — works, collections, communities.
Declaring the uniform "can this principal do this to this resource?" question
from one place is the structural fix for the opt-in-per-action drift the
authorization audit found: a new resource controller that calls this macro
cannot silently ship a write that is gated only at the GET form.

It installs three gates, matching the policy.

| Gate | Actions | Question it asks |
|---|---|---|
| `authorize_destination!` | `new`, `create` | the `:edit` ability on the **destination** |
| `authorize_edit!` | `edit`, `update`, plus `extra_edit:` | the `:edit` ability on the resource |
| `authorize_tombstone!` | `tombstone` | the tombstone gate |

`authenticate_user!` also runs on `new` and `create`.

The create surface gates on the destination because creating a child is a write
to its container, so the right question is "may you edit the thing you are
adding to?" Atlas asks the same one — `:create_child` against the resolved
parent. The destination arrives as a route segment, so it is always present:
there is no shape of the request that reaches `new` or `create` ungated.

Gating `edit` and `update` together closes the "form gated, write open" gap.

`extra_edit:` folds controller-specific edit-gated actions into the `:edit`
gate. Works uses it for the `metadata` and `update_metadata` tabs.

### The nested-route helpers

A Collection can hang from either a Community or another Collection, so several
helpers split on which route segment carried the parent.

| Helper | What it returns |
|---|---|
| `authorize_destination!` | gates on `:collection_id` or `:community_id`, and leaves `@destination_id` set so the action does not re-derive which segment carried the parent |
| `new_child_path(child)` | the nested `new` path for `child` under the destination this request came in on, for bouncing a rejected create back to its own form |
| `child_create_path(children)` | the matching POST target for the form `new` renders; `children` is the plural segment — `collections`, `communities`, `works` |

`authorize_edit_for!(id)` is the `:edit` gate keyed on an explicit id rather
than `params[:id]`, so a caller whose resource id rides a different param can
reuse it. The XML editor needs this: `xml#editor` carries `params[:id]` while
`xml#validate` and `xml#update` carry `params[:resource_id]`.

### Show-page affordances

`assign_show_abilities!(klass:)` sets the show-page flags from the already
loaded `@permissions`, so the Edit and Delete links render if and only if the
action behind them would be authorized — the same `:edit` and `:tombstone`
gates `authorize_*!` enforce. Never show a control the user cannot use. It also
keeps each resource controller's `#show` under the complexity budget and DRYs
the shared computation.

## Reporting a resource the user may not have

### Forbidden

`AtlasRb::ForbiddenError` renders the same friendly 403 page that
`CanCan::AccessDenied` renders. The two gates can diverge — Cerberus said yes,
Atlas said no — and when they do the write never happened, so this is a plain
403 rather than a 500. Left unhandled it would be the default Rails exception
trace, which leaks the request's params dump and file paths to the end user.

### Not found

Three shapes of "resource does not exist" land on one `rescue_from`, because
reads and writes report a missing id differently.

| Exception | Where it comes from |
|---|---|
| `AtlasRb::NotFoundError` | a **write** against a stale id. The guarded write bindings raise rather than return, since a caller that asked to change something and silently got nil is the worse outcome |
| `Authorizable::ResourceNotFound` | a **read** that came back empty. The guarded read bindings return nil on a 404, and `/resources/:id/permissions` answers 200 with no `"resource"` key for an unknown id, so the `authorize_*!` helpers raise this sentinel |
| `JSON::ParserError` | the pre-guard shape, from a binding that still parses a response body without consulting the status. Only the `/user` authentication reads are left on that path |

Keep `JSON::ParserError` on the list until those `/user` reads are guarded too,
or a stale id there becomes a 500.

`ResourceNotFound` exists because neither nil-returning read raises by itself,
so an unguarded unwrap trips a `NoMethodError` on the nil somewhere downstream
of the actual cause. Translating both into one sentinel puts them on the same
`rescue_from` path as the write-side `AtlasRb::NotFoundError`.

All three render the same friendly 404 page, with the singularized controller
name giving the template a sensible `obj_type` default — "work", "collection",
"download".

### Tombstones

`perform_tombstone!(response, type:)` translates an Atlas tombstone response
into the right redirect and flash.

The tombstone bindings return the raw `Faraday::Response`. atlas_rb does **not**
raise on the tombstone refusal: `RaiseOnResourceError` passes a 422 whose body
carries `code: "has_live_children"` straight through. Atlas refuses with 422
when the resource still has live, non-tombstoned members, so a caller that
ignores the response — the `tombstone; redirect notice:` shape — reports a false
"deleted" while the resource stays live.

That is guaranteed for Communities. `ShowcaseProvisioner` seeds every Community
with live showcase Collections, so a Community's tombstone is always refused.

## Rendering the permissions form

`PermissionsForm` assembles everything the permissions form needs before it
renders, and parses the submitted form into an ACL envelope: the pretty grant
rows, the group picker, the visibility ceiling a resource inherits from its
container, and the parse of the form's indexed permission rows.

This half decides nothing and writes nothing. `ResourcePermissions` owns the
write and the policy that can refuse it — see
[`docs/permissions.md`](permissions.md).

### Who may revoke a grant

`revocable_grant?(group)` is the view-side mirror of the Atlas rule that only a
member of a group may remove its grant.

It reads `current_user`, **not** `effective_user`. The acting NUID Atlas
resolves its own actor from is signed from `Current.nuid`, which is the
authenticated user, so consulting the view-as target here would lock rows
against a different principal than the one the write is evaluated as.

A nil user has no membership to appeal to and stays conservative, matching how
Atlas treats an actor-less caller. The `public` token never reaches here — it is
stripped by `pretty_resource_permissions` and is driven by the separate General
Permissions control.

### The group picker

`groups_for_permissions_picker` builds the "add a group" dropdown's candidate
list.

| Acting user | Candidates |
|---|---|
| `:admin`, or a devolved-admin delegate (`User#admin_delegate?`) | the full known-group registry, for system-wide arbitrary permission adjustment |
| everyone else | the acting user's own Grouper memberships — you can only grant a group you are yourself in |

Giving full admins the registry also fixes a latent gap: an `:admin` with no
personal Grouper groups is a legitimate shape, because the role itself is the
grant, and that user previously saw an empty picker.

### The visibility ceiling on an edit form

`assign_visibility_ceiling(resource)` decides whether the Public option may be
offered at all. Atlas refuses a resource more visible than its container — a
422 carrying `visibility_exceeds_parent`, surfaced as
`AtlasRb::PermissionsError` — so offering Public under a private parent would
only produce an error the depositor cannot act on.

`@visibility_parent` names the blocking container so the form can say which one
is in the way. A root with no parent is unconstrained, as is a caller that does
not supply the resource. A parent lookup failure must not block the form, so it
falls back to offering Public; Atlas still enforces.

### The create form

`new_form_permissions!(destination_id)` is everything the permissions section of
a *create* form needs.

Atlas copies the destination's read ACL onto a new child wholesale, group grants
included, so the form opens holding exactly what the resource would be born
with rather than a blank slate or a fixed default. That is what lets it add a
choice without moving the outcome: submit it untouched and the ACL is the one
inheritance would have produced anyway. A form that defaulted to Private instead
would quietly narrow every child of a public container, and drop the inherited
group grants with it.

`@narrowing_allowed` stays unset, which is what puts `_visibility_control` on
its ordinary offered branch — see the `== false` test there. There is nothing
inside a resource that does not exist to cascade to.

`assign_destination_ceiling(destination_id)` is the create-form counterpart to
`assign_visibility_ceiling`. That one walks the resource's ancestors, which a
resource that does not exist yet has none of. The create gate has already
loaded the destination's envelope into `@permissions`, and the destination *is*
the parent whose visibility bounds the child, so the ceiling costs no extra
call.

Only the private branch needs the parent named, so the lookup for its title is
paid only there. A failed lookup still withholds Public: the envelope has
already said the destination is private and Atlas would refuse the write
regardless, so generic copy beats a choice that cannot succeed.
`DESTINATION_TITLE_UNKNOWN` stands in for that title. The sentence it lands in
is already about a container the reader just navigated through, so it reads as a
reference rather than a gap.

## Parsing the submitted form

`permission_params(resource_key)` returns the permission and embargo fields sent
to Atlas's metadata PATCH. These are **not** MODS and never touch the
descriptive document.

Thumbnails ride the same edit form but are persisted separately by
`apply_thumbnail`. They are machine-set Delegate URIs with their own Atlas
endpoint, not PATCH fields.

### The Public/Private toggle

`mass_permissions` applies the visibility toggle to the read ACL. `read` is
always set definitively when `mass` is present, including to `[]`. Omitting the
key leaves Atlas's stored read untouched, so a Private save with no group grants
would silently keep the item public.

Public keeps the group grants alongside the `public` sentinel rather than
replacing them. They grant nothing extra while the item is public, but they are
what a later flip to Private falls back to, so dropping them here would revoke a
grant the curator made in the very submit that added it. Sets compose their read
ACL the same way — see `SetSharing#build_permissions`.

## Cascading a narrowed audience

`VisibilityCascadeJob` applies a container's narrowed read audience down its
subtree, deepest first.

The caller does **not** write the container before enqueuing. The job narrows
the container last, after everything beneath it — see `NarrowingTargets` for why
the order is load-bearing. The job is handed the intended audience, not a fait
accompli.

Re-running is safe. Each resource is clamped against the container's audience
and skipped when that changes nothing, so a retry after a partial run only
finishes the remainder.

### Arguments

| Argument | Meaning |
|---|---|
| `noid:` | the container being narrowed |
| `uuid:` | its Solr id, for the subtree lookup |
| `permissions:` | the container's whole submitted ACL envelope |

The container is written from `permissions:` verbatim, so an edit-group or
embargo change made in the same submit rides along. Descendants are clamped
against its `read` rather than taking a copy of it.

### Retrying on a lock conflict

`retry_on AtlasRb::StaleResourceError` backs off polynomially for five
attempts. Atlas retries its own optimistic-lock conflicts and only surfaces this
once its budget is exhausted — which during a deposit means finalize jobs are
still touching the same resources. Backing off and re-running is safe precisely
because the cascade is idempotent.

Inside the loop a lock conflict is re-raised rather than recorded as a failure,
so it escapes to `retry_on`. It is transient, and re-running the whole cascade
costs only the writes it already made being skipped. Any other `AtlasRb::Error`
is collected as a per-target failure.

### Writing the container

`write_container` takes the submitted envelope verbatim. The person editing it
said exactly what they wanted, and by that point every descendant is already
within it.

It is deliberately not clamped: clamping against its own new audience would be a
no-op, and round-tripping the stored envelope would silently drop the edit-group
or embargo edits made in the same submit.

The container is tallied separately from the descendants. The report speaks to
what else changed — "the items inside it" — and the person already knows they
restricted the container, because they just asked for it.

### Clamping the derivative-access default

A container's derivative-access default lives in Cerberus, not in the ACL Atlas
holds, so narrowing the container leaves that default untouched and pointing at
an audience the container no longer has. `Sentinel` already refuses that
combination when someone authors it — `policy_within_resource` — and
`clamp_sentinel` keeps the same rule true when the container narrows underneath
a default that was coherent when written.

It has to hold, not merely look untidy. Atlas refuses a tier more visible than
its Work, and the default is applied to every new deposit, so a stale default
made the next deposit into that collection fail outright.

A tier whose audience shares nobody with the container's new one clamps to the
empty list — withheld from everyone rather than re-pointed at whoever is left.
That is the same answer `audience_intersect` gives a disjoint child ACL, and the
right way round for a gate whose purpose is to withhold. The authoring form
renders it as "Restrict to groups" with none ticked, which is what it is.

### Reporting the result

A cascade is slow enough that whoever triggered it has moved on, and a partial
result is the one outcome they must not have to discover for themselves:
anything that failed to narrow is still exposed. Failures are therefore named
rather than counted.

A cascade with no actor — a rake task — has nobody to tell, and is recorded on
the admin ledger regardless. An item left exposed matters whether or not a
person triggered the run.

The body ends with a path, not a `_url`. A job has no request to take a host
from, and the inbox renders these in-app anyway. `LoadReport` makes the same
choice.
