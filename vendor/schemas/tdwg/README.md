# Corrected TDWG Darwin Core schemas

These files stand in for TDWG's published Simple Darwin Core schemas. The
published set does not compile under libxml, so a Darwin Core record could not
be validated against it at all. `config/kataba_mirrors.yml` maps each published
URL to the copy here, and Kataba reads the copy instead of fetching the
original. The other files in the chain, from Dublin Core and the W3C, still come
from their publishers unchanged.

The Darwin Core standard and these schemas are © Biodiversity Information
Standards (TDWG), published under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
at <https://github.com/tdwg/dwc>. The originals live at
`http://rs.tdwg.org/dwc/xsd/`.

## What changed

| File | Change | Why |
|---|---|---|
| `tdwg_dwc_simple.xsd` | `ref="dwc:waterbody"` becomes `ref="dwc:waterBody"` | `tdwg_dwcterms.xsd` declares `waterBody`. No `waterbody` exists, so the reference does not resolve. |
| `tdwg_dwcterms.xsd` | One added `xs:import` of `tdwg_chrono.xsd` | The file declares the Chronometric Age terms in its own `dwc:` namespace, but refers to them as `chrono:` terms, and never imports that namespace. |
| `tdwg_dwc_extensions.xsd` | The same added `xs:import` | The same reason. |
| `tdwg_chrono.xsd` | New | It declares each referenced `chrono:` term as a string, so that the references resolve. TDWG's own declarations sit in the `dwc:` namespace, and one is misspelt (`chronometriAgeID`). |

**The chrono stub is a local workaround, not a correction of TDWG's design.**
It duplicates TDWG's declarations in a second namespace and drops their
`dwc:nonEmptyString` type. That does not affect DRS, because
`tdwg_dwc_simple.xsd` refers to no Chronometric Age terms. If TDWG resolves
the namespace mismatch, replace the stub with whatever they publish.

## Upstream reports

Each patch is reported to TDWG. When an issue is resolved, take TDWG's fix and
drop the matching patch here.

| Patch | Reported in | Retire it when |
|---|---|---|
| `waterBody` in `tdwg_dwc_simple.xsd` | [tdwg/dwc#1086](https://github.com/tdwg/dwc/issues/1086) | TDWG's `tdwg_dwc_simple.xsd` refers to `dwc:waterBody` |
| The chrono imports and `tdwg_chrono.xsd` | [tdwg/dwc#1087](https://github.com/tdwg/dwc/issues/1087) | TDWG resolves the namespace mismatch. Their fix may differ from ours, so adopt theirs rather than keeping both |

## The copies

Each edit is one line. The copies also use LF line endings and drop TDWG's
trailing spaces, as this repo requires, so compare them with the originals
using `diff -b`.

## Updating

1. Download the new originals from `http://rs.tdwg.org/dwc/xsd/`.
2. Check tdwg/dwc#1086 and #1087, then reapply only the patches TDWG has not
   fixed.
3. Clear the Kataba schema cache on every host. Kataba never refreshes a cached
   schema, so without this step it keeps validating against the old copy.

If TDWG resolves both issues and its schemas compile, delete this folder and
its entries in `config/kataba_mirrors.yml`.
