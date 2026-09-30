# Downloads

How Cerberus hands bytes to a requester: one Blob, one gated image tier, or a
streamed ZIP of many. Also the pieces that mint and sign the gated image
derivatives those downloads serve.

Source files:

- `app/controllers/downloads_controller.rb`
- `app/controllers/derivative_downloads_controller.rb`
- `app/services/zip_entry_writer.rb`
- `app/services/blob_zip_packer.rb`
- `app/services/set_zip_packer.rb`
- `app/services/queue_zip_packer.rb`
- `app/services/metadata_export_packer.rb`
- `app/services/iiif_signer.rb`
- `app/services/original_jp2.rb`
- `app/services/derivative_creator.rb`
- `app/jobs/deposit_derivatives_job.rb`
- `app/jobs/pdf_rendition_job.rb`
- `app/services/rendition_asset.rb`
- `bin/soffice-timeout`

`IiifAssetsJob`, `CaptionJob` and `StreamingOnly` are covered in
`docs/derivatives.md`. `SetDownloadsController` and the resolvers that feed the
packers are covered in `docs/sets.md`.

## Downloading one Blob

`DownloadsController#show` serves a single Blob two ways.

| Blob classification | What the requester gets |
|---|---|
| `File` — Atlas could not identify the content | a zip generated on the fly, holding the Blob: a grounded, inert download |
| `Archive` | the raw bytes. These uploads are already zips |
| every other classification | the raw bytes |

The branch reads the classification (`GENERIC_CLASSIFICATION`, Atlas's
`Classification.generic.name`), not the "Zip File" download label. That label is
shared between generic Blobs and genuine archive uploads, so branching on it
would re-wrap real archives.

### Naming the outer zip

`zip_filename` builds `<base>.zip`. It takes the base from the Blob's download
name (`filename`), then its `original_filename`, then its noid, and strips the
extension. Only the outer archive is renamed. The entry inside keeps its real
extension, from `ZipEntryWriter#entry_filename`. `BlobZipPacker` puts that one
entry at the archive root and writes no `inventory.csv`.

### An on-the-fly archive cannot honour Range

`zip_kit_stream` serves 200 with no `Accept-Ranges`, because the archive does
not exist until it is written. That is acceptable here: the Blobs that get
wrapped are rare one-off opaque files.

### The second gate, beyond the Work

`authorize_show!` checks the Work. `authorize_derivative_read!` then checks the
Blob itself, because a Blob carries its own read gate. A department may reserve
the original, or a non-image rendition, while access copies stay public.

That gate lives on the Work's assets payload, not on the standalone Blob. So
the controller resolves the containing Work with `AtlasRb::Blob.work`, the same
lookup `MediaController` and `RecordImpressionJob` use. It then finds this
Blob's entry in `Work.assets` and authorizes it against the standard `:read`
Ability, through `DerivativesHelper#derivative_tier_document`. It also refuses
an unfinished deposit, and an embargoed Work unless the effective user may
bypass the embargo. The embargo needs its own Atlas call: the Blob's own
permissions, which `authorize_show!` already fetched, do not carry the Work's
embargo.

The method memoizes the resolved entry as `@derivative_asset`. So `show` can
branch zip-versus-raw off its classification without a second assets fetch, and
`download_zipped` can hand it to `BlobZipPacker`.

**It fails open when the asset cannot be resolved.** That covers a Blob with no
containing Work and a Blob absent from the Work's assets list. The work-level
gate has already passed at that point, so this is an edge case rather than a
gate to bypass. A nil asset also serves raw.

## Downloading a gated image tier

`DerivativeDownloadsController` delivers a Work's gated small, medium and large
derivatives.

Those tiers' Delegate URIs live on the gated Cantaloupe host, which serves only
a signed request. Rather than link them directly, the downloads UI routes each
tier through this controller. The controller finds the Delegate whose `use`
matches the request, and raises `Authorizable::ResourceNotFound` when none does.
It re-reads the tier's per-viewer gate, refuses an unfinished or embargoed Work,
and authorizes the effective user — reusing the app's `:read` Ability via
`DerivativesHelper`. It then 302s to a short-lived signed URL. The signature
binds the size, so the recipient cannot edit the request up to `full` or
`max`.

Deep zoom is a different flow. It is the service tier, driven by a cookie rather
than a download, and is handled elsewhere.

