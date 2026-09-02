# Edit surfaces

The tab set every resource-edit page offers, the audit rows those pages render,
the typed associations between Works, and the shared `#update` that all the
edit forms PATCH.

Source files:

- `app/helpers/edit_tabs_helper.rb`
- `app/helpers/audit_events_helper.rb`
- `app/controllers/concerns/transformable.rb`
- `app/services/work_associations.rb`
- `app/helpers/work_associations_helper.rb`
- `app/controllers/admin/associations_controller.rb`

## Adding a tab to an edit page

Add one entry to `EditTabsHelper::TABS`, then add the pane itself to that
class's edit view. Nothing else.

`TABS` is the single declaration of which tabs a Work, Collection or Community
edit page offers, in what order, and who may see each one. `shared/_edit_tabs`
renders it, and both the edit pages and the standalone XML editor use that
partial.

It is one declaration because it was once four — the three edit views plus the
XML editor's hand-mirrored copy — with nothing coupling them. The XML editor's
row went stale silently every time a tab was added: it was missing Derivative
access, Export and Analytics, and it put XML in the wrong position for
containers.

Order and membership are data, so a class-specific tab needs no conditional
anywhere. Analytics is container-only, and Advanced, Move and Delete are
Work-only, purely because of which arrays list them.

### The three tables

| Constant | Holds |
|---|---|
| `TABS` | Per-class tab keys, in display order |
| `LABELS` | The label for a key that is not the key humanized — a genuine exception such as an acronym, not merely a hyphenated key |
| `STANDALONE` | Tabs that navigate to their own page instead of switching an in-page pane |

`edit_tab_keys(klass)` returns the keys this viewer may see, in display order.
`klass` is the String `'Work'`, `'Collection'` or `'Community'`.

`edit_tab_standalone_path(key, id)` says where a standalone tab points. XML is
the only one today. A second standalone tab joins that method's `case` rather
than growing a path-guessing convention.

### Which pane opens

`edit_tab_open_key(klass, open:)` decides. The tab row and the panes both ask
it, rather than each deciding for itself, so they cannot disagree.

`open` names a pane explicitly. A re-render needs that: a rejected save must
come back on the tab the reader was working in, and it cannot rely on the URL
fragment, because Turbo follows a redirect with `fetch` and the Fetch spec drops
the fragment from the resolved URL. The `Location` header carries the fragment
and the browser never sees it.

An unknown or hidden key falls back to the default rather than opening nothing.

### Who may see a tab

`edit_tab_visible?(key)` holds the *user*-dependent gates only. Class-dependent
membership is `TABS`. History needs `can?(:read, :audit_event)`; Export needs a
loader tier.

The edit view's pane shares this predicate instead of re-testing the underlying
ability, so each gate is declared exactly once.

## Rendering an audit row

`AuditEventsHelper` is the shared formatting for audit-event rows. Each
per-action partial — `_event_create.html.haml` and its siblings — renders one
row of cells through these helpers and varies only the row's
`audit-event--<tone>` class.

Adding a new action type is a new partial, not a `case`-statement edit. These
helpers are the scaffolding around that variation, not the variation itself.

### The row's cells

| Helper | Cell |
|---|---|
| `audit_event_timestamp` | Date stacked above time, full ISO in the `title`. CSS supplies `tabular-nums`, so digits align column to column even though Bootstrap's body font is not monospace |
| `audit_event_action_badge` | The action chip: a tinted soft-badge holding icon and label, and the row's primary chromatic signal. `--audit-action-color`, set on the row by the `audit-event--<tone>` class, drives its colours, so a per-action partial never repeats the colour. The left rail reinforces the chip for at-a-glance column scanning |
| `audit_event_detail_cell` | The change\_type category label plus the payload summary, in their own column so they left-align across rows. Trailing a variable-width action chip they would not. A muted em-dash holds the column when an event carries neither |
| `audit_event_who` | The actor NUID pill, and — only in the rare proxy or acting-as case — a muted "for &lt;target&gt;" beneath it. On-behalf-of is null on the overwhelming majority of rows, so a dedicated column was pure horizontal tax, and actor and target are the same kind of fact anyway |
| `audit_event_view_cell` | The per-row "View" button, or an empty aligned cell |

`audit_event_nuid` renders a NUID as a monospace pill that reads as an
identifier rather than as body copy. A blank NUID renders as a muted em-dash
placeholder.

`audit_event_actor` stacks the name above that pill, mirroring the inbox sender
cell. A ledger that answers "who did this" with `000000003` answers it only for
a reader who can read NUIDs: the name carries the meaning and the chip keeps the
identifier to hand for a ticket. Each call is a `Rails.cache` read, and the
history view primes a page's NUIDs with one `NuidResolver.names_for` batch, so
these are hits rather than a request per row.

### The action and change\_type vocabularies

`ACTION_DESCRIPTORS` maps an action to a colour tone, a Font Awesome icon and a
display label.

