# Conventions

The rules every change to Cerberus has to satisfy, whoever or whatever writes
it. Procedure — setup, specs, worktrees, verification — is in
[`development.md`](development.md). The look of a surface is in
[`design.md`](design.md).

## Layering

Cerberus is the front end. Atlas owns every repository object, and atlas_rb is
the only way to reach it. The [repository README](../README.md) explains why the
split falls where it does.

- Use atlas_rb to create, read, update or delete a repository object. Do not
  call the Atlas API over raw HTTP, and do not query Atlas's store directly.
- Do not add ActiveRecord models or queries that stand in for something Atlas
  owns. Cerberus's own database holds only what has no repository meaning.
- Search, facets and pagination are the exception. Blacklight queries Solr
  directly, and Cerberus never writes Solr.
- Keep Blacklight configuration — facets, search fields, sort fields — in
  `CatalogController` and the search builder classes. Do not scatter it.

Treat the Atlas OpenAPI spec and the atlas_rb YARD docs as a snapshot of what
exists now. All three repositories are under active development and are not
yet feature-complete.

## Cross-repository gaps

Sometimes a Cerberus feature needs something that atlas_rb or Atlas does not
have yet. When that happens, do not change those repositories as part of the
Cerberus work, and do not work around the gap silently. Write a gap report, so
the fix lands as standalone work in the right repository.

A gap report has five parts:

| Part | Content |
|---|---|
| Cerberus feature | What you are building, and why the gap blocks it |
| What is needed | The specific method, endpoint or capability that is missing |
| Atlas status | Whether the endpoint already exists, checked against the [Atlas OpenAPI spec](https://raw.githubusercontent.com/NEU-Libraries/atlas/develop/openapi/openapi.yaml) |
| Gap type | *Binding-only* if Atlas has the endpoint but atlas_rb lacks a wrapper; *new endpoint* if Atlas itself needs the capability |
| Suggested implementation | A sketch of the atlas_rb method signature, the Atlas endpoint, or both |

The same applies to a TODO, a missing capability, or behaviour that does not
match expectations.

## Code

- Follow standard Ruby and Rails conventions: snake_case names and RESTful
  controllers.
- Keep controllers thin. Logic belongs in a service object or a model.
- Express every schema change as a migration. Never edit `db/schema.rb` by
  hand; [`development.md`](development.md#migrations-are-a-pause-point) explains
  the pause a new migration needs.
- Never commit a `.env`.

## Comments

A comment earns its place only when it explains why the code immediately below
it exists. It must still make sense to a reader two years from now who has no
access to git history or planning documents. Keep it to two or three sentences.

Do not write temporal or working-artifact comments:

- No dates, app version stamps such as `2.9.x`, or `(Fixed YYYY-MM-DD)`
  markers.
- No planning shorthand: `piece N`, `Q<n>`, "gap report", "position paper",
  named initiatives, or pointers to files outside the repository.
- No before-and-after narration, such as "used to", "no longer", "previously"
  or "was X, now Y". Describe the current design and its reason. Git holds the
  old design.

Keep real rationale, wire-contract constraints and gotchas, but drop the
incident. "Merging `:fq` drops the gated-discovery clause — use `with_filters`"
is a good comment. The date that it caused a bug is not.

Most explanation belongs on a page in `docs/`, not in the file. What stays in
the file is the trap: a comment that someone editing *this line* would break
something without. A wire-contract gotcha, an ordering constraint, a rule that
looks redundant but is not, and every `rubocop:disable` justification stay
inline. Everything else goes on a page, and the file keeps a one-line pointer
to it. [`README.md`](README.md) covers when to add a page and the comment
density target.

Prefer a spec to prose whenever the claim is testable. A spec fails when
someone breaks it; prose does not.

## Interface

- Build new elements with Bootstrap 5, and follow [`design.md`](design.md).
  Read it before you change a view, a component or a stylesheet.
- Make every new element accessible to WCAG 2.0 AA. Run `bin/a11y-lint` on the
  templates you touch, and add each new page to the axe audit.
  [`accessibility.md`](accessibility.md) covers both.
