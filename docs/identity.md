# Identity

Who Cerberus thinks the current request belongs to. How a `User` is built at
sign-in, and what each role predicate gates. How discovery abilities follow from
it, and how an administrator acts or looks as somebody else.

Source files:

- `app/models/user.rb`
- `app/models/ability.rb`
- `app/controllers/atlas_controller.rb`
- `app/lib/devise/strategies/custom_authenticatable.rb`
- `app/controllers/concerns/impersonation_session.rb`
- `app/controllers/admin/impersonations_controller.rb`
- `app/controllers/concerns/depositor_context.rb`

The ACL vocabulary these files gate on — the grant lists and the group
constants — is in [`docs/permissions.md`](permissions.md). The controller gates
that use the abilities described here are in
[`docs/authorization.md`](authorization.md).

## Building a user

`User` has no database table. It is an `ActiveModel` object built per session
from Atlas's user lookup. It carries `email`, `nuid`, `name`, `groups`, `role`
and `affiliation`. `AtlasController#sign_in_from_atlas` calls
`AtlasRb::Authentication.login(nuid)`, builds the `User` from the result, and
hands it to Devise's `sign_in`. It also clears `session[:account_email]`, so a
fresh login lands on the person's preferred account.

`groups` is the array the identity provider asserts. It is `nil` on the guest
fallback, so `User#member_of?` wraps it in `Array` before testing membership.
Group gates call `member_of?(...)` rather than repeating
`Array(...).include?(...)` at every call site.

### The Warden strategy

