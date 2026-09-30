# Authorization

How Cerberus gates a write, and how it reports a resource it may not touch or
cannot find. Also, how a narrowed audience reaches everything inside a
container.

Source files:

- `app/controllers/concerns/authorizable.rb`
- `app/controllers/concerns/permissions_form.rb`
- `app/jobs/visibility_cascade_job.rb`

The ACL vocabulary these files speak — the grant lists, `GrantRow`, audience
clamping, and the write/defer/refuse policy — is in
[`docs/permissions.md`](permissions.md). This page is about the controller and
job layer above it.

Atlas is the real authorization boundary. Cerberus's own gates are UX and
defense in depth. Atlas makes every check on this page again.

## Gating a resource controller's writes

`Authorizable.authorize_resource_writes!` declares deny-by-default write gating
for the standard resource controllers: works, collections and communities. It
asks one uniform question in one place: may this principal do this to this
resource? That stops gates drifting when each action opts in on its own. A new
resource controller that calls the macro cannot ship a write gated only at its
GET form.

It installs three gates.

| Gate | Actions | Question it asks |
|---|---|---|
| `authorize_destination!` | `new`, `create` | the `:edit` ability on the **destination** |
| `authorize_edit!` | `edit`, `update`, plus `extra_edit:` | the `:edit` ability on the resource |
| `authorize_tombstone!` | `tombstone` | the tombstone gate |

`authenticate_user!` also runs on `new` and `create`.

The create gate checks the destination, because creating a child is a write to
its container. So the question is "may you edit the thing you are adding to?"
Atlas asks the same one: `:create_child` against the resolved parent. The
destination arrives as a route segment. If neither segment is present,
`authorize_destination!` raises `ResourceNotFound`, so no request reaches `new`
or `create` ungated.

Gating `edit` and `update` together closes the "form gated, write open" gap.

`extra_edit:` adds controller-specific actions to the `:edit` gate.
`WorksController` adds `metadata`, `update_metadata`, `request_change`,
`upload`, `add_file`, `remove_caption` and `restore_caption`. The two caption
actions also require the admin or delegated-admin tier, through
`WorkCaptions#require_caption_steward!`, because Atlas refuses a FileSet
tombstone or restore from anyone below it. `CollectionsController` adds
`sentinel` and `request_restriction`, and `CommunitiesController` adds
`request_restriction`.

### The nested-route helpers

A Collection can hang from either a Community or another Collection, so several
helpers split on which route segment carried the parent.

| Helper | What it returns |
|---|---|
| `authorize_destination!` | gates on `:collection_id` or `:community_id`, and sets `@destination_id` so the action does not re-derive which segment carried the parent |
| `new_child_path(child)` | the nested `new` path for `child` under the destination this request came in on, for bouncing a rejected create back to its own form |
| `child_create_path(children)` | the matching POST target for the form `new` renders; `children` is the plural segment — `collections`, `communities`, `works` |

`authorize_edit_for!(id)` is the `:edit` gate keyed on an explicit id rather
than `params[:id]`. A caller whose resource id rides a different param can
reuse it. The XML editor needs this: `xml#editor` carries `params[:id]`, while
`xml#validate`, `xml#repair` and `xml#update` carry `params[:resource_id]`.

### Show-page affordances

`assign_show_abilities!` sets `@can_edit` and `@can_tombstone` from the
already loaded `@permissions`, typed by the controller's `solr_type`. So the
Edit and Delete links render if and only if the action behind them would be
authorized. Those are the same `:edit` and `:tombstone` checks the
`authorize_*!` gates enforce. Never show a control the user cannot use. Sharing
the method also keeps each resource controller's `#show` under the complexity
budget.

## Reporting a resource the user may not have

### Forbidden

`AtlasRb::ForbiddenError` renders the same friendly 403 page that
`CanCan::AccessDenied` renders. The two gates can disagree: Cerberus says yes and
Atlas says no. Then the write never happened, so the answer is a plain 403, not
a 500. Unhandled, the error would show the default Rails exception trace, which
leaks the request's params and file paths to the end user.

### A read Atlas refuses

A resource the caller may not read is a **403**, not a 404. DRS has never hidden
a resource's existence: v1 rendered 403 for a non-public record whether or not
the caller was signed in, reserving 404 for a genuine miss and 410 for a
tombstone. The 403 page is also the only one that tells a signed-out reader to
log in, which is the actual remedy.