`CHANGE_TYPE_LABELS` supplies the quiet secondary qualifier. It is an uppercase
micro-label rather than a second chip, because a second box would compete with
the action chip. It appears on rows whose action verb is ambiguous alone —
chiefly `update`, where the same verb covers a metadata edit and a permissions
change. The `--<change_type>` modifier stays as a semantic and styling hook,
notably for permissions.

### Where "View" points

`audit_event_view_path` returns a path or nil.

| change\_type | Action | Destination |
|---|---|---|
| `permissions` | `create` or `update` (`PERMISSION_VIEW_ACTIONS`) | The Rights-history diff page |
| `metadata` | `update` | The MODS-history diff page |
| anything else | any | nil — the column renders an empty cell and stays aligned |

Both permission actions carry a before/after snapshot: `create` is the initial
grant, emitted by Atlas's service objects, and `update` is every later ACL
change. Atlas suppresses no-op permission writes, so each one is a real
transition worth a page. `PERMISSION_VIEW_ACTIONS` is shared with
`HistoriesController#permission_events`.

Every metadata update writes a new `descMetadata.xml` OCFL version, so all of
them get a MODS-diff link: a full MODS upload via `mods_xml=`
(`{ source: 'mods' }`) and a title or description field-patch (`{ fields: }`)
alike, since Atlas's `plain_title=` and `plain_description=` edit the MODS
document and call `mods_xml=` too, in `MODSAssignment`. The MODS document's
`create` row has no prior version to diff against, so it stays update-only.

The link is deep-linked to the event. `audit_event_dom_id` derives an anchor
from the event's timestamp, which is unique per resource, so the page scrolls to
the exact entry via `:target`. This is the v2 successor to v1's per-object
Rights and MODS History pages.

### Payload summaries

`audit_event_payload_summary` derives a human one-liner from the payload, by
action. The shapes mirror what Atlas emits:

| Action | Payload | Summary |
|---|---|---|
| `update` | `{ fields: [...] }` | the field names, joined |
| `update` | `{ source: 'mods' }` | "MODS document" |
| `update` | `{ before:, after: }` | an ACL or rendition-gate diff |
| `reparent` | `{ to: noid }` | "moved to &lt;noid&gt;" |
| `link_member` | `{ collection: noid }` | "to &lt;noid&gt;" |
| `unlink_member` | `{ collection: noid }` | "from &lt;noid&gt;" |
| `create`, `tombstone`, `restore` | none | the category pill alone |

`acl_diff_summary` prints a per-grant added and removed summary across the
audited ACL keys — `read +public · edit −staff +editors` — and appends the
embargo transition when it moved. `embargo_summary_clause` uses ISO dates rather
than the Rights page's prose form, because this clause shares a dense table cell
with grant tokens where a spelled-out month would crowd them out.

`tier_diff_summary` prints the same grammar per download tier —
`large −public +staff` — because both are group grants moving on and off a slot.

### The two permission payloads

A permissions event describes either the resource ACL or the per-rendition
download gate. Atlas tags the gate change with `source:
'derivative_permissions'` (`DERIVATIVE_PERMISSIONS_SOURCE`). The two share a
change\_type and an action, so the payload's `source` is the only thing telling
them apart, and both the audit-log summary and the Rights page have to check it
before reading either one. The gate's before and after are a sparse
`{ tier => [read groups] }` map, not an ACL envelope.

`derivative_tier_rows` lists only the tiers either side of the diff mentions, in
`Sentinel::TIERS` narrowing order. The stored policy is sparse — only gated
tiers appear — so listing all eight would bury the change under empty rows.

`TIER_LABELS` gives the tiers prose names. The vocabulary and its narrowing
order come from `Sentinel::TIERS`, which is where Cerberus authors these
policies; naming the ladder twice would let the two drift. `tier_label` falls
back to the raw token.

### The Rights-history diff page

`ACL_LEVEL_LABELS` and `acl_level_label` give the ACL slots prose names for the
expanded two-column before/after view. The audit-log one-liner uses the bare
key; the full page reads better with prose.

`acl_grant_pills` renders one slot's grants as monospace identifier pills,
reusing the audit-log NUID-pill register. `marked` grants get a `state` tint,
which flags the added grants in the after column and the removed grants in the
before column. An empty slot renders a muted em-dash.

`EMBARGO_KEY` names the embargo slot in the same permissions snapshot. An
embargo is a rights decision a human makes and revises — withholding downloads
until a chosen date — so it belongs in the rights diff, just not in the
grant-pill register. `embargo_diff_cell` therefore tints it with the same tone
tokens as the pills but renders it as plain text: a date is a value, not an
identifier, and the monospace chip register is reserved for things you could
paste into a lookup.

`embargo_date` degrades a blank or unparseable value to "no embargo" rather than
raising mid-table, because the payload is a remote snapshot.

### The version picker

`mods_version_options` builds the `<option>` list for the MODS-history version
picker: the version label, a compact timestamp and the actor NUID joined by
middots, with the opaque OCFL version id as the value. The actor may be blank,
and an absent or unparseable timestamp drops out of the label so the option
still reads cleanly.

## The shared `#update`

`Transformable` is the `#update` entry point for the Work, Collection and
Community Metadata, Permissions and Advanced tabs. They are separate forms that
all PATCH the same action with disjoint fields.