### A control labelled Download has to download

The redirect lands on Cantaloupe, so the browser obeys *Cantaloupe's* headers
rather than Cerberus's. A `download` attribute on the link is ignored across
origins, and with no disposition the JPEG simply renders in a new tab. From one
list, under one word, the original row would save a file while the size rows
opened a viewer.

Cantaloupe reads `response-content-disposition`, so `download_url_for` appends
it after signing.

### Naming a tier's file

`derivative_filename` mirrors the original row's `original_<noid>.jpg`: the tier,
then the Work, as `<slug>_<work_noid>.jpg`. The slug is the parameterized `use`,
or `derivative` when that is blank. Three tiers of three Works therefore do not
collide in one Downloads folder. The tier slug matches the entry names
`ZipEntryWriter` writes into a zip.

## Building a ZIP

Four packers stream into an already-open `zip_kit` writer. They differ in what
they enumerate.

| Packer | What it packs |
|---|---|
| `SetZipPacker` | every content Blob of every Work in a Set |
| `QueueZipPacker` | only the items in a Download Queue — a flat, user-curated list of individually chosen downloads |
| `MetadataExportPacker` | a re-ingestable metadata bundle, no binaries |
| `BlobZipPacker` | one Blob, at the archive root |

`ZipEntryWriter` holds the per-asset write that the content packers share: STORE
compression, the labelled consumer-facing naming, inventory accrual, and
mid-stream error capture. Keeping it in one module is what stops the packers
drifting apart.

### The rules that govern every entry

- **Stream, never buffer.** A Blob's bytes come from Atlas chunk by chunk and go
  straight into the sink, so memory stays flat regardless of set or file size. A
  derivative rides `Faraday`'s `on_data` for the same reason — the whole JPEG is
  never held.
- **STORE, not deflate.** DRS payloads — JP2, PDF, images, curated zips — are
  already compressed, so deflating burns CPU for about no gain.
- **Record a failure, do not raise it.** Once the response headers are out the
  archive cannot be un-sent, so a mid-stream fetch failure becomes an
  `ERRORS.txt` line.
- **Write the inventory last.** `write_manifest` writes `inventory.csv`, then
  `ERRORS.txt` when there are errors, after every file. A truncated or partial
  archive is therefore still self-describing.

### The inventory

The Set and Queue archives end with `inventory.csv`, one row per packed file,
under the header `identifier,filename,handle`. The identifier is the Work's
NOID, which is also the file's folder. The handle is the Work's citable URL,
built by `handle_url`.

A Work's handle is on its Atlas record only, not in Solr, so the inventory
costs one `Work.find` per Work in the archive. `inventory_csv` caches the lookup
per NOID. That is small next to the file
bytes already streamed for each Work. A Work without a handle, or a failed
read, leaves the cell blank rather than an error, because the files are
already sent. A failed file still goes to `ERRORS.txt` and gets no row.

### Folders and names

Folder is the caller's choice. The Set and Queue packers group each Work's
content under its noid; a lone Blob passes nil and sits at the archive root. A
title slug is the obvious alternative for the folder name. It was rejected
because titles run absurdly long.

`entry_filename` prefers the labelled `<prefix><noid>.<ext>` Atlas serves, and
otherwise builds a neutral `<noid>.<ext>`. Both are collision-free. It never
names an entry from `original_filename`.
`extension_of` takes the extension only — from `original_filename`, else a MIME
guess, else `bin`.

A derivative has no filename, so `derivative_filename` names it by the slugged
use, for example `small-image.jpg`.

### Reaching Cantaloupe from the server

A Delegate's `uri` carries Cantaloupe's public host, but a packer runs
server-side and, under compose and on staging, reaches Cantaloupe by its
internal service name. `internal_iiif_url` swaps the public host
(`config.iiif_host`) for `config.x.cerberus.iiif_internal_host`, mirroring
`IiifManifest#info_base`. It leaves the URI alone when either is blank. Only the
host changes; the signed path is unaffected.

### Content only, and how a Blob is told from a Delegate

`content_blob?` is the single test: a Delegate carries a `uri` and no
noid-backed bytes, and a content Blob does not.

`SetZipPacker` needs nothing more. Atlas's `GET /works/:id/assets` already drops
metadata FileSets and non-downloadable roles, and `content_blob?` drops the
Delegates, the small/medium/large tiers among them.