Atlas refuses the read with a 403, and the guarded read bindings raise the bare
`AtlasRb::ResourceError` carrying that status. `Authorizable` renders the
forbidden page for a 403 and **re-raises everything else**. A 401 or 422 there
is Cerberus's own misconfiguration, such as a wrong bearer token. Dressed as a
permission page, it would claim "this resource does not exist" on every page at
once. So it keeps the loud default handler.

Two ordering constraints hold this together, and both are load-bearing.

1. The `ResourceError` handler must be declared **above** the not-found handler.
   `rescue_from` matches the last registered handler first, and
   `AtlasRb::NotFoundError` subclasses `ResourceError`. Registered below, it
   swallows every write-side 404 and the not-found page becomes unreachable.
2. `#show` must keep loading the resource before `authorize_show!`. The
   403 arrives on the `find`, not on the gate.

Every surface reports a refused read the same way, including those reached
through `authorize_show!` or `authorize_edit_for!` rather than a `find`. That
depends on `AtlasRb::Resource.permissions` checking the status before it parses
the body. A binding that parsed first would unwrap a 403 envelope to the same
`nil` a missing id gives, and the page would 404. Cerberus cannot recover a
status the binding discarded.

**An unknown id still answers 404, but not for the obvious reason.** Atlas's
`ResourcesController#permissions` authorizes before its nil check, against
`resource || Resource`. For an unknown id CanCan gets the bare class. A class
check cannot evaluate the block-form `can :read, Resource` rule, so it passes.
The request then falls through to `head :not_found`. Absence is reported as
absence, but through that pass-through, not through the ordering. Anyone
tightening that rule in Atlas must re-check this, or a mistyped NOID starts
rendering the forbidden page.

### Not found

Two shapes of "resource does not exist" land on one `rescue_from`, because
reads and writes report a missing id differently.

| Exception | Where it comes from |
|---|---|
| `AtlasRb::NotFoundError` | a **write** against a stale id. The guarded write bindings raise rather than return, because silently getting nil back from a change request is the worse outcome |
| `Authorizable::ResourceNotFound` | a **read** that came back empty. The guarded read bindings, `Resource.permissions` included, return nil on a 404. `require_resource!` and the `authorize_*!` helpers turn that nil into this exception |

`JSON::ParserError` is deliberately **not** on the list. Every atlas_rb read
checks the status before parsing. So an unparseable body is a Cerberus bug, not
Atlas saying "no such thing", and it must not be reported as a 404.

`ResourceNotFound` exists because a nil-returning read does not raise by
itself. An unguarded unwrap then trips a `NoMethodError` on the nil, somewhere
downstream of the real cause. Raising one exception puts a missing read on the
same `rescue_from` path as the write-side `AtlasRb::NotFoundError`.

Both render the same friendly 404 page. `not_found_label` gives the template
its `obj_type`: the singularized controller name, such as "work", "collection"
or "download". A controller named after a surface rather than a noun overrides
it. `XmlController` and `HistoriesController` both answer "resource".

#### Converting a nil read

`require_resource!` is the one place that turns a nil read into
`ResourceNotFound`. Every controller that reads a resource by id wraps the read
in it:

```ruby
@work = require_resource!(AtlasRb::Work.find(params[:id]))
```

The conversion stays in Cerberus rather than in atlas_rb, because the split
above is deliberate: a write raises and a read returns nil. Keeping the
conversion in one method puts the gem's contract in one place, so a change to
what nil means is one edit.

It converts nil and nothing else. Do not let it absorb the tombstone checks.
`CollectionsController#show` renders 410 Gone for a tombstoned Collection, via
`render_gone`. `#facet_scope_filters` raises the same 404 for a tombstoned one,
because a tombstoned container has no browsable contents to count. That
difference is intentional. `Admin::FileVersionsController` likewise keeps its
own second raise for an unknown version id.

### Tombstones

`perform_tombstone!` calls `AtlasRb::Resource.tombstone(params[:id])` and turns
the response into a redirect and flash. It takes no arguments: the flash names
the controller's `solr_type`.

| Response | Result |
|---|---|
| success | redirect to `return_to`, or else the parent, with "deleted" |
| 422 | redirect back with "can't be deleted while it still contains live members" |
| anything else | redirect back with "could not be deleted" |

The tombstone binding returns the raw `Faraday::Response`. atlas_rb does **not**
raise on the refusal: `RaiseOnResourceError` passes the 422 through, with
`code: "has_live_children"` in its body. Atlas answers that 422 while the
resource still holds a live Community, Collection or Work. So a caller that
ignores the response reports a false "deleted" while the resource stays live.

For Communities that is the usual case. `CommunitiesController#create` runs
`ShowcaseProvisioner`, which gives each new Community live showcase
Collections. So Atlas refuses a Community's tombstone until those are gone.

