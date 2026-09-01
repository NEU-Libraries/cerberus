# Ingest

How a staged upload becomes a Work with its derivatives, and how the batch
loaders survive a retry.

Source files:

- `app/services/ingest_dispatch.rb`
- `app/jobs/multipage_ingest_job.rb`
- `app/services/xml_validator.rb`

## Routing a staged upload

`IngestDispatch` is the single home for "what does this file type get?". Both
the single-file deposit (`WorksController`) and the XML loader (`XmlIngestJob`)
call it, so the two ingest paths cannot drift apart.

| Staged type | Enrichment |
|---|---|
| `image/*` | `IiifAssetsJob` — JP2 and thumbnail Delegates |
| `application/pdf` | `IiifAssetsJob` — `MasterJp2` rasterizes page 1 via vips and poppler |
| Word, PowerPoint | `PdfRenditionJob` — LibreOffice writes a PDF rendition Blob, and thumbnails come from that rendition's first page |
| everything | `ContentCreationJob` — the primary Blob. Enrichment never gates or blocks it |

Full text rides alongside, for body-text search and the "Full Text Match"
snippet. Native PDFs and plain text get `FullTextExtractionJob` from here.
Office documents get theirs from the PDF rendition instead: `PdfRenditionJob`
enqueues it on the converted PDF, so LibreOffice runs once rather than twice.

No `derivative_widths` pass through here. A deposit gets thumbnails at upload
time only. Small, medium and large are opt-in download renditions chosen later
on the metadata page, by `DepositDerivativesJob`, and by policy a document gets
thumbnails only — never S/M/L.

### Two flags that look alike and are not

`include_primary:` and `complete_work:` are different facts. Reading one as a
second name for the other will break a path.

**`include_primary:`** controls whether this call creates the primary Blob.

- The deposit and loader paths leave it `true`; the primary Blob is created here.
- The admin "replace a file" path passes `false`. `Blob.update` writes the
  primary bytes separately and preserves the NOID, so only the type-routed
  *derivative* refresh is wanted here — never a second `ContentCreationJob` or
  `Blob.create`.

**`complete_work:`** asks whether anything still owes this Work its metadata.

- A batch loader has already supplied the metadata, so ingest completing the
  Work is correct.
- An interactive deposit has not: a human confirms on the form's second page.
  That path passes `false`, and `ConfirmDepositJob` completes the Work later.

### Detecting the type

Detection sniffs the staged file with Marcel rather than trusting a
browser-supplied content type, which the loader path does not have at all.

Legacy Office files (`.doc`, `.ppt`) need a second step. Their magic bytes say
only "OLE container", and Marcel keeps the magic type, because its hierarchy
roots `msword` and `ms-powerpoint` under `x-tika-msoffice` rather than
`x-ole-storage`. For those ambiguous container types the filename decides.

## Multipage pages, and retry safety

`MultipageIngestJob` runs once per page row. `MultipageItemJob` enqueues it
after that item's Work is minted and `work_pid` is stamped on the row, which is
why the row id is the only argument.

Each page becomes an ordered FileSet — position is the manifest Sequence —
holding the page binary as its Blob. Page jobs parallelise safely, because each
job touches only its own FileSet, across every item in the load.

### The two Atlas writes behave differently

Retry safety is the design centre of this job, and it exists because the two
writes are not alike.

| Write | Behaviour on a repeat call |
|---|---|
| `FileSet.create` | Idempotent, keyed on `ingest.idempotency_key`. The result is stamped on `file_set_pid`, so a retry skips or converges |
| `FileSet.update` (the binary PATCH) | **Appends a new Blob every time it is called** |

`blob_attached_at` is stamped immediately after a successful PATCH. On a
resumed execution only — meaning `file_set_pid` was already set when the job
started, so a previous attempt got past the create — the job asks Atlas before
PATCHing, so a lost response cannot double-attach the page. The happy path makes
no extra reads.

### What page 1 does that other pages do not

Page 1 seeds the Work-level thumbnails through `IiifAssetsJob`, which self-guards
on an existing thumbnail.

Every page, page 1 included, gets its own IIIF image-service pointer: a JP2 plus
the FileSet-level `iiif_service` PATCH, for manifest assembly. See
`persist_page_service!`.

`ContentCreationJob` is never enqueued here. It calls `Work.complete`, which is
`CompleteWorkJob`'s responsibility, exactly once, after every page has landed.

## Validating MODS XML

`XmlValidator` runs phased checks and returns an Array. The document is valid if
and only if that array is empty. Errors stringify cleanly for display, because
`Nokogiri::XML::SyntaxError` responds to `to_s` and the rest are plain strings.

Syntax runs first. If the document does not parse, schema checks are skipped —
you cannot schema-validate XML that does not parse.

### The phases this class deliberately omits

**Phase 3, business rules** — required fields, date formats — is not here on
purpose. Different consumers want different rule sets: the XML editor, IPTC
ingest, and future bulk loaders. Layering them onto this generic XSD-floor
validator would widen every consumer's contract at once.

**Phase 4, does the MODS-display partial render?** belongs to the caller, via
`AtlasRb::Resource.preview`, because rendering lives in Atlas.

### Reporting an impossible character before the parse

A character that XML 1.0 cannot store is reported ahead of the parse. libxml
fails on it too, but answers with `PCDATA invalid Char value 11`, which names
neither the character, nor the fact that Word wrote it as a manual line break,
nor what to put in its place.

Nothing is lost by pre-empting. Such a document never parses, so the phases
below could not have run either way.
