# Accessibility

Cerberus checks accessibility in two layers. Template linters catch markup
mistakes before a commit, and axe-core checks the rendered pages in the browser
lane. The target is WCAG 2.2 at levels A and AA.

Source files:

- `bin/a11y-lint` (runs both template linters)
- `.haml-lint.yml` (enables only the accessibility linters)
- `spec/system/accessibility_spec.rb` (the axe audit, and the rules it skips)

## The two layers

| Layer | Tool | Runs on | Catches |
|---|---|---|---|
| Templates | `haml-lint` | HAML views | an `img` with no `alt`, a repeated `id` |
| Templates | `herb-lint` | ERB views | bad ARIA roles and attributes, missing `alt` and `title`, unlabelled `nav`, positive `tabindex`, empty headings, nested links |
| Rendered pages | axe-core | every page in the axe spec | names and labels, landmarks, contrast, link distinction, ARIA use, target size |

**Most WCAG failures appear only in the rendered page.** A label that a helper
never emits, or a name computed from an icon, is invisible in a template. Treat
the template linters as a fast first check and the axe spec as the real one.

**Neither layer proves compliance.** Automated tools find about half of WCAG
failures. Keyboard order, focus visibility, and how a screen reader announces a
flow still need a person.

## Running the template linters

```bash
bin/a11y-lint                 # every template under app/
bin/a11y-lint <files>         # named templates
```

The script runs `haml-lint` inside the `web` container, where the bundle is. It
runs `herb-lint` on the host, because Herb is npm-only and the repo has no
`package.json`. Where `herb-lint` is missing, the script skips ERB and says so.
Install Herb with `npm install -g @herb-tools/linter`.

Nothing is auto-corrected. Each finding needs a person to choose the alt text or
the label.

**The repo keeps no `.herb.yml`.** `herb-lint` has no rule filter on the command
line, so the script filters Herb's output down to its accessibility rules. Two
rules stay out on purpose:

- `html-input-require-autocomplete`: WCAG 1.3.5 asks for `autocomplete` only on
  fields that collect the user's own details, such as a name or an email.
- `html-no-title-attribute`: a `title` is not a WCAG failure.

## The Claude Code hook

A local Claude Code `PostToolUse` hook, `.claude/hooks/a11y-lint.sh`, runs
`bin/a11y-lint` on each template Claude writes. A finding goes back to Claude as
tool feedback, so Claude fixes it in the same turn. The hook runs the edited
checkout's own script, so a worktree is linted with its own rules. `.claude/`
is gitignored, so the hook lives in the main checkout's local configuration,
not in the repository.

The hook sees only Claude's edits. Before you commit a template you edited by
hand, run:

```bash
bin/a11y-lint --staged
```

## The axe spec

The spec visits each page as the least privileged user who can open it. It
visits each edit-page tab through its URL fragment, because axe skips content
that is not displayed. The tab list comes from `EditTabsHelper::TABS`, so a new
tab is audited without an edit to the spec.

It runs in the browser lane, which CI does not run:

```bash
docker exec cerberus-web-1 bundle exec rake browser
```

To run only the audit from a worktree, first start the `selenium` service as
`development.md` describes. Then run:

```bash
bin/spec --tag browser spec/system/accessibility_spec.rb
```

**Add a page to the spec when you add a surface.** The audit covers only the
pages it visits. Pages with no fixture yet include a person, a Set, a load
report and an inbox message.

## Known failures awaiting a design decision

`AxeAudit::SKIPPED` in the spec turns off two axe rules. Fixing either rule
changes how pages look, so each fix waits on a design decision. When a decision
lands, fix every element under that rule and remove the rule from the list. The
spec then guards it.

### `color-contrast`

WCAG 1.4.3 asks for 4.5:1 for normal text and 3:1 for large text.

| Element | Ratio | Where |
|---|---|---|
| `.btn-warning` (Cancel, View as): white on `$orange` | 2.57 | every form footer, impersonation |
| `.btn-danger` (Act as, Request deletion): white on `$danger` | 3.82 | impersonation, the Delete tab |
| `.btn-success` (Save, Send, Atlas Login): white on `$success` | 4.02 | every form footer, sign-in |
| `.admin-action-card__cta`: `$success` on white | 4.02 | `_admin_dashboard.scss:125` |
| `.thumb-type-pill`: white on light grey | 1.91 | `_blacklight_discovery.scss:52` |
| `$gray-500` small labels | 1.94 to 2.07 | `_admin_registry.scss:267`, `_deposit_form.scss:32`, `_admin_reparent.scss:26`, `_admin_impressions.scss:57`, `_audit_history.scss:78`, `_derivative_access.scss:16`, `_derivative_access.scss:70` |
| `$gray-600` hint text on a tinted fill | 4.03 to 4.44 | `_admin_dashboard.scss:53`, `_deposit_form.scss:244`, `_deposit_form.scss:262`, `_blacklight_discovery.scss:223`, `_audit_history.scss:217` |
| The "Created" audit chip: its tone on its own tint | 3.65 | `_audit_history.scss:217` |
| `.text-black-50` type label beside a page title | 3.85 | the Collection and Community headers; the Set header uses the same class |
| Ace's line numbers (the `eclipse` theme) | 2.97 | the XML editor |

`$success`, `$warning` and `$danger` are Bootstrap theme colours. Changing them
changes every button and alert in that colour, not only the ones listed.

### `link-in-text-block`

WCAG 1.4.1 asks that a link inside a run of text differ from that text by more
than colour. The link needs 3:1 against the text, or an underline.

| Element | Ratio | Where |
|---|---|---|
| A link in an empty-state hint (`$gray-700` text) | 1.59 | zero results, the people index |
| The "XML editor" link in the Advanced tab's explainer | 1.35 | the Work edit page |

The site-wide link colour already clears 3:1 against body text. These links fail
because the text around them is a lighter grey than body text. `design.md`
explains why the four link and background tokens are coupled.

### Keyboard access

axe does not test keyboard operation, so this one sits outside the spec.

| Element | Problem | Where |
|---|---|---|
| The breadcrumb "Add" menu toggle | an `<a>` with no `href` cannot take focus, so a keyboard user cannot open the menu | `app/views/shared/_breadcrumbs.html.haml` |

A `<button>` fixes it. Restyling a button to match the current link changes how
the toggle looks and how it shows focus.
