# Edit surfaces

This page covers the tab set on every resource edit page, the audit rows those
pages render, and the typed associations between Works. It also covers the
shared `#update` that the edit forms PATCH.

Source files:

- `app/controllers/concerns/atlas_resource_type.rb`
- `app/lib/descriptive_policy.rb`
- `app/helpers/edit_tabs_helper.rb`
- `app/views/shared/_edit_tabs.html.haml`
- `app/helpers/audit_events_helper.rb`
- `app/controllers/concerns/transformable.rb`
- `app/services/work_associations.rb`
- `app/helpers/work_associations_helper.rb`
- `app/controllers/admin/associations_controller.rb`

## Adding a tab to an edit page

Add one entry to `EditTabsHelper::TABS`, then add the pane to that class's edit
view. Nothing else is needed.

`TABS` is the single declaration of which tabs a Work, Collection or Community
edit page offers, in what order. `shared/_edit_tabs` renders it. The edit pages
and the standalone XML editor both use that partial.

It is one declaration so that no copy can drift. Four hand-kept lists — the
three edit views and the XML editor's mirror — had nothing coupling them, and
the XML editor's row went stale silently each time a tab was added.

Order and membership are data, so a class-specific tab needs no conditional.
Advanced, Move and Delete are Work-only; Derivative access and Export are
Collection-only; Analytics is container-only. Each follows purely from which
arrays list it.

A Work's Analytics is a tab on its *show* page, offered to editors, and is not
part of `TABS`. See `docs/analytics.md`.

A key doubles as the pane's DOM id (`#<key>`) and its tab button's id
(`<key>-tab`). It must match the `.tab-pane` id in the edit view.

### The three tables

| Constant | Holds |
|---|---|
| `TABS` | Per-class tab keys, in display order |
| `LABELS` | The label for a key whose label is not the key humanized — a genuine exception such as the acronym XML |
| `STANDALONE` | Tabs that navigate to their own page instead of switching an in-page pane |

`edit_tab_label` swaps hyphens for spaces before humanizing, so a hyphenated key
such as `derivative-access` needs no `LABELS` entry. `String#humanize` alone
turns only underscores into spaces.

`edit_tab_keys(klass)` returns the keys this viewer may see, in display order.
`klass` is the String `'Work'`, `'Collection'` or `'Community'`.

`edit_tab_standalone_path(key, id)` says where a standalone tab points. XML is
the only one, so the method returns `xml_editor_path(id)` and raises
`ArgumentError` for any other key. A second standalone tab adds a branch to that
method rather than a path-guessing convention.

### Which pane opens

`edit_tab_open_key(klass, open:)` decides. The tab row and the panes both ask
it, so they cannot disagree.

`open` names a pane explicitly, because a re-render needs it. A rejected save
must come back on the tab the reader was working in, and the URL fragment cannot
carry that. Turbo follows a redirect with `fetch`, and the Fetch spec drops the
fragment from the resolved URL. The `Location` header carries the fragment, but
the browser never sees it.

An unknown, hidden or standalone key falls back to the first in-page pane rather
than opening nothing.

### Who may see a tab

`edit_tab_visible?(key)` holds only the *user*-dependent gates. `TABS` holds the
class-dependent membership. History needs `can?(:read, :audit_event)`; Export
needs a loader tier (`current_user.loader_tier?`).

The edit view's pane calls the same predicate instead of re-testing the
ability, so each gate is declared exactly once.

## Rendering an audit row

`AuditEventsHelper` is the shared formatting for audit-event rows. Each
per-action partial, such as `_event_create.html.haml`, renders one row of cells
through these helpers. The partials vary only the row's `audit-event--<tone>`
class.

`audit_events/_history` picks the partial `_event_<action>` and falls back to
`_event_generic`. So a new action type is a new partial, not a `case` edit.
These helpers are the scaffolding around that variation, not the variation
itself.

### The row's cells