`return_to` lets a list that offers the delete, such as deposit triage or My
DRS, take the user back to itself. `url_from` drops an off-host value, so it
cannot become an open redirect.

## Rendering the permissions form

`PermissionsForm` assembles everything the permissions form needs before it
renders, and parses the submitted form into an ACL envelope. It builds the grant
rows, the group picker, and the visibility ceiling a resource inherits from its
container. It also parses the form's indexed permission rows.

This half decides nothing and writes nothing. `ResourcePermissions` owns the
write and the policy that can refuse it — see
[`docs/permissions.md`](permissions.md).

### Who may revoke a grant

`revocable_grant?(group)` is the view-side mirror of the Atlas rule that only a
member of a group may remove its grant. An admin or devolved admin
(`admin_delegate?`) may revoke any grant, as in Atlas.

It reads `current_user`, **not** `effective_user`. Atlas resolves its actor from
the NUID signed from `Current.nuid`, which is the authenticated user. So
consulting the view-as target here would lock rows against a different
principal than the one Atlas evaluates the write as.

A nil user has no membership to appeal to, so every row stays locked. Atlas
treats an actor-less caller the same way. The `public` token never reaches
here. `pretty_resource_permissions` strips it, along with
`Permissions::STAFF_EDIT_GROUP`, and the separate General Permissions control
drives it.

### The group picker

`groups_for_permissions_picker` builds the "add a group" dropdown's candidate
list.

| Acting user | Candidates |
|---|---|
| `:admin`, or a devolved admin (`User#admin_delegate?`) | the full known-group registry (`Group.for_select`), so they can adjust any resource's permissions |
| everyone else | the acting user's own Grouper groups. You can only grant a group you are in yourself |

Admins need the registry for a second reason. An `:admin` with no Grouper groups
of their own is a legitimate shape, because the role itself is the grant. Built
from their memberships, their picker would be empty.

### The visibility ceiling on an edit form

`assign_visibility_ceiling(resource)` sets `@public_allowed`: whether the Public
option may be offered at all. Atlas refuses a resource more visible than its
container, with a 422 carrying `visibility_exceeds_parent`. atlas_rb raises that
as `AtlasRb::PermissionsError`. So offering Public under a private parent would
only produce an error the depositor cannot act on.

The ceiling is the resource's immediate parent, the last entry in its
`ancestors`. `@visibility_parent` names that container, so the form can say
which one is in the way. A root with no parent is unconstrained, and so is a
call with no resource. A failed parent lookup must not block the form, so it
falls back to offering Public. Atlas still enforces.

### The create form

`new_form_permissions!(destination_id)` is everything the permissions section of
a *create* form needs.

Atlas copies the destination's read ACL onto a new child wholesale, group grants
included. So the form opens holding exactly what the resource would be born
with, rather than a blank slate or a fixed default. That is what lets it add a
choice without moving the outcome. Submit it untouched and the ACL is the one
inheritance would have produced anyway. A form that defaulted to Private instead
would quietly narrow every child of a public container, and drop the inherited
group grants with it.

Order matters inside `new_form_permissions!`. The ceiling reads the
destination's envelope, and `pretty_resource_permissions` then mutates that same
envelope to strip the `public` sentinel. So the ceiling is settled first.

`@narrowing_allowed` stays unset. That puts `_visibility_control` on its
ordinary branch — see the `== false` test there. A resource that does not exist
yet has nothing inside it to cascade to.

`assign_destination_ceiling(destination_id)` is the create-form counterpart to
`assign_visibility_ceiling`. That method reads the resource's ancestors, and a
resource that does not exist yet has none. The create gate has already loaded
the destination's envelope into `@permissions`. The destination *is* the parent
whose visibility bounds the child, so the ceiling costs no extra call.

Only the private branch needs the parent named, so only that branch pays for
the title lookup. A failed lookup still withholds Public. The envelope has
already said the destination is private, and Atlas would refuse the write
anyway. Generic copy beats offering a choice that cannot succeed.
`DESTINATION_TITLE_UNKNOWN` ("The destination container") stands in for the
title. The sentence it lands in is about a container the reader just navigated
through, so it reads as a reference rather than a gap.

## Parsing the submitted form

`permission_params` returns the permission and embargo fields from the
submitted form, under the controller's `resource_key`. `ResourcePermissions`
writes them to Atlas. They are **not** MODS and never touch the descriptive
document.

Thumbnails ride the same edit form but are saved separately by
`Thumbable#apply_thumbnail`. They are machine-set Delegate URIs with their own
Atlas endpoint, not permission fields.

