# Accessibility

Cerberus checks accessibility in two layers. Template linters catch markup
mistakes before a commit, and axe-core checks the rendered pages in the browser
lane.

## The target

**Cerberus must meet WCAG 2.0 at level AA.** That is the standard Northeastern's
[Policy on Digital Accessibility](https://policies.northeastern.edu/policy122)
names, and the policy asks for good-faith effort on existing systems. The target
covers public, staff and admin pages alike.

**Meet a WCAG 2.1 or 2.2 AA criterion when it costs no UX.** The site already
passes every 2.1 and 2.2 AA rule that axe tests, so the audit keeps those rules.
If one fails later and its fix would make the interface worse, skip that rule in
the spec and record the reason under the known failures below.

**Deposited content is outside the target.** Cerberus cannot repair the files
that depositors upload, such as PDFs, images and media.

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

**Keyboard operation needs its own browser spec.** axe does not test it.
`spec/system/breadcrumb_add_spec.rb` is the pattern: it checks that a control
takes focus and that Enter operates it.

## What the audit does not count

Two kinds of grey are exempt from WCAG 1.4.3, so they keep `$gray-500`:

- **Decorative icons.** Each one carries `aria-hidden` and sits beside text that
  says the same thing.
- **Disabled controls,** such as a pagination arrow with nowhere to go.

Contrast for icons and control edges is WCAG 2.1's 1.4.11, which is outside the
target. Text in grey uses `$text-subtle`; `design.md` has the palette rules.

## Recorded exceptions

An exception is a known WCAG 2.0 AA failure kept on purpose, under the
good-faith clause of Northeastern's
[Policy on Digital Accessibility](https://policies.northeastern.edu/policy122).
`AxeAudit::CONTRAST_EXCEPTIONS` in the spec excludes each one from the
`color-contrast` rule only. Every other rule still checks it.

### White text on the orange Cancel button

**The failure.** `.btn-warning` (Cancel, View as) sets white text on `#fd7e14`.
WCAG 2 measures that at 2.57:1, against the 4.5:1 that WCAG 1.4.3 requires.

**Why it stays.** WCAG 2's contrast formula is known to understate how legible
light text is on saturated mid-tones such as orange. On this button it rates
dark text (6.00:1) far above white (2.57:1). APCA, the perceptual method
behind the WCAG 3 draft, ranks them the other way round: white scores Lc 54.7
and dark text Lc 50.7. Two published pieces report the same effect with users:

- *The Myths of Color Contrast Accessibility*, UX Movement, 16 October 2019.
  It argues that the WCAG 2 formula mismeasures white text on saturated
  buttons, and reports readers preferring white text on orange and blue
  buttons that fail the ratio.
  <https://uxmovement.com/buttons/the-myths-of-color-contrast-accessibility/>
- *Orange You Accessible? A Mini Case Study on Color Ratio*, Ericka O'Connor,
  Bounteous, 22 March 2019. About 20 colour-blind colleagues compared white and
  black text on a brand orange. 61% preferred white, although white measured
  3.26:1 and black 6.44:1. Preferences differed by type of colour blindness:
  the one monochrome participant preferred black. The author still advises
  following the guidelines and calls for further research.
  <https://www.bounteous.com/insights/2019/03/22/orange-you-accessible-mini-case-study-color-ratio/>
  (archived:
  <http://web.archive.org/web/20260314085740/https://www.bounteous.com/insights/2019/03/22/orange-you-accessible-mini-case-study-color-ratio/>)

**What it does not claim.** Neither source makes the button conform to WCAG
2.0 AA, and APCA's Lc 54.7 is still below the Lc 60 it suggests for text of
this size. The exception records a reasoned trade-off, not a pass.

**What was tried.** No orange as light as `#fd7e14` reaches 4.5:1 under white
text at any hue; it has to darken to amber-brown first. These options all pass
and were all declined, so do not re-propose them without new evidence:

- Dark text on the same orange.
- Deeper oranges with white text: red-orange `#cc4b00`, deep amber `#a15c00`,
  ochre `#8a6a1f`, and darkened `#ec4913` or `#e68a00`.
- A tonal orange, a slate tonal-secondary, or a text link.
- A larger bold label on `#e66700`, which passes the 3:1 large-text rule.
- Other hues with white text, from indigo through rose.

**What would retire it.** Any Cancel style that passes 4.5:1 and is approved
from a mock-up. Remove `.btn-warning` from `AxeAudit::CONTRAST_EXCEPTIONS`
when it lands. Keep white-on-orange to this one button: no new surface may use
`$warning` behind white text.

## Known failures awaiting a design decision

`AxeAudit::PENDING` in the spec excludes this component from every rule. It
fails 1.4.3, and each fix proposed so far was declined because it changed the
look too much. When a decision lands, fix the component and remove its entry.
The spec then guards it.

| Component | Now | Declined so far |
|---|---|---|
| `.thumb-type-pill`: white on a 70% light grey | 1.91:1 | an 85% `$gray-700` backing; a white pill; dark text; a slate pill; a caption under the thumbnail |
