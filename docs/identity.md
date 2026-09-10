# Identity

Who Cerberus thinks the current request belongs to. How a `User` is built at
sign-in, and what each role predicate gates. How discovery abilities follow from
it, and how an administrator acts or looks as somebody else.

Source files:

- `app/models/user.rb`
- `app/models/ability.rb`
- `app/lib/devise/strategies/custom_authenticatable.rb`
- `app/controllers/concerns/impersonation_session.rb`
- `app/controllers/admin/impersonations_controller.rb`
- `app/controllers/concerns/depositor_context.rb`

The ACL vocabulary these files gate on — the grant lists and the group
constants — is in [`docs/permissions.md`](permissions.md). The controller gates
that use the abilities described here are in
[`docs/authorization.md`](authorization.md).

## Building a user

`User` has no database table. It is an `ActiveModel` built per session from
Atlas's user lookup, carrying `email`, `nuid`, `name`, `groups`, `role` and
`affiliation`. `AtlasController#sign_in_from_atlas` calls
`AtlasRb::Authentication.login(nuid)`, builds the `User` from what comes back,
and hands it to Devise's `sign_in`.

`groups` is the identity-provider-asserted array. It is `nil` on the guest
fallback, which is why `User#member_of?` wraps it in `Array` before testing
membership. Group gates read as `member_of?(...)` rather than re-typing
`Array(...).include?(...)` at every call site.

### The Warden strategy