`QueueZipPacker` packs both kinds. Each queue entry is
`{ 'w' => work_noid, 'b' => blob_noid }` for a content Blob, or
`{ 'w' => work_noid, 'd' => use }` for a derivative rendition. It groups by
Work, then matches the Work's assets against those two sets: Blobs by noid,
renditions by use. A content Blob goes through `write_asset`; a rendition goes
through `write_derivative`, which fetches it from Cantaloupe over a signed URL.
A failed assets read for one Work becomes an `ERRORS.txt` line, and the packer
moves on to the next Work.

### Withholding: three checks, and why one is not enough

`Work.assets(nuid:)` re-checks read at Atlas for each Work, so an item that was
queued and later restricted is simply not returned. Anonymous callers get public
Works only.

That is not sufficient, twice over.

**An embargoed Work is deliberately readable.** Its metadata stays public and
only its content is withheld. So it clears both Atlas's read check and the
resolver's gated search, and arrives at the packer looking like any other
member. Without a packer-side embargo check the archive is assembled with the
*owner's* reach and hands an anonymous requester bytes that `/downloads/:id`
refuses them.

**Atlas re-authorizes at the Work level, not the tier level.** The per-asset
gate rides the returned entries as advisory `gated` and `permission` values.
The display layer enforces them. A restricted tier — a Streaming Only recording, a
gated original — therefore arrives looking ordinary. `DerivativeGate.readable?` is
what stops the archive handing out those bytes.

The caller's own rights drive both checks. `ability` and `bypass_embargo` are
the **caller's**, never the Set owner's.

### Where each packer reads the embargo

| Packer | Source of the embargo date | Cost |
|---|---|---|
| `SetZipPacker` | the member's Solr doc, already fetched | free |
| `QueueZipPacker` | `AtlasRb::Resource.permissions` | one Atlas call per distinct Work |

A queue is a bare list of noids with no Solr doc behind it, so `QueueZipPacker`
pays that call. It is acceptable: a queue is user-curated and short, and the
alternative is handing out embargoed bytes.

Both report a withheld item in `ERRORS.txt` rather than dropping it in silence.
Someone asks for a set of twelve and gets eleven files, or queues a file and
does not get it. They should be able to see which one, and that access — not
failure — is the reason. The stored embargo value is a timestamp, and a person
reads `ERRORS.txt`, so both render the date through `Embargo.release_date`
rather than `2029-12-31T00:00:00+00:00`.

### Declaring the Solr fields a packer reads

`SetZipPacker::REQUIRED_DOC_FIELDS` and
`MetadataExportPacker::REQUIRED_DOC_FIELDS` list every Solr field their packer
reads off a doc. `SetResolver::PACKER_FIELDS` is the union of the two, and
`CollectionContentsResolver` uses the export packer's list. So a new field lands
in the query by being declared there.

**A field read but not declared is silently nil.** Solr does not return it, and
nothing raises. For `SetZipPacker` that disables the embargo check on every
document, because `embargo_release_date_dtsi` reads as blank.

| Packer | Fields |
|---|---|
| `SetZipPacker` | `id`, `alternate_ids_ssim`, `embargo_release_date_dtsi` |
| `MetadataExportPacker` | the same, plus `created_at_dtsi` |

Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`; both packers strip
that prefix, and skip a doc with no noid.

## Exporting metadata as a re-ingestable bundle

`MetadataExportPacker` streams a collection's or Set's metadata as a
`manifest.xlsx`, in the exact column shape the XML batch loader reads
(`XmlLoader::Manifest`). Optionally it adds one `mods/<noid>.xml` per item.

It is the inverse of the XML loader: export the records, edit the MODS offline,
re-feed the bundle as updates. Every row carries a NOID, so
`XmlLoader::Manifest::Row#update?` is true for all of them.

`docs:` is anything responding to `each_content_batch { |solr_docs| ... }` —
`SetResolver` and `CollectionContentsResolver` both do. The gating lives in that
enumerator, which yields only the Works the requesting user can discover, so
this packer stays auth-agnostic.

### What it shares with the content packers, and what it does not

It matches their posture — STORE, flat memory, mid-stream error capture. But it
streams MODS *strings* from Atlas rather than Blob bytes, so it does not include
`ZipEntryWriter`.