| Helper | Cell |
|---|---|
| `audit_event_timestamp` | Date stacked above time, with the full ISO timestamp in the `title`. CSS supplies `tabular-nums`, so digits align down the column even though Bootstrap's body font is not monospace |
| `audit_event_action_badge` | The action chip: a tinted soft badge holding icon and label, and the row's main colour signal. The `audit-event--<tone>` class sets `--audit-action-color` on the row, and that drives the chip's colours, so a partial never repeats the colour. The left rail reinforces the chip for scanning the column |
| `audit_event_detail_cell` | The change\_type label plus the payload summary. They sit in their own column so they left-align across rows; after a variable-width action chip they would not. A muted em-dash holds the column when an event carries neither |
| `audit_event_who` | The actor, and — only in the rare proxy or acting-as case — a muted "for &lt;target&gt;" beneath it. `on_behalf_of_nuid` is empty on nearly every row, so a dedicated column would waste width, and actor and target are the same kind of fact anyway |
| `audit_event_view_cell` | The per-row "View" button, or nothing, which leaves an empty aligned cell |

`audit_event_nuid` renders a NUID as a monospace pill that reads as an
identifier rather than as body text. A blank NUID renders as a muted em-dash.

`audit_event_actor` puts the person's name before that pill, as the inbox
sender cell does. A ledger that answers "who did this" with `000000003` answers
it only for a reader who can read NUIDs. The name carries the meaning, and the
pill keeps the identifier to hand for a ticket.

`NuidResolver` echoes the NUID back when the directory has no name, for the
anonymous and system principals and for departed users. `audit_event_actor`
then renders the pill alone, so the digits do not print twice.

Each `NuidResolver.name_for` call is a `Rails.cache` read. `_history` primes the
whole table's NUIDs with one `NuidResolver.names_for` batch first, so the row
reads are cache hits rather than a request per NUID.

### The action and change\_type vocabularies

`ACTION_DESCRIPTORS` maps an action to a colour tone, a Font Awesome icon and a
display label. An action it does not know renders with `GENERIC_ACTION` and the
humanized verb, rather than raising or rendering an empty chip.

`release_embargo` is a lapse the nightly job records. A person clearing an
embargo early writes an `update` row instead, and the two labels must not read
alike.

`CHANGE_TYPE_LABELS` supplies the quiet secondary qualifier. It is an uppercase
micro-label rather than a second chip, because a second box would compete with
the action chip. It renders on every row that carries a change\_type. It matters
most on `update`, where one verb covers both a metadata edit and a permissions
change. The `audit-event__change-type--<change_type>` modifier stays as a
semantic and styling hook, notably for permissions.

### Where "View" points

`audit_event_view_path` returns a path or nil.

| change\_type | Action | Destination |
|---|---|---|
| `permissions` | `create` or `update` (`PERMISSION_VIEW_ACTIONS`) | The Rights-history diff page, `rights_history_path` |
| `metadata` | `update` | The MODS-history diff page, `mods_history_path` |
| anything else | any | nil — the column renders an empty cell and stays aligned |

Both permission actions carry a before/after snapshot. `create` is the initial
grant, which Atlas's service objects emit, and `update` is every later ACL
change. Atlas suppresses no-op permission writes, so each event is a real
transition worth a page. `HistoriesController#permission_events` filters on the
same `PERMISSION_VIEW_ACTIONS`.

Every metadata update writes a new `descMetadata.xml` OCFL version, so every
one gets a MODS-diff link. That covers a full MODS upload (`{ source: 'mods' }`)
and a title or description field patch (`{ fields: }`) alike. Atlas's
`plain_title=` and `plain_description=` edit the MODS document and call
`mods_xml=` too, in `MODSAssignment`. The MODS document's `create` row has no
earlier version to diff against, so the link is update-only.

Both links pass the event's `occurred_at` as `at:`, and each page uses it to
find the event:

- The Rights page shows one permission event per page.
  `HistoriesController#page_for` picks the page holding the event whose
  `occurred_at` matches. The link also carries an anchor from
  `audit_event_dom_id`, which derives it from the timestamp. The timestamp is
  unique per resource, so the entry is styled via `:target`.
- The MODS page picks the OCFL version whose `created` time matches `at`
  (`HistoriesController#anchored_version_id`), and diffs it against the version
  before it.

This is the v2 successor to v1's per-object Rights and MODS History pages.

### Payload summaries

`audit_event_payload_summary` derives a one-line summary from the payload, by
action. The shapes mirror what Atlas emits:

| Action | Payload | Summary |
|---|---|---|
| `update` | `{ fields: [...] }` | the field names, joined |
| `update` | `{ source: 'mods' }` | "MODS document", plus "via &lt;surface&gt;" when the event has an origin |
| `update` | `{ before:, after: }` | an ACL or rendition-gate diff |
| `reparent` | `{ to: noid }` | "moved to &lt;noid&gt;" |
| `link_member` | `{ collection: noid }` | "to &lt;noid&gt;" |
| `unlink_member` | `{ collection: noid }` | "from &lt;noid&gt;" |
| `create`, `tombstone`, `restore` | none | none; the category label stands alone |
| `release_embargo` | `{ release_date: }` | none; the row's own timestamp is the release day |

