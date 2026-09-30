# Iconography

Each concept in the DRS has one Font Awesome solid icon, and no two concepts
share one. The reference is the homepage Featured Content gateways: a button and
the heading of the page it opens show the same icon. This page is the vocabulary
to reuse when a new surface names one of these concepts.

Source files:

- `app/helpers/application_helper.rb` (`document_type_icon`, the catalog's type icon)
- `app/helpers/admin_finder_helper.rb` (`RESOURCE_ICONS`, the admin finder's type chip)
- `app/helpers/pages_helper.rb` (`featured_gateways`, the homepage buttons)
- `app/models/featured_content.rb` (`GENRES`, the genre icons)

## The vocabulary

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

## Choosing an icon for something new

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
creators, or `fa-user` and `fa-people-arrows` for self and proxy deposit, name
a role on one form rather than a DRS concept, and sit outside this table.

## Why the table looks as it does

- **Faculty & Staff is one person, Communities a group.** v1 drew them that way,
  and the pages they open are headed the same way.
- **Grouper groups are `fa-user-group`, not `fa-users`.** They shared `fa-users`
  with communities. Two figures still read as people and stay distinct from the
  three-figure community icon.
- **The Group names feature keeps `fa-tags`.** It manages the display labels for
  groups, so its icon names the labels, not a group.
- **The multipage ingest mode is `fa-book-open`.** It borrowed the Sets icon;
  a paged object reads as a book.