The manifest is a small text grid even at the export cap
(`SetResolver::MAX_EXPORT_ROWS`, 10,000 rows). The packer accrues it in memory
and writes it once every item has been visited, followed by `ERRORS.txt` when
there are errors. Only the MODS payloads stream. The `.xlsx` is itself a zip, so
it too is STOREd. A failed MODS fetch leaves the row's MODS path blank and adds
an `ERRORS.txt` line.

### The manifest columns

The first five `HEADERS` match `XmlLoader::Manifest::COLUMN_LABELS`, or the
bundle no longer loads back. `PIDs` is v1's column name for what is a NOID in
DRS 2, and the loader accepts `PIDs`, `PID`, `NOID` or `NOIDs`. A sixth column,
Date Ingested, is for the reader: the Work's creation date (`created_at_dtsi`)
in the app's Eastern time zone. The loader ignores columns it does not know, so
the bundle still re-ingests.

File Name carries the name the Work's `original_file` was deposited under,
falling back to its stored name. Solr holds no filename, so it costs one
`Work.assets` read per Work. A failed read leaves the cell blank and adds a line
to `ERRORS.txt`. Every exported row has a NOID, so the loader treats it as an
update and ignores the cell.

The embargo columns come from `embargo_release_date_dtsi` and are otherwise
blank. They stay so the spreadsheet remains a faithful re-ingest template.
Embargoed? is `true` only while the date is still in the future: a lapsed date
is not an embargo. Atlas indexes only the date, never a flag, because nothing
re-indexes a Work on its release day. An `embargoed_bsi` still in the index is
a stale leftover.

## Signing a gated IIIF request

`IiifSigner` mints the two credentials the gated Cantaloupe host's authorization
delegate validates. Both are HMAC-SHA256 hex digests keyed with the shared
secret in `config.x.cerberus.iiif_signing_secret`
(`CERBERUS_IIIF_SIGNING_SECRET`). A blank secret raises `ArgumentError` rather
than signing with nothing. The delegate recomputes both messages the same way,
so their formats must change in lock-step with it.

| Credential | Message | Lifetime | Used for |
|---|---|---|---|
| `sign_url` | `<path>\|<exp>` | `DOWNLOAD_TTL`, 5 minutes | one-shot downloads |
| `sign_identifier` | `<identifier>\|<exp>` | `IDENTIFIER_TTL`, 1 day | interactive deep zoom |

`sign_url` appends `?exp=<exp>&sig=<sig>` to the URL.

The signed URL's message is the request **path**, which includes the IIIF size
segment. A recipient therefore cannot edit the size — `pct:50` to `max` —
without breaking the signature. Because the query string is outside the message,
`DerivativeDownloadsController` can safely append
`response-content-disposition` after signing.

An identifier token authorizes every derived request for that one image —
`info.json` and all tiles — until it expires. A viewer generates its own tile
URLs, so they cannot be signed individually. But they all share the image's
identifier, and a token embedded there rides along on every one. Being carried
in the URL, it needs neither a cookie nor credentialed CORS, so it works with
IIIF's mandated cross-origin `ACAO:*`.

`sign_identifier` rewrites the identifier to `<exp>~<sig>~gated-<uuid>.jp2`. The
`~` avoids Cantaloupe's `;` meta-delimiter and keeps the identifier slash-free.

### Why the identifier's expiry is quantized

The expiry is rounded to a `ttl`-sized window aligned to the epoch. So every
view within that window mints a byte-identical identifier — and so a stable
Cantaloupe derivative-cache key. A fresh wall-clock `exp` per call would give
each page load a unique identifier, defeat that cache, and re-decode every tile
cold on every reload.

It rounds up to the window *after* next, which keeps a token valid for at least
`ttl` and at most `2 * ttl`. One minted anywhere in a window therefore always
has a full `ttl` left, and tiles never 403 mid-view near a boundary.

The delegate reads whatever `exp` it is handed, so its HMAC message,
`<identifier>|<exp>`, is unchanged by the quantization.

## Minting the JP2s a download serves

`OriginalJp2` mints two JP2s from one source. The first is a capped display copy
for thumbnails and preview, served openly. The second is a full-resolution copy
for small/medium/large downloads and deep zoom, served only behind the
delegate. It returns both IIIF bases as `open_base` and `gated_base`.
`IiifAssetsJob` calls it — see `docs/derivatives.md`.

