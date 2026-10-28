# Font Awesome

The site serves a Font Awesome build that carries only the icons the source
names.

| | Upstream | Build |
|---|---|---|
| The three fonts, `.woff2` | 277 KiB | 16 KiB |
| `css/all.min.css`, gzip | 19.8 KiB | 3.3 KiB |

Every page loads the solid and brands fonts and the full stylesheet, so the
difference lands on every cold page load. The stylesheet does not block the
first paint ([`critical-css.md`](critical-css.md)), but it still shares the
connection with the fonts and the largest image.

Source files:

- `lib/font_awesome_subset.rb` (the scan and the build)
- `bin/fontawesome-subset` (runs the build)
- `spec/lib/font_awesome_subset_spec.rb` (fails when an icon is missing)
- `vendor/fontawesome-upstream/` (the release, unmodified)
- `vendor/fontawesome/` (the build, which is what the site serves)
- `vendor/fontawesome-icons.txt` (the icons in the build)

## Adding or removing an icon

1. Use the class in the source.
2. Run the build:
   ```bash
   bin/fontawesome-subset
   ```
3. Commit `vendor/fontawesome/` and `vendor/fontawesome-icons.txt` with the
   change.

The build runs on the host, not in the `web` container, because it needs
`pyftsubset` from fonttools with brotli:

```bash
pip install 'fonttools[woff]'
```

If that `pyftsubset` is not on `PATH`, point `PYFTSUBSET` at it.

Removing an icon without a rebuild does no harm. The build just carries a glyph
and a rule that nothing uses until the next run.

## How the build works

1. `FontAwesomeSubset.names` collects every `fa-` token in `app/`, `config/` and
   `lib/`. It skips `app/assets/builds/`, which is gitignored compiled output.
2. `FontAwesomeSubset.icons` reads each `.fa-x::before{content:"\f…"}` rule of
   the upstream stylesheet. Tokens with no such rule, such as `fa-solid` or
   `fa-fw`, drop out.
3. `pyftsubset` cuts each upstream `.ttf` down to those codepoints, written as
   both `.woff2` and `.ttf`. Each font keeps only the codepoints it has, so the
   brands font ends up with only the few logos in use.
4. `FontAwesomeSubset.trim` writes the stylesheet without the icon rules the
   source does not name. A rule with any selector that is not a plain
   `.fa-x:before` stays whole. Every other rule is untouched.
5. `trim` also drops the `@font-face` rules for the Font Awesome 4 and 5 family
   names, which exist for markup written against those releases. The site uses
   only the Font Awesome 6 families. The critical CSS inlines every `@font-face`
   on every page, so the old ones cost bytes in each page's `<head>`. Nothing
   else used `fa-v4compatibility`, so the build no longer carries it.
6. The build writes all of this to `vendor/fontawesome.build/`. Only once
   every font is cut does it replace `vendor/fontawesome/` with that directory
   and write the icon names to `vendor/fontawesome-icons.txt`. A failed
   `pyftsubset`, such as one without brotli, leaves both as they were and
   removes the staging directory.

The build reads the `.ttf` files, not the `.woff2`. fonttools' brotli decoder
rejects the upstream `.woff2`, although browsers load them.

The output is byte-identical from run to run, so a rebuild with no icon change
leaves the tree clean.

## Why a source scan is safe

Every icon name in the source is a literal string, in a template, a helper, a
model constant or a JavaScript template. Nothing builds a name from parts, and
neither Blacklight nor blacklight-gallery uses Font Awesome. A name built at
runtime, such as `"fa-#{kind}"`, would defeat the scan. Write each name out in
full, as `document_type_icon` does.

## The spec

`spec/lib/font_awesome_subset_spec.rb` compares the scan against
`vendor/fontawesome-icons.txt`, and against the rules in the served stylesheet.
A missing glyph or rule renders as nothing, and neither the browser nor the log
reports it, so the spec is the only check. It fails with the missing names and
the command that fixes them.

## Why `font-display` stays `block`

Lighthouse flags the upstream `font-display:block` and suggests `swap`. Font
Awesome's glyphs sit at private-use codepoints, so a fallback font during a
`swap` shows empty boxes or nothing. With the build's small fonts, the block
period is about one round trip. The audit is unscored.