`Devise::Strategies::CustomAuthenticatable` backs
`devise :custom_authenticatable`. It inherits `Devise::Strategies::Authenticatable`,
which implements the underlying strategy logic, and is based on
[this gist](https://gist.github.com/madtrick/3917079).

Warden calls `authenticate!`. On success the strategy calls `success!` with an
instance of the model class Devise is configured with — `mapping.to`, the `User`
class. The strategy builds it from `authentication_hash`, which the base class
populates with the fields the login form submitted. On failure it calls `fail!`.

`credentials_valid?` returns `true`. Nothing is checked. The shape the source
records as intended is: take the NUID, send it to Atlas, and merge the returned
values into the authentication hash. That is not wired, and the sign-in path the
app actually uses builds the `User` in `AtlasController` instead.

### Displaying a name

`pretty_name` runs the stored name through Namae, which understands only
person-shaped names. A descriptive or organisational one — "Law Library Staffer"
— parses to nothing. The raw-name fallback is load-bearing. An empty display
name blanks the whole user block in the navbar, and that block holds Log Out. So
the only way out of the session was to clear it by hand.

## What each role predicate gates

| Predicate | Test | What it gates |
|---|---|---|
| `admin?` | `role == 'admin'` | Mirrors the Atlas-side role. Because `Ability` short-circuits on it, an Atlas admin drives admin-only UI without every Grouper group stuffed onto their record |
| `privileged?` | `role == 'privileged'` | Whether the deposit form renders the proxy ("upload as") radio. Group membership still selects *which* collections the user may deposit into |
| `messageable?` | not `guest` or `anonymous` | Inbox eligibility. The guest NUID is a shared fallback identity with no inbox of its own |
| `curates_sets?` | `messageable?` | Whether the user may own Sets. Sets share the inbox's human-role floor — one concept, two surfaces. Split the predicates if the floor ever diverges |
| `loader_tier?` | `loader`, `privileged` or `admin` | The loader surface: `LoadsController` and the My Loaders page and menu. *Which* loaders appear inside is `Loader.available_to`'s concern, per Grouper group |
| `admin_delegate?` | `privileged?` **and** `Permissions::ADMIN_GROUP` | The devolved-admin tier — a named subset of `Admin::BaseController` surfaces below the full `:admin` role's blanket access. See [`docs/admin.md`](admin.md) |
| `can_bypass_embargo?` | `admin?` or `Permissions::STAFF_EDIT_GROUP` | The only carve-out from an active embargo's download withholding |

Two of these are easy to get wrong.

`admin_delegate?` mirrors the Atlas-side Ability's identical role-and-group
pairing, and neither half alone is sufficient. It covers only the narrower
non-admin case, so call sites ask `admin? || admin_delegate?` — `:admin` always
short-circuits.

`can_bypass_embargo?` uses `STAFF_EDIT_GROUP` on the read side, which is not that
group's usual role. Elsewhere it is an always-on edit group; here it stands in
for "someone who can confirm this restriction is intentional".

## Discovery abilities

`Ability` decides `:read`, `:edit` and `:tombstone` on a `SolrDocument`.

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

`edit_equivalent?` is an ACL edit-group match **or** ownership.

Granting read from it is the fix for two ordinary states that otherwise locked a
person out of their own material. Those are a depositor who set their collection
Private with no group rows, and a group granted Manage but not View. Both kept
the Edit page and got a 403 on the object itself.

It cannot widen disclosure, because it only admits people who could already
alter the thing. Atlas says the same of Sets — edit implies read. Its read floor
admits any authenticated principal, so nothing here outruns what the backend
will serve.

Ownership has to be tested separately because the ACL does not represent it. A
personal root and everything beneath it carries `edit: [repository:staff]` with
the owner recorded only as `depositor`. This mirrors Atlas's edit-equivalent
grant, and divergence shows up as Cerberus hiding an Edit link for a write Atlas
would allow.

`:restore` is deliberately not one of these verbs. Reversing a tombstone is an
operator action, not an owner one.

### Ownership and proxy deposits

`depositor?` is not Work-scoped, because a depositor owns their Collections too.
The whole workspace subtree inherits their NUID, since creators copy
`parent.permissions` and that carries `depositor`. A Collection they own is
theirs to edit and, once empty, to withdraw. Emptiness needs no check here —
Atlas refuses the tombstone while live children remain.

`proxy_uploader?` applies to Works only. A librarian who proxied a deposit keeps
tombstone rights on it: the recorded `proxy_uploader` retains authority, not just
the on-behalf-of depositor.

## Impersonation

`ImpersonationSession` is included into `ApplicationController`, so it governs
every request — an impersonating administrator browses the whole app, not just an
admin surface. Its two modes are mutually exclusive and both admin-only.

| Mode | Authenticated identity | Effect | Writes |
|---|---|---|---|
| acting-as | stays the admin (`Current.nuid`) | `Current.on_behalf_of` is set to the target, so atlas_rb writes carry `On-Behalf-Of: <target>` via the default on-behalf-of callable. Atlas authorizes the admin and stamps the target as provenance | allowed, and attributed to the target |
| view-as | untouched | sets `view_as_nuid`, which drives `effective_user` — the single user both `Ability` and `SearchBuilder` consult | rejected |

Session state lives in the Rails session cookie with a 30-minute sliding
inactivity TTL (`IMPERSONATION_TTL`). `enforce_impersonation_ttl` runs on every
request and either expires the session or refreshes the clock. Every termination
path funnels through `end_impersonation`.

`impersonation_target` hydrates whichever target is set, for the banner's name
and NUID display, and is `nil` when there is no session or hydration fails.

### Ordering, and the audit trail

`start_acting_as` and `start_view_as` emit the `impersonation_started` audit
event **before** establishing the session, so an admin can never impersonate
without a trail. A failed emit raises a Faraday error and no session is set;
`ImpersonationsController` rescues it into a flash and a redirect rather than a
500.

`end_impersonation` inverts that order: it tears the session down first and then
emits `impersonation_ended` best-effort, logging a failure. The rescue covers
`AtlasRb::Error` as well as `Faraday::Error`, because a refusal Atlas states in
an HTTP response is still a failed emit. A read-only maintenance window is the
case that proves it. The session is already gone by that point. So letting
`AtlasRb::ReadOnlyModeError` escape would land the admin on the maintenance page
and tell them an exit failed that had in fact succeeded.

`emit_impersonation_event` records a session-scoped `AuditEvent` — there is no
resource to hang it on — through atlas_rb's emit binding. It passes the admin as
`actor_nuid` explicitly. The gem uses that value as the `User:` header and as the
recorded principal. So the admin gate still holds on an `impersonation_ended`
emit fired mid-teardown.

### Context plumbing

`set_impersonation_context` pushes the impersonation state into `Current` after
`ApplicationController#set_current_nuid` has set the admin identity.
`Current.on_behalf_of` drives write attribution. `Current.view_as_nuid` is
read-only bookkeeping; `effective_user` is its real consumer.

### Rejecting a write under view-as

`reject_writes_in_view_as` ends the session loudly on any non-GET, non-HEAD
request, rather than silently performing or silently dropping the write.

"Loudly" needs help when the write came from inside a turbo-frame — the My DRS
token panel is one. Turbo looks for that frame in the redirect's target, does not
find it on the root page, and discards the entire response. That means no token,
no error, no flash, and the banner still showing until the next navigation. The
button looks simply dead, so an admin may keep pressing it while no longer
impersonating anyone.

The reply to a turbo-frame request is therefore a turbo-stream refresh. A
turbo-stream is honoured whatever frame the request came from, and a refresh
re-renders the page, which surfaces the flash and drops the banner.

### Hydrating a target

`hydrate_user` builds a `User` from the same Atlas user lookup SSO sign-in uses —
there is no database to read. It suppresses `Current.on_behalf_of` for the
duration, because this is a plain profile lookup and not an on-behalf-of
operation. A hydration failure logs and returns `nil`.

`view_as_target` fails closed: a miss yields a public-only guest-shaped user, so
a broken lookup can never render the admin's own view under a view-as banner.

### The toggle surface

`Admin::ImpersonationsController` is only the toggle; the state machine and
hydration live in the concern.

| Action | Gate |
|---|---|
| `create_acting_as` | the inherited strict `require_admin` |
| everything else — `new`, `recipients`, `create_view_as`, `destroy` | `require_admin_or_delegate` |

Act-as stays `:admin`-only even for a delegate who cleared the broader gate to
reach the controller, which matches the view. `_start.html.haml` renders the "Act
as" control for a full admin only. Atlas gates acting-as server-side too,
authorizing the `On-Behalf-Of` header against the admin role. So the Cerberus
gate is defense in depth rather than the only backstop. Atlas's own
devolved-admin grant opens `:create AuditEvent` for the session-start emit that
view-as needs, and does not touch on-behalf-of or acting-as at all.

The controller skips `reject_writes_in_view_as` because it manages the
impersonation session itself. `enforce_impersonation_ttl` and
`set_impersonation_context` still run.

`new` renders the NUID-entry start form, reached from the admin dashboard's
Impersonation card. That matches the other admin actions — Re-parent, Linked
members — which open onto their own page. `recipients` is the typeahead JSON for
the target-user picker, from `UserDirectorySearchable`. That directory's role
exclusions are apt here too, since impersonation targets real human users and
never the self, system or anonymous principals. `resolve_target` returns `nil`
for a blank entry without calling Atlas.

## Depositor context

`DepositorContext` is the shared context for the curation surfaces: the weighted
deposit fork in `WorksController`, and the two-space My DRS page in
`MyDrsController`. Both need the signed-in depositor's curated Person and the
Collections they own.

`deposit_person` resolves the Person from the user's NUID and memoises it for the
request. The Person is authoritative for display name, affiliations, and
`personal_root_id` — the personal root that homes published works. It is `nil`
for anyone without a Person, which is most depositors, and simply means no
publish branch. A resolution failure degrades to `nil` rather than blocking a
workspace deposit.

`workspace_collections` returns the Collections under that personal root. They
are sorted newest first over Valkyrie's own record timestamp, because a depositor
reaches for the collection they just made. Featured showcases and tombstoned
rows are excluded. No personal root means no personal workspace, and an empty
list.

`publish_targets` keys publish destinations by community NOID:
`{ noid => { name:, genres: { label => showcase_noid } } }`. Only the depositor's
affiliated communities that actually have showcases appear, and only when the
Person carries a `personal_root_id`. `community_name` degrades to the NOID when
the lookup fails, so a stale affiliation cannot break the deposit form.

`publish_showcase_id` resolves the showcase to promote into from the submitted
community and genre. It returns `nil` when the request cannot be honoured. That
covers no curated Person, a community the depositor is not affiliated with, or
no showcase for that genre there. The showcase lookup is gated, so one the
depositor cannot see reads `nil` as well.