**Every source is converted to 3-band sRGB before encoding.** A grayscale or
CMYK source otherwise yields a JP2 whose header parses, so `info.json`
succeeds. Cantaloupe cannot decode its codestream, though, so every render
answers 501.

Both files go to the single derivatives root Cantaloupe reads
(`config.x.cerberus.derivatives_root`), named `<prefix>-<uuid>.jp2`. They are
told apart by that `open-` or `gated-` prefix. That prefix is the signal the
delegate gates on: serve `open-*` freely, require a credential for `gated-*`. It
rides through into the IIIF identifier.

A plain hyphen prefix, rather than an `open/…` subpath, keeps the identifier
slash-free. So signed-URL paths carry no `%2F` that could desync between
Cerberus and the delegate.

### The open copy's cap

`OPEN_CAP` is 500, the width of the `preview` hero's `500,` request. Thumbnails
and preview are all downscales of it, and nothing on the open pipe needs more.

Capping there keeps `full/max` on an `open-` identifier safe by construction:
the original's pixels are not in that file.

`capped` caps the **width**, not the longest edge, so the width-500 request
serves without upscaling in every orientation. A longest-edge cap would leave
portrait sources narrower than 500. A narrower source is never upscaled, which
matches `DerivativeCreator`'s posture.

### Rasterizing a PDF

PDFs rasterize through vips' poppler loader, first page by default. At 150 dpi
a letter page comes out about 1275px wide — crisp for the 500px preview tile
without an oversized JP2. `load_options` passes `dpi` only when Marcel
identifies the source as a PDF, because the image loaders reject it.

## Choosing rendition sizes

`DerivativeCreator` turns a gated IIIF base and a set of widths into one
rendition URI per role, shaped `<base>/full/<size>/0/default.jpg`.

`DEFAULT_WIDTHS` is one third, one half and three quarters of the source, for
small, medium and large. Ratios are the sane choice across varying source sizes:
they always downscale, never trigger upscaling, and produce derivatives
proportionate to whatever the depositor uploaded.

| `widths:` value | IIIF size emitted | Behaviour |
|---|---|---|
| Integer | `!N,N` | fit within an N×N box, aspect preserved. No `^`, so it never upscales. The deposit opt-in UI (`works/_derivative_fields`) caps its sliders at the source's longest edge, which guarantees N is a downscale |
| Other number, up to 100% | `pct:N` | a fraction of the source, N rounded to a whole percent. A pure downscale that never trips Cantaloupe's upscale guard |
| Other number, above 100% | `^pct:N` | upscale |
| nil | `full` | source dimensions, no scaling |

### Reading the sizes back off a Work

`existing_widths` is the inverse of `#call`, recovering the widths that produced
a Work's current renditions from their stored URIs. It returns nil when the Work
has none.

**A tier whose size does not parse is left out, never defaulted.** `width_for`
returns `:unknown` for a size token this class does not emit, and
`existing_widths` logs a warning and skips that tier. Defaulting would rebuild
Small at full resolution, which is a permission leak.

Replacing a Work's bytes mints a new gated JP2. So every rendition has to be
rebuilt against the new base, at the sizes the Work already carries. Nothing else
records those sizes: the depositor chose them once, on the metadata page, and
the URIs are the only place that choice survives.

`ROLES` maps Atlas's stable `role` token for each rendition to the width key.
So a Work's current set can be read back out of an assets listing. Match on that
token, not on the human display label.

`width_for` (a private class method) does the parsing, and lives beside
`iiif_size` so the grammar of a rendition URI is written down in one place.

## Generating the opt-in renditions after deposit

`DepositDerivativesJob` generates the small, medium and large renditions a
depositor chose on the metadata page. It runs *after* the deposit's IIIF assets
already exist.

The chosen sizes render from the Work's **gated** full-resolution JP2. Its base
is the URI of the `service_file` Delegate that `IiifAssetsJob` set at ingest,
found by role in `Work.file_sets`. The thumbnail Delegate cannot stand in: it
points at the open, capped JP2. The job hands the base to
`DerivativeCreationJob`, and does nothing when the depositor chose no sizes.

### The race with `IiifAssetsJob`

A depositor can submit the metadata form before `IiifAssetsJob` has PATCHed the
service. `ServiceNotReady` rides `retry_on` for six attempts of polynomially
longer waits — roughly 16 minutes of cover.