`transform_permissions` groups the indexed `group_id` / `ability` rows into
`read` and `edit` lists, and copies a submitted embargo into
`permissions[:embargo]`.

### The Public/Private toggle

`mass_permissions` applies the visibility toggle (`params[:mass]`) to the read
ACL. When `mass` is present, `read` is always set explicitly, even to `[]`.
Atlas keeps a stored key the payload omits, so leaving `read` out of a Private
save with no group grants would silently keep the item public.

Public keeps the group grants alongside the `public` sentinel rather than
replacing them. They grant nothing extra while the item is public, but a later
flip to Private falls back to them. Dropping them here would revoke a grant the
curator made in the very submit that added it. Sets compose their read ACL the
same way — see `SetSharing#build_permissions`.

## Cascading a narrowed audience

`VisibilityCascadeJob` applies a container's narrowed read audience down its
subtree, deepest first.

`NarrowingRequest` enqueues it, and does **not** write the container first. The
job narrows the container last, after everything beneath it. Top-down would
leave every descendant more visible than the container until the run finished,
and a crash would leave it that way. `NarrowingTargets` yields that order — see
[`docs/narrowing.md`](narrowing.md). So the job receives the intended audience,
not a change already made.

Re-running is safe. The job clamps each descendant against the container's
audience and skips it when that changes nothing. A retry after a partial run
only finishes the rest.

### Arguments

| Argument | Meaning |
|---|---|
| `noid:` | the container being narrowed |
| `uuid:` | its Solr id, for the subtree lookup |
| `permissions:` | the container's whole submitted ACL envelope |

The job writes the container from `permissions:` verbatim, so an edit-group or
embargo change made in the same submit rides along. It clamps each descendant
against that `read` rather than copying it, and writes only `{ 'read' => ... }`.
Atlas keeps the descendant's other keys.

### Retrying on a lock conflict

`retry_on AtlasRb::StaleResourceError` backs off polynomially for five
attempts. Atlas retries its own optimistic-lock conflicts, and raises this only
once its budget is spent. During a deposit, that means finalize jobs are still
touching the same resources. Backing off and re-running is safe only because
the cascade is idempotent.

Inside the loop, the job re-raises a lock conflict rather than recording it as
a failure, so it reaches `retry_on`. The conflict is transient. Re-running the
cascade costs only skipping the writes it already made. The job collects any
other `AtlasRb::Error` as a per-target failure.

### Writing the container

`write_container` sends the submitted envelope verbatim. The person editing it
said exactly what they wanted, and by then every descendant is already within
it.

It is deliberately not clamped. Clamping against its own new audience would do
nothing. Round-tripping the stored envelope instead would silently drop the
edit-group or embargo edits made in the same submit.

The job counts the container separately from the descendants. The report says
what else changed: how many items were narrowed, and how many already were. The
person already knows they restricted the container, because they just asked for
it.

### Clamping the derivative-access default

A container's derivative-access default (its `Sentinel`) lives in Cerberus, not
in the ACL Atlas holds. So narrowing the container would leave that default
pointing at an audience the container no longer has. `Sentinel` refuses that
combination when someone authors it, in `policy_within_resource`.
`clamp_sentinel` keeps the rule true when the container narrows underneath a
default that was valid when written. The job clamps the container's `Sentinel`
and each descendant's.

The rule must hold; a stale default is not merely untidy. Atlas refuses a tier
more visible than its Work, and `Sentinel.apply_default` applies the default to
every new deposit. So a stale default makes the next deposit into that
collection fail outright.

A tier whose audience shares nobody with the container's new one clamps to the
empty list. It is withheld from everyone, rather than re-pointed at whoever is
left. `audience_intersect` gives a disjoint child ACL the same answer. That is
the right way round for a gate whose purpose is to withhold. The authoring form
renders it as "Restrict to groups" with none ticked, which is what it is.

### Reporting the result

`report` sends the result through `CompletionNotice.deliver`, which writes an
`AdminNotice` and messages the actor's inbox. The actor is whoever enqueued the
job: `ApplicationJob` carries their `Current.nuid` onto the queue.

A cascade is slow enough that whoever triggered it has moved on. A partial
result is the one outcome they must not have to discover for themselves:
anything that failed to narrow is still exposed. So the report names each
failure rather than counting them.

A cascade with no actor, such as one run from a rake task, has nobody to tell.
`CompletionNotice` still records it on the admin ledger. An item left exposed
matters whether or not a person triggered the run.

The body ends with a path, not a `_url`. A job has no request to take a host
from, and the inbox renders these in-app anyway. `LoadReport` makes the same
choice.