Each piece it composes owns one half of a job: `PermissionsForm` parses and
presents the permissions form while `ResourcePermissions` writes it,
`DescriptiveMetadata` and `AdvancedMetadata` merge MODS, and `AtlasWrite` makes
a write survive the wire. What is left in `Transformable` is the routing between
them.

`handle_metadata_update` sends permissions to Atlas's metadata endpoint, and
validates descriptive fields before merging them into the existing MODS and
writing them through the structure-safe raw `update` path.

`resource_mods` reads the resource's raw MODS once per request. Both form
loaders parse the same document — `DescriptiveMetadata` for the bare title,
abstract and keywords, `AdvancedMetadata` for the structured title parts and
names — and the Work edit page runs both, so without the memo the page fetched
the same XML from Atlas twice.

### The two ACL writes

`apply_permissions` is the edit path and `apply_new_permissions` is the create
path. `report` turns whichever `Result` comes back into a flash, and does
nothing when the result carries no level. See `docs/permissions.md` for what
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
| The admin panel (`Admin::AssociationsController`) | `AtlasRb::Resource.find_many` | A management surface must show every edge that exists, including one pointing at a tombstoned Work — which the gated search drops, and which would then be unremovable |

### The public box

`WorkAssociations` resolves Atlas's edges to Solr documents the viewer is
allowed to see, and takes one Solr query to cover both directions and every
predicate, however many edges a Work has.

Atlas answers with noids, and that is what makes this safe. Atlas's read floor
is unconditional: the association endpoint reports every edge, including edges
to Works the viewer must not see. Resolving those noids through the gated search
turns the ungated edge list into only the rows this viewer may have — a noid
that resolves to no document simply does not render. The same lookup drops
tombstoned Works for free, since `-tombstoned_bsi:true` sits in the catalog's
`default_solr_params`.

`initialize` takes `associations:`, Atlas's reply from `AtlasRb::Work.associations`
in the shape `{"outbound" => {predicate => [noid]}, …}`, and `search_service:`,
the controller's `search_service`, which supplies the gated search builder and
index.

`Result` holds one Hash of predicate to documents per direction, in
`AtlasRb::Work::ASSOCIATION_TYPES` order rather than Atlas's hash order, so the
box lists its groups the same way on every Work. `Result#size` counts every
document across both directions, for a jump-link count that matches what
actually renders.

`noids` deduplicates every noid Atlas named across both directions. One Work can
be both the transcription of a Work and a figure for it, and a cycle between two
Works is permitted and meaningful.

`documents_by_noid` keys the gated lookup by bare noid. Solr stores the noid in
`alternate_ids_ssim` as `id-<noid>`, and `search` uses the same `{!terms}` shape
as `SetResolver#noun_uuids`.

### The labels

`WorkAssociationsHelper` holds every phrasing. The predicate is Atlas's wire
token; the phrasing is Cerberus's. One stored edge reads three ways, so each
predicate carries three:

| Key | Where it appears | Example |
|---|---|---|
| `outbound` | A heading on the asserting Work | "Is codebook for" |
| `inbound` | A heading on the target Work | "Codebooks" |
| `assertion` | The tail of a sentence in the form | "codebook for" |

They live in one table, as `AuditEventsHelper` holds its action descriptors, so
adding a predicate is one entry rather than three edits in three files.

Icons are the restrained Font Awesome solid set the rest of the site uses,
chosen for the *kind of thing* the associated Work is. There is deliberately no
colour per predicate: a relationship is a label, not a status, and a
five-colour legend would outrank the Embargoed and Incomplete pills, which do
carry status.

`association_direction_caption` supplies the manage panel's heading for each
direction.

### The admin panel

`Admin::AssociationsController` manages the edges.

| Action | Does |
|---|---|
| `index` | Search for the Work to manage |
| `manage` | Its edges in both directions, plus a search to assert a new one |
| `add` | POST an edge, then back to `manage` |
| `remove` | DELETE an edge, then back to `manage` |

Nothing moves in the containment tree and no permissions change. An association
is descriptive.

It is admin-only because Atlas is. Atlas gates the write to admin and the
devolved tier, because the claim renders on the *target's* page too and the
asserter often holds no rights over it. That is stricter than "descriptive"
suggests, and it is why this is an `/admin/*` surface rather than a tab on the
Work edit page: a tab would be dead chrome for every depositor and editor who
could reach it.

`add` always writes from the managed Work outward, because the edge is stored on
the Work that asserts it. To assert the reverse claim, manage the other Work.
`remove` takes the holder explicitly and so retracts either direction from one
panel, which an admin can do because they hold rights on both ends.

`manage` passes `exclude_node_uuid` to `ResourceSearch`, which keeps the managed
Work out of its own candidate list and pre-empts Atlas's `self_association`
rejection at the point of choice.

`REFUSALS` phrases Atlas's 422 codes on an association write in the admin's
terms. The vocabulary is atlas\_rb's; the wording is Cerberus's. A `Faraday::Error`
is logged by `log_failure` and reported as `GENERIC_REFUSAL`.