`update_payload_summary` matches `source` exactly, not merely for presence.
Atlas uses that slot for several unrelated things on an `update` row, and
treating any of them as the MODS marker labels a rendition-gate change "MODS
document".

`acl_diff_summary` prints the grants added and removed on each `ACL_DIFF_KEYS`
slot (`read`, `edit`, `edit_users`) — `read +public · edit −staff +editors`. It
appends "Embargo set", "Embargo removed" or "Embargo updated" when the embargo
moved. The embargo stays out of `ACL_DIFF_KEYS`, because every renderer there
treats a value as a set of group tokens, and an embargo is a single date.

`tier_diff_summary` prints the same grammar per download tier —
`large −public +staff` — because both are group grants moving on and off a slot.

### Which surface made a MODS upload

Several Cerberus writers send a full MODS document through
`AtlasRb::Resource.put_mods`. Three are editing surfaces: the simple Metadata
form, the Advanced tab and the raw XML editor. The first two merge into the
stored document through `AtlasWrite#merge_mods!`; the XML editor replaces it
wholesale. A curator reading the audit log needs to know which one an entry
came from.

Each writer tags its own write with an `origin:` keyword, and Atlas records the
string verbatim beside `source` in the payload:

| Surface | Write site | Tag |
|---|---|---|
| Metadata form | `DescriptiveMetadata#save_descriptive!` | `metadata_form` |
| Advanced tab | `AdvancedMetadata#save_advanced!` | `advanced_form` |
| Raw XML editor | `XmlController#update` | `xml_editor` |
| Deposit, titling a new Work from its filename | `WorkDeposit#finalize_new_work` | `deposit` |
| XML loader, replacing an existing Work's document | `XmlIngestJob#update_work` | `xml_loader` |

The deposit row is not a form. It is the write that titles a new Work before
its depositor has seen the metadata page. It takes its own tag so the audit log
does not show a Metadata form edit that nobody made.

`AuditEventsHelper::ORIGIN_LABELS` maps each tag to the text the row shows.
`origin_label` humanizes a tag the map does not know rather than dropping it.
Atlas never branches on the value, so a new surface needs no Atlas change.

The renderer must tolerate an absent origin. Two kinds of event have none:
every row written before the field existed, and the system write that sends
no tag: `ShowcaseProvisioner` passes `origin: nil`. Atlas omits the key rather than sending it empty,
so those rows fall back to the bare "MODS document".

### The two permission payloads

A permissions event describes either the resource ACL or the per-rendition
download gate. Atlas tags the gate change with `source:
'derivative_permissions'` (`DERIVATIVE_PERMISSIONS_SOURCE`). The two share a
change\_type and an action, so the payload's `source` is the only thing that
tells them apart. Both the audit-log summary and the Rights page check it,
through `derivative_permissions_payload?`, before reading either shape. The
gate's before and after are a sparse `{ tier => [read groups] }` map, not an
ACL envelope.

`derivative_tier_rows` lists only the tiers that either side of the diff
mentions, in `Sentinel::TIERS` narrowing order. The stored policy is sparse —
only gated tiers appear — so listing all eight would bury the change under empty
rows. A tier `Sentinel::TIERS` does not know sorts last rather than vanishing,
so a tier Atlas adds before Cerberus does still shows.

`TIER_LABELS` gives the tiers prose names. The vocabulary and its narrowing
order come from `Sentinel::TIERS`, which is where Cerberus authors these
policies; naming the ladder twice would let the two drift. `tier_label` falls
back to the humanized token.

### The Rights-history diff page

`ACL_LEVEL_LABELS` and `acl_level_label` give the ACL slots prose names for the
two-column before/after view. The audit-log summary uses the bare key; the full
page reads better with prose.

`acl_grant_pills` renders one slot's grants as monospace identifier pills,
reusing the audit log's NUID-pill style. Grants listed in `marked:` get the
`state:` tint. The view uses that to flag the added grants in the after column
and the removed grants in the before column. An empty slot renders a muted
em-dash.

