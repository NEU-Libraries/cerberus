# Design

The DRS look in one phrase is *restrained, librarian/archival, institutional*.
This page holds the rules that make it so: which container a surface gets, the
palette and its coupled tokens, type, icons, tabs, buttons and hover. Read it
before you change a view, a component or a stylesheet. A local Claude Code hook
blocks UI edits until this page has been read in the session.

For a new interface or an in-place redesign, also use the `/frontend-design`
skill, as `CLAUDE.md` says, and land its output on the rules here.

Source files:

- `app/assets/stylesheets/_colors.scss` (the palette and the coupled tokens)
- `app/assets/stylesheets/_layout.scss` (the `.well`, and hover without fades)
- `app/assets/stylesheets/_tonal_buttons.scss` (the tonal button variants)
- `app/assets/stylesheets/_admin_registry.scss` (the card shell and identifier chip)
- `app/helpers/application_helper.rb` (`document_type_icon`, the catalog's type icon)
- `app/helpers/admin_finder_helper.rb` (`RESOURCE_ICONS`, the admin finder's type chip)
- `app/helpers/pages_helper.rb` (`featured_gateways`, the homepage buttons)
- `app/models/featured_content.rb` (`GENRES`, the genre icons)
- `spec/assets/color_contrast_spec.rb` (the contrast ratios, asserted)

## Container chrome

Pick a container by what the surface **is**, not by how much it needs
bracketing.

| Surface | Chrome | Reference |
|---|---|---|
| A form section (label and control) | `.well.p-3.my-3.rounded-3` | the Move and Delete tabs in `works/edit` |
| A form footer (Save and Cancel) | `.well.p-3.my-3.rounded-3` | the end of every tab in `works/edit` |
| A tab pane | bare `.py-2.px-1`, with an `%h5.pb-2` heading and a `%p.text-muted.small` explainer | the Permissions tab in `works/edit` |
| A standalone form or action page | the `.admin-registry` card shell | `admin/groups/new` |
| A page heading plate | `.container.p-4.my-3.well.rounded-3` on `:container_header` | the People and Communities indexes |
| A ledger surface | the richer `.audit-history` card shell | the Audit History tab |

`.admin-registry` is shared chrome despite its name: the impersonation form, My
DRS and the Inbox all reuse it on surfaces that are not admin pages.

### The well is a fill, and only for forms

The `.well` is `background-color: $well-bg` and nothing else. It has no border
and no shadow, and must not gain one. The fill alone makes it read as a panel,
and `$well-bg` is pinned by contrast (see the palette below), so it cannot be
lightened to make up for a weaker edge.

A well reads as "a form section you fill in or submit". So:

- **Never wrap prose or a read-only readout in a well.** A readout beside a form
  footer looks like part of that form. Give it a bare section under a heading,
  as `works/_download_access` does.
- **Do not wrap a whole standalone page in a well.** Use the card shell.
- **An explainer with the one action it explains may sit in a well**, when that
  action is the form, as in the Set page's "Apply it to this set's works".
- **A warning a pane leaves unbracketed** needs chrome of its own, or it reads as
  more prose: `.alert.alert-warning.py-2.px-3.small.d-flex.align-items-start`,
  before the control it applies to, as in `my_drs/_programmatic_access`.

### The card shell

For a new component that needs a card, match the bordered card shell: `1px
solid $gray-300` and `rounded-3` on a white or off-white fill. Audit history, the
admin registry, the deposit form, Sets and full-text snippets use it.

Either container takes a subtle shadow at most. Avoid heavy drop shadows,
gradients and coloured card backgrounds.

## Palette

The tokens in `_colors.scss` are deliberately desaturated from Bootstrap's
defaults: `$blue: #2666a6` (navy-teal), `$success` from a darkened `$green:
#18bc9c` (teal-green, not a punchy emerald), `$danger: #e74c3c`, and the footer
`#385775`. Use the SCSS variables rather than hard-coded hex. For a new tone,
such as an audit action colour, derive a desaturated value, not a Bootstrap one.

### Four tokens are one coupled system

`$link-blue`, `$well-bg`, `$gray-100` and `$gray-900` are pinned to each other by
two opposing WCAG rules. **Do not hand-tune them.** Ordinary links carry no
underline, so a link must clear 4.5:1 against every background it sits on, which
pushes it darker, and 3:1 against the body text around it, which pushes it
lighter. The window between the two is a few thousandths of relative luminance
wide, and two of the four current ratios are hairlines (4.51 against 4.50, and
3.01 against 3.00).

`spec/assets/color_contrast_spec.rb` asserts all of them. Run it after touching
any of the four. Darkening `$link-blue` to `$blue` looks obvious, and silently
trades one audit failure for another; it has been tried.

Hue is free: contrast depends only on relative luminance, so any hue at the
required lightness works.

## Typography and numerics

Use Bootstrap's defaults for body text, and add no web fonts. For tabular data,
such as audit rows, NUIDs, file sizes and timestamps, turn on
`font-variant-numeric: tabular-nums`, and consider a monospace chip:
identifiers should look like identifiers, not body words. The registry's
`.admin-registry-table__id` is that chip; extend it rather than restyle one.

## Iconography

Each concept has one Font Awesome solid icon, and no two concepts share one. The
reference is the homepage Featured Content gateways: a button and the heading of
the page it opens show the same icon.

| Concept | Icon | Seen on |
|---|---|---|
| A person | `fa-user` | Faculty & Staff gateway, People index and profile, People registry, a community's Faculty & Staff entry |
| A community | `fa-users` | Communities gateway and index, a community page, the catalog type icon, Community affiliations |
| A collection | `fa-folder-open` | A collection page, the catalog type icon, deposit and loader destinations |
| A work | `fa-file` | The catalog type icon, the admin finder chip |
| A Grouper group | `fa-user-group` | Group and loader forms, the People registry's Groups toggle, the Inbox group chip, the My DRS group count |
| The Group names feature | `fa-tags` | Its dashboard card, registry and form: the labels it manages, not a group |
| A Set | `fa-layer-group` | Every Set page, the My Sets menu entry |
| My DRS | `fa-folder-tree` | The My DRS page and its menu entry |
| A loader | `fa-file-import` | Its dashboard card, the Loader registry, the loader chip on load pages |
| Move (reparent) | `fa-sitemap` | Its dashboard card and pages, the audit "Reparented" row, the Requests "Move" row |
| A genre | its `FeaturedContent::GENRES` icon | Its homepage gateway, its landing page heading and empty state |

The genre icons are `fa-file-lines` (Research Publications),
`fa-person-chalkboard` (Presentations), `fa-database` (Datasets),
`fa-file-contract` (Technical Reports), `fa-book` (Monographs),
`fa-graduation-cap` (Theses & Dissertations) and `fa-newspaper` (Other
Publications). Because they are taken, a work is `fa-file`, not `fa-file-lines`.

### Choosing an icon for something new

1. If the thing is a concept in the table, use its icon, even where a different
   one looks better in isolation.
2. If it is new, pick an icon no row above uses. Check the table and search
   `app/` for the class before you settle on it.
3. Make it singular or plural by what it shows: one person is `fa-user`, a group
   of people is a community or a Grouper group, each with its own icon.
4. Confirm the class exists in the Font Awesome build the site loads. A missing
   class renders nothing, and no spec or log reports it. In the browser, a real
   class's `::before` content is a glyph code (`U+f007` for `fa-user`); a
   missing one's is `none`.

Icons in context, such as `fa-user` and `fa-building` for personal and corporate
creators, or `fa-user` and `fa-people-arrows` for self and proxy deposit, name a
role on one form rather than a DRS concept, and sit outside the table.

### Why the table looks as it does

- **Faculty & Staff is one person, Communities a group.** v1 drew them that way,
  and the pages they open are headed the same way.
- **Grouper groups are `fa-user-group`, not `fa-users`.** They shared `fa-users`
  with communities. Two figures still read as people and stay distinct from the
  three-figure community icon.
- **The Group names feature keeps `fa-tags`.** It manages the display labels for
  groups, so its icon names the labels, not a group.
- **The multipage ingest mode is `fa-book-open`.** It borrowed the Sets icon; a
  paged object reads as a book.

## Tabs and navigation

The Edit pages use Bootstrap `nav-tabs` with `data-controller="tab-hash"`. Add a
tab by extending that pattern. Do not introduce another navigation idiom.

## Buttons

**Never use `btn-outline-*` or `btn-light`.** An outline button is transparent,
and `btn-light` is the body's own `$gray-100`, so both take the colour of
whatever they sit on and read as text in a box.

Give each surface one solid button for its main action: `btn-primary`, or
`btn-success` for Save. Every other button takes a variant from
`_tonal_buttons.scss`:

| Variant | For | Examples |
|---|---|---|
| `btn-tonal-primary` | row and file actions | Download, export, Regenerate, New upload |
| `btn-tonal-secondary` | quiet actions | Copy, Clear, Add to queue, Back links, inactive filter chips |
| `btn-tonal-danger` | destructive actions | Discard, Revoke, Remove |
| `btn-tonal-success` | status chips | "In queue" |

Buttons come in two sizes, the default and `btn-sm`, and no custom ones. A form's
actions (Save, Cancel, and the tab's main action) take the default size on every
tab, so switching tabs never resizes them. `btn-sm` is for actions inside a table
row, a chip group, or a compact toolbar strip such as the Analytics header.

A Cancel that abandons a form is always `btn-warning`, with no icon. A Back link
only navigates, so it is tonal-secondary rather than orange.

Keep the tonal border at full strength. It is what clears WCAG's 3:1 edge
contrast against both the grey page and white cards; a softer border falls to
about 2:1.

## Hover

**Hover must never move or resize the element under the pointer.** No
`translateY` lift, and no change to border width, padding or font weight. The
element's edge slides out from under a resting pointer, the hover drops, the
element slides back, and it flickers.

Signal hover with colour, border and shadow instead, and switch it instantly
rather than fading. A fade that swaps dark text on a pale fill for white on a
dark one passes through a point where the label vanishes. `_layout.scss` turns
off Bootstrap's fade on every `.btn`, so do not add a `transition` to a hover
that changes colour, on a button or anywhere else.

## What not to add

- Tailwind, another CSS framework, or another design system.
- New web fonts.
- Maximalist effects, such as gradient meshes, grain overlays or animated heroes.
  They fight the institutional register the rest of the site sets.

## The reference example: the Audit History tab

When in doubt about how to meet these rules on a new admin, metadata or audit
surface, start from the Audit History tab. It is a forensic ledger that sits
beside Blacklight's search UI without looking like a different product.

- `app/views/audit_events/_history.html.haml`: the card shell with a header
  strip, a gated render, and partial dispatch.
- `app/views/audit_events/_event_*.html.haml`: per-action partials that share
  helper-rendered cells and vary only the action chip's class.
- `app/helpers/audit_events_helper.rb`: the formatting helpers (the timestamp
  split, the NUID chip, and the action table with a generic fallback for an
  unknown verb).
- `app/assets/stylesheets/cerberus.scss` (search `audit-history` and
  `audit-event-table`): a left rail drawn with `::before`, and tinted action
  chips driven by a `--audit-action-color` custom property. Adding a tone is one
  map entry and one CSS line. The chip background is derived with
  `color-mix(in srgb, …, white)`; the icon and label take the full tone.
