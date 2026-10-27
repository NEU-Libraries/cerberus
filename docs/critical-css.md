# Critical CSS

A full page load carries, inline in `<head>`, the rules of `application.css`
and Font Awesome that its own markup can match. It loads both full files
without blocking the first paint, and applies them when they land. The page
paints styled about as soon as its HTML has arrived, instead of after roughly
70 KiB of stylesheets has downloaded.

Source files:

- `app/services/critical_css.rb` (picks the rules for one page)
- `app/services/critical_css/stylesheet.rb` (splits a compiled stylesheet into rules)
- `app/services/critical_css/selector.rb` (the tokens a selector needs)
- `app/services/critical_css/markup.rb` (the tokens a page carries)
- `app/helpers/stylesheets_helper.rb` (the three `<head>` shapes)
- `app/controllers/concerns/critical_css_inlining.rb` (rewrites the response)
- `app/views/layouts/blacklight/base.html.erb` (the one-line Blacklight override)

## The three heads

| Request | `<head>` carries |
|---|---|
| A full page load | The page's rules in a `<style>`, both full files as `media="print"` links, the script that applies them, `<noscript>` blocking links, and the `rel="expect"` render hold |
| A full page load where selection fails, or a Live controller | Blocking links, exactly as Blacklight would emit them |
| A Turbo visit | No layout stylesheets at all |

Every shape carries `<meta name="layout-stylesheets" data-turbo-track="reload">`,
whose content is the two digested paths. A deploy that changes either file
changes the signature, and Turbo does a full reload.

The layout always renders the blocking links, between two HTML comments. After
the action, `CriticalCssInlining` swaps them for the inline shape only when
selection succeeds. So the safe shape is the default, and every failure,
including an exception, leaves it in place. A Live controller, such as the
download queue, has already sent its headers and is streaming its body, so it
keeps the blocking links.

## How the rules are picked

Selection is done on each response, at runtime. Nothing is generated ahead of
time, so nothing can go stale when a template or a stylesheet changes.

1. `Stylesheet` splits each compiled file into top-level rules. A rule inside
   `@media` or `@supports` keeps its chain of at-rules. The split is parsed once
   for each set of asset digests and cached in the process. In development, a
   rebuilt stylesheet therefore takes effect on the next request.
2. `Selector` turns each selector into the tokens it needs: tag names,
   `.class`, `#id` and `[attribute`.
3. `Markup` collects the same tokens from the rendered HTML. It scans the raw
   text, not a parsed tree, so markup inside a `<template>` counts too.
4. A rule is kept when every token of any one of its selectors is on the page.
   `@font-face` is always kept. An `@keyframes` is kept when a kept rule names
   it. Consecutive kept rules under the same at-rule chain share one wrapper.

Every simplification may only drop a requirement, never add one. Pseudo-classes
and pseudo-elements are ignored, and so is the whole argument of `:not()`,
`:is()`, `:where()`, `:has()` and `:nth-*()`. An extra rule costs bytes. A
missing rule makes the page shift when the full file lands.

The scan works on bytes, not characters. Indexing a multibyte UTF-8 string by
character offset is linear for each call, which made the scan quadratic: about
1.5 s against about 75 ms.

## Why the full files can override safely

The inline rules are copies of rules in the full files, in the same order. They
sit before the full files in `<head>`. When the full files apply, every inline
rule has a later twin with the same specificity, so the cascade comes out the
same as with the full files alone. Before they apply, the page has a subset of
the same cascade, taken in the same order.

This holds only because the inline CSS is copied, not written by hand. A
hand-written rule would stay in force until the full CSS overrode each of its
declarations.

## Turbo

Turbo compares tracked `<head>` elements by their exact HTML. The deferred links
change their own `media` attribute once they load, so they cannot carry the
reload signature. The meta tag never changes, so it carries the signature.

A Turbo visit keeps the current `<head>` stylesheets and appends any new ones
after them. Two problems follow if a Turbo response carries stylesheets. A
`media="print"` link never matches the live `media="all"` one, so Turbo appends
another copy on every visit. A page's inline rules, appended after the full
files, would also beat rules that came after them in the original order. So a
Turbo response carries none. `StylesheetsHelper#turbo_request?` reads the
`X-Turbo-Request-Id` header that Turbo sends with every request, and the
response `Vary`s on it.

The first page's inline `<style>` stays where it was, in front of the links.

A click made before the deferred files have landed would render the next page
with only the first page's inline rules. The apply script therefore holds any
`turbo:before-render` until both files have loaded or failed.

## The render hold

`<link rel="expect" href="#blacklight-modal" blocking="render">` holds the first
paint until the layout's last element has been parsed. Without it, a page
arriving over a slow link paints half-parsed and then shifts as later markup
lands. The facet sidebar is the worst case: it follows the results in the source
but displays before them. With blocking stylesheets, the first paint waited for
the CSS, so the document was always fully parsed by then. Browsers without
support ignore the hold and render progressively.

## What it does not cover

- **Classes that JavaScript adds after the page loads.** Their rules are not in
  the markup, so they apply when the full files land, usually within a second or
  two.
- **Other layouts.** Only Blacklight's base layout calls the helper. The mailer
  layout and the static error pages are untouched.
- **Returning visitors.** A full load always sends the inline rules, even when
  the full files are already cached. With a warm cache, the deferred files apply
  almost at once, so a cookie-gated "send plain links" path would save only the
  inline bytes. It was left out to avoid a cookie, a `Vary: Cookie`, and a third
  branch.

## Verifying a change here

The specs cover the parser, the selector and markup tokens, the three heads, the
fallback, and the Blacklight override (`spec/services/critical_css*`,
`spec/requests/critical_css_spec.rb`, and
`spec/views/layouts/blacklight_base_override_spec.rb`). The last of these fails
when a Blacklight upgrade changes its base layout, so the override can take the
change.

A spec cannot see layout shift, so check a change in Chrome as well. These two
checks are reliable:

- **Load each page twice: once with the full stylesheets blocked, once
  normally.** Compare every element's bounding box. Any difference is a shift
  waiting to happen. Only animated elements, such as a spinner, may differ.
- **Throttle the network and record layout shifts** with a `PerformanceObserver`.
  Uncompressed development HTML exaggerates progressive rendering, so compare
  against `develop` under the same throttle rather than against zero.