`EMBARGO_KEY` names the embargo slot in the same permissions snapshot. An
embargo is a rights decision a person makes and revises — withholding downloads
until a chosen date — so it belongs in the rights diff, but not in the pill
style. `embargo_diff_cell` tints it with the same state classes as the pills
but renders it as plain text, as a spelled-out date. A date is a value, not an
identifier, and the monospace pill style is reserved for things you could paste
into a lookup.

`embargo_recorded?` keeps the embargo row off the page when neither side has
one, because "None → None" reads as a change. `embargo_changed?` compares
through `presence`, because "no embargo" arrives as nil, `''` or an absent key
depending on how the resource was created.

`embargo_date` turns a blank or unparseable value into "no embargo" rather than
raising mid-table, because the payload is a remote snapshot.

### The version picker

`mods_version_options` builds the `<option>` list for the MODS-history version
picker. Each option's label joins the OCFL version id, a compact timestamp and
the actor NUID with middots. The value is the version id. The actor may be
blank, and a missing or unparseable timestamp drops out of the label, so the
option still reads cleanly.

## Declaring the resource type

Each resource controller states which Atlas type it edits, once, in its class
body:

```ruby
class WorksController < ApplicationController
  atlas_resource AtlasRb::Work, key: :work, route: :work
end
```

`WorksController`, `CollectionsController` and `CommunitiesController` declare
one. `AtlasResourceType` turns the declaration into four readers the shared
concerns use:

| Reader | Answers |
|---|---|
| `atlas_class` | Which `AtlasRb::*` class to call |
| `resource_key` | The strong-params and form key |
| `show_path(id)` | The resource's own page (`<route>_path`) |
| `edit_path(id)` | Its edit page (`edit_<route>_path`) |

`solr_type` is a fifth reader, derived rather than declared:
`atlas_class.name.demodulize`. It is the type name Atlas writes into
`internal_resource`, which the Solr documents CanCan gates on carry.
`Authorizable` puts it into the synthetic `SolrDocument` for the tombstone gate
and for the show page's Edit and Delete links (`assign_show_abilities!`).
`Transformable` hands it to `ResourcePermissions`, and the tombstone notice
names it.

The private `parent_path(id)` says where to land once the resource is gone.
Read it *before* a tombstone, because the withdrawn resource's own read is
gated. A failed read or a top-level resource falls back to the home page.

### Why all three arguments are stated

A macro cannot derive `key:` or `route:` from the class name. The Atlas
vocabulary and the UI vocabulary diverge on purpose: Atlas's `Compilation` is
the UI's Set, `SetsController`, `set_path`. A convention that holds for Work,
Collection and Community breaks on the fourth type. It breaks by resolving the
wrong constant or route, not by raising.

`solr_type` must follow Atlas's vocabulary for the same reason, in the other
direction. Deriving it from the route or the params key would make a Set's gate
read `Set` when its Solr document says `Compilation`. `Ability` compares that
string, so a mismatch evaluates the wrong rule instead of failing.

`atlas_class` raises `NotImplementedError` by default. A Ruby module cannot
force an includer to declare anything. Without the raise, a controller that
mixes in the edit concerns and forgets the declaration fails deep inside a
metadata save rather than on its first request.

### What stays an argument

A declaration answers what varies by *type*. An argument answers what varies by
*call*.

So `include_advanced:` stays a keyword argument to `handle_metadata_update`.
`WorksController#update` and `#update_metadata` share the controller and the
type. They differ only in whether the form rendered the Advanced field set
inline. No declaration can answer that.

`AtlasWrite` needs no declaration at all. `merge_mods!` reads and writes MODS
through `AtlasRb::Resource`, whatever the resource type. That is what lets
`ShowcaseProvisioner` and `ResourcePermissions`, which are services, include the
module beside the controller concerns.

### The keyword rule is policy, not identity

`DescriptivePolicy.keywords_required?` decides whether a form must carry at
least one keyword. Works must; containers need not. The container forms have no
Keywords box, so requiring one there would make a title-only edit unsaveable.

It looks like a fourth fact for the declaration, and it is not. It is a DRS
editorial rule that a Cerberus form validator enforces; Atlas accepts a MODS
document either way. So it sits in `app/lib/`, beside `app/lib/permissions.rb`,
which holds the other Cerberus-only rules. Putting it in the declaration would
flatten a policy into a row of identity facts, and invite the next reader to
take it for a MODS constraint.

## The shared `#update`