If the service never appears — a `OriginalJp2` failure, a dead queue — the
attempts exhaust. The block logs a warning and sets the Work's `IncompleteFlag`
with reason `IncompleteReasons::DERIVATIVES`, then swallows the error. The
deposit and its metadata are untouched, and the depositor can revisit the
metadata page to request sizes again. A later success clears the flag.

A separate `retry_on StandardError` (three attempts) absorbs transient Atlas
failures, including the optimistic-lock 500 raised when another job is still
PATCHing the same FileSet. It sets the same flag on exhaustion. That
serial-PATCH constraint is documented on `IiifAssetsJob`.

**`ServiceNotReady`'s handler must be declared after the `StandardError` one.**
ActiveJob matches handlers in reverse declaration order, so the later
declaration takes precedence.

## Rendering Word and PowerPoint to PDF

`PdfRenditionJob` enriches a Word or PowerPoint deposit with a PDF rendition —
v1 parity, `thesis.docx` alongside `thesis.pdf`. It also seeds the Work's
thumbnails from the rendition's first page, by running `IiifAssetsJob` on the
PDF. `IngestDispatch` routes those two types here; see `docs/ingest.md`.

### Convert first, then wait

`ContentCreationJob` owns the primary Blob. Rather than race it with a second
concurrent Blob writer, this job converts first. Conversion is the slow part, so
the wait is overlapped for free. It then waits for that primary Blob to appear.
The wait is `PrimaryFileMissing` on `retry_on` for six attempts, the same idiom
as `DepositDerivativesJob`'s `ServiceNotReady`. A retry skips the conversion
when the PDF is already on disk.

The wait keys on the **artifact**: an asset whose role is `original_file`,
tested by `PrimaryFilePresence#primary_file?`. That
is the real precondition. Keying it on the Work's `in_progress` flag reads as
equivalent and is not. That flag means "no depositor has confirmed this
deposit", which an abandoned deposit never does. So a flag-based wait would
strand the rendition on a human rather than on the writer it actually races.

Office documents also get their full text from this rendition rather than from
the original: the job enqueues `FullTextExtractionJob` on the PDF. LibreOffice
therefore runs once rather than twice.

### Enrichment never fails a deposit

The failure posture matches v1. A corrupt document, a hung `soffice`, or a
primary Blob that never lands all exhaust their retries and log a warning. The
job then sets the Work's `IncompleteFlag` with reason
`IncompleteReasons::PDF_RENDITION`, and leaves the deposit intact: its primary
file present, no rendition, no thumbnail. A success clears the flag.

`bin/soffice-timeout` kills a hung `soffice` at 120 seconds, because libreconv
has no timeout of its own. It also re-runs `soffice.bin` once on exit 81, which
LibreOffice returns after initialising a fresh profile, and libreconv starts
every run with one. A missing `soffice` binary (`WordToPdf.available?` false)
skips the rendition outright.

### One PDF across replaces and reverts

A replace or revert re-runs this job with `refresh: true`. The job then updates
the Work's existing PDF with `Blob.update` rather than creating another one, so
the Work keeps a single PDF that matches its current file. Each earlier PDF
stays as a revision of that Blob.

Deleting the stale PDF and creating a new one was the obvious alternative. It
does not work, because Atlas lets only an admin delete a Blob. This job runs as
whoever replaced the file, and atlas_rb has no system-principal delete.

`RenditionAsset.for` finds the existing PDF from `Work.file_sets`. Atlas
stores a rendition as an ordinary `original_file` in a FileSet of its own, so
nothing on the wire marks it as derived. The name does: the job writes
`thesis.docx` as `thesis.pdf`, and a primary's `original_filename` survives
every `Blob.update`. So the rendition
is the `original_file` PDF whose name stem matches another `original_file` on
the Work. It reads `original_filename` for that match only, and never renders
it.

Two consequences follow:

- A PDF that the depositor attached under the same stem counts as the
  rendition. Updating it appends a revision, so its bytes stay recoverable.
- A Work that already holds several PDFs keeps them. Every replace updates the
  same one, the lowest NOID, and an admin can remove the others.

`MediaRenditionJob` does the same for the MP4 it remuxes from a video or audio
original, such as `talk.mov` to `talk.mp4`, asking `RenditionAsset` with
`mime_types: RenditionAsset::MP4`. An original that is already an MP4 is never
remuxed, and has no other original under its stem, so it is never mistaken for
its own rendition.