`Devise::Strategies::CustomAuthenticatable` backs
`devise :custom_authenticatable`. It inherits `Devise::Strategies::Authenticatable`,
which supplies the underlying strategy logic. It is based on
[this gist](https://gist.github.com/madtrick/3917079).

Warden calls `authenticate!`. On success the strategy calls `success!` with an
instance of the model class Devise is configured with: `mapping.to`, the `User`
class. It builds that instance from `authentication_hash`, which the base class
fills with the fields the login form submitted. Only `nuid`, `email` and
`password` are copied. On failure it calls `fail!`.

`credentials_valid?` returns `true`. It checks nothing, so whatever the
authentication hash carries becomes the signed-in identity. The NUID lookup
against Atlas that would validate it is not wired here. The app signs in through
`AtlasController#sign_in_from_atlas` instead.

### Displaying a name

`pretty_name` runs the stored name through Namae, which understands only
person-shaped names. A descriptive or organisational name, such as "Law Library
Staffer", parses to nothing. Keep the fallback to the raw name. An empty display
name blanks the whole user block in the navbar, and that block holds Log Out.
The user would then have to clear the session by hand to get out.

## What each role predicate gates

| Predicate | Test | What it gates |
|---|---|---|
| `admin?` | `role == 'admin'` | Mirrors the Atlas-side role. Because `Ability` short-circuits on it, an Atlas admin drives admin-only UI without every Grouper group stuffed onto their record |
| `privileged?` | `role == 'privileged'` | Whether the deposit form (`works/new`) renders the proxy ("upload as") radio, for an admin or a privileged user who is not acting as someone. Group membership still selects *which* collections the user may deposit into |
| `messageable?` | not `guest` or `anonymous` | Inbox eligibility. The guest NUID is a shared fallback identity with no inbox of its own |
| `curates_sets?` | `messageable?` | Whether the user may own Sets. Sets share the inbox's human-role floor — one concept, two surfaces. Split the predicates if the floor ever diverges |
| `loader_tier?` | `loader`, `privileged` or `admin` | The loader surface: `LoadersController` (the My Loaders page), `LoadsController`, and the menu link. *Which* loaders appear inside is `Loader.available_to`'s concern, per Grouper group |
| `admin_delegate?` | `privileged?` **and** `Permissions::ADMIN_GROUP` | The devolved-admin tier — a named subset of `Admin::BaseController` surfaces below the full `:admin` role's blanket access. See [`docs/admin.md`](admin.md) |
| `can_bypass_embargo?` | `admin?` or `Permissions::STAFF_EDIT_GROUP` | The only exception to an active embargo's download withholding. Widening it hands out embargoed bytes. Callers ask it of `effective_user` |

Two of these are easy to get wrong.

`admin_delegate?` mirrors Atlas's `User#admin_delegate?`, which pairs the same
role and group. Neither half alone is sufficient. It covers only the narrower
non-admin tier, so call sites must ask `admin? || admin_delegate?`. Otherwise
they lock full admins out of the surface.

`can_bypass_embargo?` uses `STAFF_EDIT_GROUP` on the read side, which is not
that group's usual job. Elsewhere it is the edit group Atlas adds to everything.
Here it stands in for "someone who can confirm this restriction is
intentional".

## Discovery abilities

`Ability` decides `:read`, `:edit` and `:tombstone` on a `SolrDocument`.
`ApplicationController#current_ability` builds it from `effective_user`, so a
view-as session sees the target's decisions.

| Principal | Rules |
|---|---|
| Nobody signed in | `:read` on public documents only |
| `:admin` | `can :manage, :all` |
| Everyone else | `apply_group_abilities` |

The admin wildcard mirrors Atlas's own `can :manage, :all` for `:admin`.
Honouring the role rather than a group means the role itself is the grant on
both sides.

For a signed-in non-admin:

| Verb | Granted when |
|---|---|
| `:read` | the document is public, a read grant matches one of the user's groups, or the user is edit-equivalent |
| `:edit` | the user is edit-equivalent |
| `:tombstone` | the user is edit-equivalent, or is the recorded `proxy_uploader` on a Work |

### Edit-equivalence, and why read follows it

`edit_equivalent?` is true for an ACL edit-group match, the user's NUID in the
ACL's `edit_users`, **or** ownership (`depositor`). Atlas's `edit_grants?` makes
the same test: `group_acl_grants?` plus its ownership check.

Read must follow it. Otherwise two ordinary states lock a person out of their
own material: a depositor who set their collection Private with no group rows,
and a group granted Manage but not View. Both keep the Edit page and get a 403
on the object itself.

It cannot widen disclosure, because it admits only people who could already
change the thing. Atlas's own read rule, `Ability#resource_readable?`, admits
the same three ways in: public, a read group, or `edit_grants?`. So nothing here
outruns what the backend will serve.

Ownership needs its own test because the ACL does not record it. A personal
root and everything beneath it carries `edit: [repository:staff]`, with the
owner recorded only as `depositor`. An ACL-only test would lock a non-staff
depositor out of their own workspace. If the two sides diverge, Cerberus hides
an Edit link for a write Atlas would allow.

`:restore` is deliberately not one of these verbs. Reversing a tombstone is an
operator action, not an owner one.

### Discovery follows the same read rule

`SearchBuilder#apply_gated_discovery` puts `:read` into Solr as one `fq`,
built by `discovery_clause`. A document matches when it is public, a read group
matches, an edit group matches, or the user's NUID is in
`edit_access_person_ssim` or `depositor_ssi`. Admins skip the filter.
`gated_user` is the effective user, so a view-as session is gated as the
target.

The two must stay in step. If the filter is narrower, staff and depositors
cannot find items they can open: staff hold edit, not read, on every resource,
and a private Work names its depositor in no group. If the filter is wider, a
search shows hits that 403 when opened.

Atlas's `SolrReadGate` applies the same five clauses to `/resources/search`,
Set contents and descendant-work lists. A change here needs the same change
there.

### Ownership and proxy deposits

`depositor?` is not Work-scoped, because a depositor owns their Collections too.
The whole workspace subtree inherits their NUID: Atlas's creators copy
`parent.permissions`, which carries `depositor`. A Collection they own is theirs
to edit and, once empty, to withdraw. Emptiness needs no check here, because
Atlas refuses the tombstone while live children remain.

`proxy_uploader?` applies to Works only (`internal_resource_tesim` is `Work`). A
librarian who proxied a deposit keeps tombstone rights on it. The recorded
`proxy_uploader` keeps authority, not only the depositor they acted for.

## Impersonation

`ImpersonationSession` is included into `ApplicationController`, so it governs
every request. An impersonating administrator browses the whole app, not just an
admin surface. Its two modes are mutually exclusive: each `start_*` calls
`end_impersonation` first.

| Mode | Who may start it | Authenticated identity | Effect | Writes |
|---|---|---|---|---|
| acting-as | `:admin` only | stays the admin (`Current.nuid`) | sets `Current.on_behalf_of` to the target, so atlas_rb writes carry `On-Behalf-Of: <target>` through the default on-behalf-of callable. Atlas authorizes the admin and stamps the target as provenance | allowed, and attributed to the target |
| view-as | `:admin` or a devolved admin | untouched | sets `view_as_nuid`, which drives `effective_user`, the single user both `Ability` and `SearchBuilder` consult | rejected |

Session state lives in the Rails session (`session[:acting_as_nuid]` or
`session[:view_as_nuid]`) with a 30-minute sliding inactivity limit,
`IMPERSONATION_TTL`. `enforce_impersonation_ttl` runs on every request and
either ends the session or refreshes the clock. Every way a session ends goes
through `end_impersonation`.

`impersonation_target` hydrates whichever target is set, for the banner's name
and NUID. It is `nil` when there is no session or hydration fails.

### Ordering, and the audit trail

`start_acting_as` and `start_view_as` emit the `impersonation_started` audit
event **before** they set the session, so an admin can never impersonate without
a trail. A failed emit raises and no session is set.
`ImpersonationsController#begin_impersonation` rescues a `Faraday::Error` into a
flash and a redirect rather than a 500.

`end_impersonation` reverses that order. It tears the session down first, then
emits `impersonation_ended` best-effort and logs a failure. The rescue covers
`AtlasRb::Error` as well as `Faraday::Error`, because a refusal Atlas states in
an HTTP response is still a failed emit. A read-only maintenance window is the
proving case. The session is already gone by then, so letting
`AtlasRb::ReadOnlyModeError` escape would land the admin on the maintenance page
and tell them an exit failed that had in fact succeeded.

`emit_impersonation_event` records a session-scoped event through
`AtlasRb::AuditEvent.emit`; there is no resource to hang it on. It passes the
admin as `actor_nuid` explicitly, with the target as `on_behalf_of_nuid` and
the mode. The gem sends `actor_nuid` as the `User:` header and records it as
the principal. So the admin gate still holds on an `impersonation_ended` emit
fired after the session is gone.

### Context plumbing

`set_impersonation_context` copies the session's impersonation state into
`Current`. `Current.on_behalf_of` drives write attribution.
`Current.view_as_nuid` is read-side bookkeeping, and must never become a write
header. `effective_user` reads the session, not `Current`.

### Which NUID a gated read uses

`viewer_nuid` is `effective_user&.nuid`. A read that gates on the *view-as
target* passes it to atlas_rb. Three reads take it: `Work.assets`,
`Work.file_sets` and `Blob.work`. So do the two zip packers, `QueueZipPacker`
and `SetZipPacker`.

The kwarg's presence is a per-call decision, not boilerplate to be removed.
`mods` and `find` carry no `nuid:` and must not: atlas_rb signs
`Current.nuid`, the real user, into those reads. `Current` already holds
`view_as_nuid`, so making the read NUID ambient looks free, and it would be a
correctness regression — `mods` would silently acquire view-as gating.

| Read | Gated by |
|---|---|
| `mods`, `find` | `Current.nuid`, the real user, via atlas_rb's ambient `User:` header |
| `Work.assets`, `Work.file_sets`, `Blob.work` | `viewer_nuid`, the view-as target |

`WorksController#parallel_show_reads` and `#downloads` resolve it into a local
before building the tasks. The parallel reads run on worker threads, and a
worker must not touch ActiveRecord, which `effective_user` can reach.

### Rejecting a write under view-as

`reject_writes_in_view_as` ends the session loudly on any request that is not
GET or HEAD. It neither performs the write nor drops it silently. A plain
request gets a redirect to the root page with an alert.

"Loudly" needs help when the write came from inside a turbo-frame — the My DRS
token panel is one. Turbo looks for that frame in the redirect's target, does not
find it on the root page, and discards the entire response. That means no token,
no error, no flash, and the banner still showing until the next navigation. The
button looks simply dead, so an admin may keep pressing it while no longer
impersonating anyone.

So the reply to a turbo-frame request is a turbo-stream refresh. Turbo honours a
turbo-stream whatever frame the request came from, and a refresh re-renders the
page, which shows the flash and drops the banner.

The refresh must pass `request_id: nil`. The default is the current request's
id, and Turbo drops a refresh whose id it has already seen. That is true of
every refresh sent in reply to the request that triggered it.

### Hydrating a target

`hydrate_user` builds a `User` from the same Atlas user lookup that sign-in uses,
`AtlasRb::Authentication.login`; there is no database to read. It clears
`Current.on_behalf_of` for the call, because this is a plain profile lookup, not
an on-behalf-of operation. The lookup sends the target as `User:`, and the
target is not an admin. So a leaked `On-Behalf-Of` makes Atlas refuse the
lookup, and the banner reads "Unknown user". A transport or parse failure logs
and returns `nil`.

`view_as_target` fails closed. A miss yields a guest-shaped user with no groups,
who sees public material only. So a broken lookup can never render the admin's
own view under a view-as banner.

### The toggle surface

`Admin::ImpersonationsController` is only the toggle. The state machine and
hydration live in the concern.

| Action | Gate |
|---|---|
| `create_acting_as` | the inherited strict `require_admin` |
| everything else — `new`, `recipients`, `create_view_as`, `destroy` | `require_admin_or_delegate` |

Act-as stays `:admin`-only, even for a delegate who cleared the broader gate to
reach the controller. That matches the view: `_start.html.haml` renders the "Act
as" control for a full admin only. Atlas also gates acting-as, authorizing the
`On-Behalf-Of` header against the admin role. So the Cerberus gate is defense in
depth, not the only backstop. Atlas's devolved-admin grants include
`:create, AuditEvent`, which view-as needs for its session-start emit. They do
not touch on-behalf-of.

The controller skips `reject_writes_in_view_as`, because it manages the
impersonation session itself. Without the skip, the banner's Exit (a DELETE) and
a mode switch (a POST) would trip the guard and end the session with a
misleading message. `enforce_impersonation_ttl` and `set_impersonation_context`
still run.

`new` renders the NUID-entry start form, reached from the admin dashboard's
Impersonation card. That matches the other admin actions, such as Re-parent and
Linked members, which open onto their own page. `recipients` is the typeahead
JSON for the target picker, from `UserDirectorySearchable`. Atlas's directory
leaves out guest, anonymous and system users, and the requesting user. That
suits impersonation, which targets real people and never oneself.
`resolve_target` returns `nil` for a blank entry without calling Atlas.

## Depositor context

`DepositorContext` is the shared context for the curation surfaces: the deposit
fork in `WorksController`, and the two-space My DRS page in `MyDrsController`.
Both need the signed-in depositor's curated Person and the Collections they own.

`deposit_person` resolves the Person from the user's NUID
(`AtlasRb::Person.resolve`) and memoises it for the request. The Person is
authoritative for display name, affiliations, and `personal_root_id`, the
personal root that homes published works. It is `nil` for anyone without a
Person, which is most depositors, and then there is simply no publish branch. A
transport or parse failure also yields `nil` rather than blocking a workspace
deposit.

`workspace_collections` returns the Collections under that personal root, up to
`rows:` (200). It scopes by `ancestor_ids_ssim`, not by every collection the
user deposited into. Otherwise an admin who seeded the institutional tree would
"own" all of it. The Solr query is deliberately ungated, so a depositor's own
private collections stay visible. Results sort newest first on
`created_at_dtsi`, because a depositor reaches for the collection they just
made. Featured showcases and tombstoned rows are excluded. No personal root
means no workspace, and an empty list.

`publish_targets` keys publish destinations by community NOID:
`{ noid => { name:, genres: { label => showcase_noid } } }`. An empty hash hides
the publish branch entirely, so the `personal_root_id` check gates publishing.
Only the depositor's affiliated communities that have showcases appear, and
staff-only genres (`FeaturedContent::STAFF_ONLY`) are left out.
`community_name` falls back to the NOID when the lookup fails, so a stale
affiliation cannot break the deposit form.

`publish_showcase_id` resolves the showcase to promote into from the submitted
`publish_community_id` and `publish_genre`. It returns `nil` when the request
cannot be honoured: no curated Person, a community the depositor is not
affiliated with, a staff-only genre, or no showcase for that genre there.
`ShowcaseFinder` runs through the gated `SearchBuilder`, so a showcase the
depositor cannot see also reads `nil`.

`publish_showcase_id` does **not** check where the Work is going. The caller
must confirm separately that the destination is the depositor's own root before
offering promotion.