`Transformable` is the `#update` entry point for the Metadata, Permissions and
Advanced tabs of Works, Collections and Communities. They are separate forms
that all PATCH the same action with disjoint fields. `Transformable` includes
`AtlasResourceType`, `AtlasWrite`, `PermissionsForm`, `DescriptiveMetadata` and
`AdvancedMetadata`.

Each included piece owns one half of a job. `PermissionsForm` parses and
presents the permissions form, and `ResourcePermissions` writes it.
`DescriptiveMetadata` and `AdvancedMetadata` decide *which* MODS fields a form
owns. `AtlasWrite#merge_mods!` is the read-merge-write spine both of them call:
it retries a lost lock race and skips a no-op write. What is left in
`Transformable` is the routing between them.

`handle_metadata_update` runs in this order:

1. If the Advanced tab submitted, it calls `save_advanced!` and redirects. Nothing
   else runs.
2. Otherwise it applies permissions (`apply_permissions`) and the thumbnail.
3. If no descriptive fields were submitted, it redirects to the show page.
4. Otherwise `apply_descriptive` validates the descriptive fields, including
   keywords where `DescriptivePolicy` requires them. It merges them into the
   existing MODS and writes the result.

`WorksController#update` then runs the Work-only extras that ride the Metadata
and Permissions forms: Streaming Only, captions and the Showcase category
(`WorkShowcaseCategory`, see `docs/discovery.md`).

`advanced_submitted?` and `include_advanced:` mean opposite things, and must
not be confused. The first reads the Advanced **tab's** own hidden marker
(`form: 'advanced'`), which says "the advanced fields and nothing else", and
short-circuits to `save_advanced!`. The second is a caller's statement that the
form it rendered carries the advanced fields **inline, beside** the descriptive
ones — the deposit page. Both sets then fold into one `save_descriptive!` and
one MODS write. It is a keyword argument rather than another params check
because the two signals look alike. Reading the wrong one would make a deposit
submit skip its keywords, permissions and confirmation. See `docs/deposit.md`.

`resource_mods` reads the resource's raw MODS once per request. Both form
loaders parse the same document: `DescriptiveMetadata` for the bare title,
abstract and keywords, and `AdvancedMetadata` for the structured title parts and
names. The Work edit page runs both, so without the memo it would fetch the same
XML from Atlas twice. The memo is for reads only. `merge_mods!` re-reads inside
`with_stale_retry`, because a retry needs the current MODS and its lock token.

### The two ACL writes

`apply_permissions` is the edit path and `apply_new_permissions` is the create
path. `apply_permissions` passes the resource's current read groups and
embargo, which the authorization gate loaded into `@permissions`, so
`ResourcePermissions` can tell whether the submit narrows.
`apply_new_permissions` passes neither. Straight after a create, `@permissions`
still holds the *destination's* envelope, which would answer the wrong
question.

`report` turns whichever `Result` comes back into a flash. It does nothing when
the result carries no level. See `docs/permissions.md` for what
`ResourcePermissions` decides.

## A Work's typed associations

An association is a directed claim that one Work is the codebook, figure,
transcription, instructional material or supplemental material *for* another.

The edge is stored once, on the Work that asserts it, and Atlas derives the
other direction. So one Work's `outbound` is another's `inbound`, and the two
can never disagree.

Two surfaces read those edges, and they resolve titles differently on purpose.

| Surface | Resolves noids through | Because |
|---|---|---|
| The public association box (`WorkAssociations`) | The gated Blacklight search | A viewer must not learn that a Work they cannot see exists |
| The admin panel (`Admin::AssociationsController`) | `AtlasRb::Resource.find_many` | A management surface must show every edge, including one to a tombstoned Work. The gated search drops that Work, and the edge would then be unremovable |

Atlas gates a delegated admin's reads by group, so on the admin panel
`find_many` can drop a Work that admin cannot read. `titles_for` then shows the
bare NOID, and the edge stays removable.

### The public box

`WorkAssociations` resolves Atlas's edges to the Solr documents the viewer may
see. It takes one Solr query to cover both directions and every predicate,
however many edges a Work has.

Atlas answers with noids, and that is what makes this safe. Atlas's association
endpoint is ungated: it reports every edge, including edges to Works the viewer
must not see. Resolving those noids through the gated search reduces the list
to the rows this viewer may have. A noid that resolves to no document does not
render, and leaves no trace: no group heading, no count, no "1 item hidden".
Each of those would confirm the record exists. The same lookup drops tombstoned
Works for free, since `-tombstoned_bsi:true` sits in the catalog's
`default_solr_params`.

