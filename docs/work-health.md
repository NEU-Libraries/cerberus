# Work health

Atlas grades a Work green, yellow or red, and lists what is wrong with it.
Cerberus shows that report in two places: the Health tab on a Work's edit page,
and the admin lookup at `/admin/work_health`. Both are for the admin and
delegated-admin tiers only.

Source files:

- `app/services/work_health_check.rb` (the Atlas read, and its failures)
- `app/helpers/work_health_helper.rb` (grades, severities, and the repair map)
- `app/controllers/work_health_controller.rb` (the Health tab's frame)
- `app/controllers/admin/work_health_controller.rb` (the lookup by NOID)
- `app/views/work_health/` (the report, the findings table, the failure notice)
- `app/assets/stylesheets/_work_health.scss`

## What Atlas answers

`AtlasRb::Work.health_check(id, nuid:)` wraps `GET /works/:id/health_check`.
It returns the Work's `noid`, a `grade`, `fixity_checked` and a list of
`findings`. Each finding has a `severity`, a `code`, a `subject` and a
`message`.

| Grade | Means | Worst severity |
|---|---|---|
| green | viable | `advisory`, or none |
| yellow | repairable in place, nothing lost | `repairable` |
| red | bytes missing or corrupt; restore or re-deposit | `fatal` |

**The codes are an open vocabulary.** Atlas adds a code when it adds a check,
usually before Cerberus knows the code. A code that Cerberus does not know
renders its `message` with no repair link. It never raises. Atlas's
`docs/work-health.md` lists the codes.

**`subject` is often not the Work.** It names the object the finding is about,
which is often a FileSet or a Blob inside the Work. The report shows "this
Work" when `subject` is the Work's own NOID, and the NOID otherwise.

**`fixity_checked` is always `false`.** Atlas never re-hashes bytes over HTTP,
because a large file would hold a worker for minutes. So a green means nothing
is missing, not that the bytes were verified. The report always says so. A
fixity check runs offline, through Atlas's `rake atlas:health:work` with
`FIXITY=1` or its `bin/ocfl-health`.

**Atlas does not cache the answer.** Check again shows the grade after a repair.

## Who may see it

Atlas allows the check for admins and the delegated-admin tier, and answers 403
to anyone else, including a user who can edit the Work. So Cerberus must offer
it to exactly those two tiers, or an editor sees a tab that then fails.

| Surface | Gate | Evaluated as |
|---|---|---|
| The Health tab | `can?(:read, :work_health)`, through `edit_tab_visible?('health')` | the effective user, so the tab follows view-as |
| The frame action | `authorize! :read, :work_health` | the effective user |
| The admin lookup | `require_admin_or_delegate` | the real user, like every `/admin/*` page |

`:work_health` is a rule of its own in `Ability`, beside `:audit_event`. The
two audiences are the same today. Separate rules let them diverge without a
hunt.

**Atlas is always called as the real operator,** with `current_user.nuid`. Under
view-as the effective user can sit below the tier, and Atlas would refuse.
`WorkCaptions#removed_captions` does the same for the same tier.

## The Health tab

The tab is the last entry in the Work row of `EditTabsHelper::TABS`. Atlas
grades Works only, so no container offers it.

**The pane loads lazily.** It holds a Turbo Frame with `loading: :lazy` and a
`src` of `GET /works/:id/health`. The check reads Postgres, Solr and the Work's
files on disk, so it costs more than the History tab's read. A lazy frame in a
hidden pane loads only once the pane is shown. The edit page pays nothing until
the operator opens the tab.

**A failure renders inside the frame.** A lazy frame that gets an error page
shows only Turbo's "Content missing". So `WorkHealthCheck` turns every failed
read into a reason, and the action renders it with status 200:

| Atlas | Reason | The notice says |
|---|---|---|
| 404, so `nil` | `:not_found` | no Work has that NOID |
| `ResourceError` 403 | `:forbidden` | the check is not available to you |
| an outage (`Outage.for`) | `:outage` | the capability's title, and Try again |
| any other `ResourceError` or `Faraday::Error` | `:failed` | the check could not run, and Try again |

The notice names the lost capability, never the service, as the outage pages
do. See `docs/outages.md`.

## The report

The report has two parts, so the summary does not read as part of the table.

**A readout first.** A bare label-and-value list sits under the pane heading,
with Check again below it. `docs/design.md` keeps a read-only readout out of a
well, so it has no container.

| Label | Shows |
|---|---|
| Grade | a chip with the `fa-heart-pulse` icon and the grade in words. Colour alone fails WCAG 1.4.1, so the words carry the meaning |
| Fixity | always "Not checked", because Atlas never re-hashes bytes for this check |
| Problems | the count, split by whether this page offers a repair (`work_health_problem_summary`). It counts only what Cerberus knows, and does not say who repairs the rest |

**Then the findings card,** only when there are findings. It reuses the Audit
History card shell and its chip and row rail. `_work_health.scss` maps each
grade and severity to an existing ledger tone: red for lost content, amber for
a repair, teal for viable, and grey for a state that is not damage.

- **Problems** come first, fatal before repairable. A severity Atlas adds later
  sorts after them, as a problem.
- **Advisory findings,** such as `in_progress`, `private` and `no_handle`, sit
  in a collapsed `details`. They are states of the Work, not damage. A Work with
  advisory notes and no problems keeps the card, which says nothing is missing
  or broken.

## Where each finding is repaired

`WorkHealthHelper::REPAIR_TABS` maps a code to the edit surface that repairs
it. `REINDEX_CODES` lists the codes that the Reindex action repairs.

| Codes | Repair |
|---|---|
| `untitled` | the Metadata tab |
| `mods_access_copy_missing`, `descriptive_file_set_missing`, `mods_xml_missing` | the XML editor. A Save writes the MODS and recreates a missing descriptive FileSet |
| `orphaned`, `parent_missing`, `wrong_parent_type` | the Move tab |
| `staff_edit_missing`, `no_depositor` | the Permissions tab |
| `live_under_withdrawn` | the Delete tab |
| `not_indexed` | Reindex, posting to `Admin::ReindexController#work` |

The other codes, such as `binary_missing`, `blob_unlinked` and the envelope and
OCFL codes, have no Cerberus surface. They show the message alone.

**A link inside the frame must say where it loads.** By default a link in a
Turbo Frame loads its target into the frame. So:

- A tab link on the edit page is a bare fragment (`#move`) with
  `data-turbo="false"`. The browser changes the hash, and `tab-hash` switches
  the pane in place on `hashchange`.
- The XML editor link and the Reindex form carry `data-turbo-frame="_top"`, so
  they replace the whole page.

**Reindex comes back to the report.** The button sends a `return_to`: the edit
page with `tab: 'health'`, or the admin lookup for that NOID. The reindex
action follows it through `url_from`, which refuses anything off this site, and
falls back to the Work's show page. The flash then shows above the new grade.

## The admin lookup

A Work can be too broken to open its edit page. For example, the edit page
reads the Work's MODS and its assets before it renders. The admin hub's Work
health card opens `/admin/work_health`, which runs the same check on a NOID
typed in.

It takes a NOID, not a title search. The title search reads Solr, and a Work
with no Solr document is one of the cases the page exists for.

The page renders the same report with `standalone: true`. No tabs sit beside
it, so each repair link opens the edit page on its tab (`?tab=move`), and
Check again and Reindex come back to the lookup.

## The XML editor on a damaged Work

The XML editor is where most yellow and red Works get repaired, so it must open
on one.

- **No access copy** (`mods_access_copy_missing`): Atlas answers 404 for the
  HTML rendering, so `@mods` is nil. The preview shows a placeholder. The
  placeholder keeps the `#mods` id, because Validate's Turbo Stream replaces
  that node.
- **No preservation XML** (`mods_xml_missing`): Atlas answers 404 for the XML,
  so the buffer opens empty beside a full preview of the access copy. A notice
  above the editor says so, and links an operator to the Health tab.