`search` adds its filter with `with_filters`, not a merged `:fq`. Merging `:fq`
drops the gated-discovery clause the search builder adds, which is the whole
protection this class depends on. `SetResolver#search` uses the same plumbing.

`initialize` takes two arguments:

- `associations:`, Atlas's reply from `AtlasRb::Work.associations`, in the shape
  `{"outbound" => {predicate => [noid]}, …}`
- `search_service:`, the controller's `search_service`, which supplies the
  gated search builder

`Result` holds one Hash of predicate to documents per direction. The predicates
follow `AtlasRb::Work::ASSOCIATION_TYPES` order rather than Atlas's hash order,
so the box lists its groups the same way on every Work. Documents within a group
sort by title. `Result#size` counts every document across both directions, so a
jump-link count matches what actually renders.

`noids` deduplicates every noid Atlas named across both directions. One Work
can be both the transcription of a Work and a figure for it, and a cycle
between two Works is permitted and meaningful.

`documents_by_noid` keys the gated lookup by bare noid. Solr stores the noid in
`alternate_ids_ssim` as `id-<noid>`, and `search` uses the same `{!terms}`
shape as `SetResolver#noun_uuids`.

### The labels

`WorkAssociationsHelper::ASSOCIATION_LABELS` holds every phrasing. The
predicate is Atlas's wire token; the phrasing is Cerberus's. One stored edge
reads three ways, so each predicate carries three phrasings and an icon:

| Key | Where it appears | Example |
|---|---|---|
| `outbound` | A heading on the asserting Work | "Is codebook for" |
| `inbound` | A heading on the target Work | "Codebooks" |
| `assertion` | The tail of a sentence in the form | "codebook for" |

They live in one table, as `AuditEventsHelper` holds its action descriptors, so
adding a predicate is one entry rather than three edits in three files.
`association_label` humanizes a predicate the table does not know, because
Atlas can ship a new predicate before Cerberus has a phrase for it.

Icons come from the restrained Font Awesome solid set the rest of the site uses,
chosen for the *kind of thing* the associated Work is. There is deliberately no
colour per predicate. A relationship is a label, not a status, and a
five-colour legend would outrank the Embargoed and Incomplete pills, which do
carry status.

`association_type_options` builds the form's predicate select from
`AtlasRb::Work::ASSOCIATION_TYPES`, not from the label table, so it can only
offer a predicate Atlas accepts. `PICKER_ORDER` puts the most-used first.

`association_direction_caption` supplies the manage panel's heading for each
direction.

### The admin panel

`Admin::AssociationsController` manages the edges.

| Action | Does |
|---|---|
| `index` | Search for the Work to manage |
| `manage` | Show its edges in both directions, plus a search to assert a new one |
| `add` | POST an edge, then return to `manage` |
| `remove` | DELETE an edge, then return to `manage` |

Nothing moves in the containment tree and no permissions change. An
association is descriptive.

It is open to admins and the devolved tier, the two that Atlas grants the
write, through `require_admin_or_delegate`. It is not an `:edit` check: the
claim renders on the *target's* page too, and the asserter often holds no rights
over it. That is stricter than "descriptive" suggests. It is also why this is an `/admin/*` surface rather
than a tab on the Work edit page: a tab would be dead chrome for every depositor
and editor who could reach it.

`add` writes from the picked Work toward the managed one. Staff start from the
primary Work and pick the Work that supports it, but the edge is stored on the
supporting Work, which asserts it. So `add` sends the picked Work as Atlas's
`work` and the managed Work as its `target`. The swap also reverses Atlas's
two tombstone codes, which `REFUSALS` phrases accordingly. To assert the reverse
claim, manage the other Work.
`remove` takes `holder_id` explicitly, so one panel can retract either
direction. An admin can do that because they hold rights on both ends.

`manage` passes `exclude_node_uuid` to `ResourceSearch`. That keeps the managed
Work out of its own candidate list, and heads off Atlas's `self_association`
refusal at the point of choice.

`REFUSALS` phrases Atlas's 422 codes on an association write in the admin's
terms, keyed on the `AtlasRb::WorkAssociationError#code`. The vocabulary is
atlas\_rb's; the wording is Cerberus's. An unknown code falls back to
`GENERIC_REFUSAL`. A `Faraday::Error` is logged by `log_failure` and also shown
as `GENERIC_REFUSAL`.
