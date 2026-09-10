# Downloads

How Cerberus hands bytes to a requester: one Blob, one gated image tier, or a
streamed ZIP of many. Also the pieces that mint and sign the gated image
derivatives those downloads serve.

Source files:

- `app/controllers/downloads_controller.rb`
- `app/controllers/derivative_downloads_controller.rb`
- `app/services/zip_entry_writer.rb`
- `app/services/set_zip_packer.rb`
- `app/services/queue_zip_packer.rb`
- `app/services/metadata_export_packer.rb`
- `app/services/iiif_signer.rb`
- `app/services/master_jp2.rb`
- `app/services/derivative_creator.rb`
- `app/jobs/deposit_derivatives_job.rb`
- `app/jobs/pdf_rendition_job.rb`

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

The branch reads the classification, not the "Zip File" download label. That
label is shared between generic Blobs and genuine archive uploads, so branching
on it would re-wrap real archives.

### Naming the outer zip

`zip_filename` builds `<base>.zip`, taking the base from the Blob's download
name, then its `original_filename`, then its noid. Only the outer archive is
renamed. The entry inside keeps its real extension, from
`ZipEntryWriter#entry_filename`.

### An on-the-fly archive cannot honour Range

`zip_kit_stream` serves 200 with no `Accept-Ranges`, because the archive does
not exist until it is written. That is acceptable here: the Blobs that get
wrapped are rare one-off opaque files.

### The second gate, beyond the Work

`authorize_show!` checks the Work. `authorize_derivative_read!` then checks the
Blob itself, because a Blob carries its own read gate. A department may reserve
the master, or a non-image rendition, while access copies stay public.

That gate lives on the Work's assets payload, not on the standalone Blob. So
the controller resolves the containing Work — the same lookup the impression
path uses. It then finds this Blob's entry, and authorizes it against the
standard `:read` Ability. It also refuses an unfinished deposit, and an
embargoed Work unless the effective user may bypass the embargo. The embargo
needs its own Atlas call: the Blob's own permissions, which `authorize_show!`
already fetched, do not carry the Work's embargo.

The method memoizes the resolved entry as `@derivative_asset`. So `show` can
branch zip-versus-raw off its classification without a second assets fetch, and
`download_zipped` can hand it to `BlobZipPacker`.

**It fails open when the asset cannot be resolved.** The work-level gate has
already passed at that point. A Blob absent from the assets list is an edge
case rather than a gate to bypass. A nil asset also serves raw.

## Downloading a gated image tier

`DerivativeDownloadsController` delivers a Work's gated small, medium and large
derivatives.

Those tiers' Delegate URIs live on the gated Cantaloupe host, which serves only
a signed request. Rather than link them directly, the downloads UI routes each
tier through this controller. That controller re-reads the tier's per-viewer
gate, and authorizes the effective user against it — reusing the app's `:read`
Ability via `DerivativesHelper`. It then 302s to a short-lived signed URL. The
signature binds the size, so the recipient cannot edit the request up to `full`
or `max`.

Deep zoom is a different flow. It is the service tier, driven by a cookie rather
than a download, and is handled elsewhere.

### A control labelled Download has to download

The redirect lands on Cantaloupe, so the browser obeys *Cantaloupe's* headers
rather than Cerberus's. A `download` attribute on the link is ignored across
origins, and with no disposition the JPEG simply renders in a new tab. From one
list, under one word, the master row would save a file while the size rows
opened a viewer.

Cantaloupe reads `response-content-disposition`, so `download_url_for` appends
it after signing.

### Naming a tier's file

`derivative_filename` mirrors the master row's `master_<noid>.jpg`: the tier,
then the Work, as `<slug>_<work_noid>.jpg`. Three tiers of three Works therefore
do not collide in one Downloads folder. The tier slug matches the entry names
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
compression, the labelled consumer-facing naming, manifest accrual, and
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
- **Write the manifest last**, so a truncated or partial archive is still
  self-describing.

### Folders and names

Folder is the caller's choice. The Set and Queue packers group each Work's
content under its noid; a lone Blob passes nil and sits at the archive root. A
title slug was tried for the folder name and ran absurdly long.

`entry_filename` prefers the labelled `<prefix><noid>.<ext>` Atlas serves, and
otherwise builds a neutral `<noid>.<ext>`. Both are collision-free.
`extension_of` takes the extension only — from `original_filename`, else a MIME
guess, else `bin`.

A derivative has no filename, so `derivative_filename` names it by the slugged
use, for example `small-image.jpg`.

### Reaching Cantaloupe from the server

A Delegate's `uri` carries Cantaloupe's public host, but a packer runs
server-side and, under compose and on staging, reaches Cantaloupe by its
internal service name. `internal_iiif_url` rewrites the host, mirroring
`IiifManifest#info_base`. Only the host changes; the signed path is unaffected.

### Content only, and how a Blob is told from a Delegate

`content_blob?` is the single test: a Delegate carries a `uri` and no
noid-backed bytes, and a content Blob does not.

`SetZipPacker` needs nothing more. Atlas's `GET /works/:id/assets` already drops
metadata FileSets and non-downloadable roles, and `content_blob?` drops the
small/medium/large Delegates.

`QueueZipPacker` packs both kinds. Each queue entry is
`{ 'w' => work_noid, 'b' => blob_noid }` for a content Blob, or
`{ 'w' => work_noid, 'd' => use }` for a derivative rendition. It groups by
Work, then matches the Work's assets against those two sets: Blobs by noid,
renditions by use.

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
The display layer enforces them. A restricted tier — a Streaming Only video, a
gated master — therefore arrives looking ordinary. `DerivativeGate.readable?` is
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
failure — is the reason. The stored embargo value is a timestamp, and the
manifest is read by a person, so both render the date rather than
`2029-12-31T00:00:00+00:00`.

### Declaring the Solr fields a packer reads

`SetZipPacker::REQUIRED_DOC_FIELDS` and
`MetadataExportPacker::REQUIRED_DOC_FIELDS` list every Solr field their packer
reads off a doc. A resolver builds its `fl` from them, so a new field lands in
the query by being declared there.

Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`; both packers strip
that prefix.

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

The manifest itself is a small text grid even at the export cap. It is accrued
in memory and written as the final entry once every item has been visited; only
the MODS payloads stream. The `.xlsx` is itself a zip, so it too is STOREd.

### The manifest columns

`HEADERS` matches `XmlLoader::Manifest::COLUMN_LABELS`. `PIDs` is v1's column
name for what is now a NOID, and the loader accepts either.

File Name is left blank. For an update-oriented export, where every row has a
NOID, the loader does not require it. The embargo columns are best-effort from
Solr and otherwise blank, kept so the spreadsheet stays a faithful re-ingest
template.

## Signing a gated IIIF request

`IiifSigner` mints the two credentials the gated Cantaloupe host's authorization
delegate validates. Both are HMAC-SHA256 over the shared secret in
`config.x.cerberus.iiif_signing_secret`.

| Credential | Message | Lifetime | Used for |
|---|---|---|---|
| `sign_url` | the request path, plus the expiry | 5 minutes | one-shot downloads |
| `sign_identifier` | the bare image identifier, plus the expiry | 1 day | interactive deep zoom |

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

`MasterJp2` mints two JP2s from one source. The first is a capped display copy
for thumbnails and preview, served openly. The second is a full-resolution copy
for small/medium/large downloads and deep zoom, served only behind the
delegate.
`IiifAssetsJob` calls it — see `docs/derivatives.md`.

Both files go to the single derivatives root Cantaloupe reads, and are told
apart by an `open-` or `gated-` filename prefix. That prefix is the signal the
delegate gates on: serve `open-*` freely, require a credential for `gated-*`. It
rides through into the IIIF identifier.

A plain hyphen prefix, rather than an `open/…` subpath, keeps the identifier
slash-free. So signed-URL paths carry no `%2F` that could desync between
Cerberus and the delegate.

### The open copy's cap

`OPEN_CAP` is 500, the width of the `preview` hero's `500,` request. Thumbnails
and preview are all downscales of it, and nothing on the open pipe needs more.

Capping there keeps `full/max` on an `open-` identifier safe by construction:
the master's pixels are not in that file.

`capped` caps the **width**, not the longest edge, so the width-500 request
serves without upscaling in every orientation. A longest-edge cap would leave
portrait sources narrower than 500. A narrower source is never upscaled, which
matches `DerivativeCreator`'s posture.

### Rasterizing a PDF

PDFs rasterize through vips' poppler loader, first page by default. At 150 dpi
a letter page comes out about 1275px wide — crisp for the 500px preview tile
without an oversized JP2.

## Choosing rendition sizes

`DerivativeCreator` turns a gated IIIF base and a set of widths into one
rendition URI per role, shaped `<base>/full/<size>/0/default.jpg`.

`DEFAULT_WIDTHS` is one third, one half and three quarters of the source, for
small, medium and large. Ratios are the sane choice across varying source sizes:
they always downscale, never trigger upscaling, and produce derivatives
proportionate to whatever the depositor uploaded.

| `widths:` value | IIIF size emitted | Behaviour |
|---|---|---|
| Integer | `!N,N` | fit within an N×N box, aspect preserved. No `^`, so it never upscales. The deposit opt-in UI caps its sliders at the source's longest edge, which guarantees N is a downscale |
| Numeric ≤ 1 | `pct:N` | a fraction of the source. A pure downscale that never trips Cantaloupe's upscale guard |
| Numeric > 1 | `^pct:N` | upscale |
| nil | `full` | source dimensions, no scaling |

### Reading the sizes back off a Work

`existing_widths` is the inverse of `#call`, recovering the widths that produced
a Work's current renditions from their stored URIs. It returns nil when the Work
has none.

Replacing a Work's bytes mints a new gated JP2. So every rendition has to be
rebuilt against the new base, at the sizes the Work already carries. Nothing else
records those sizes: the depositor chose them once, on the metadata page, and
the URIs are the only place that choice survives.

`ROLES` maps Atlas's stable `role` token for each rendition to the width key.
So a Work's current set can be read back out of an assets listing. Match on that
token, not on the human display label.

`width_for` does the parsing, and lives beside `iiif_size` so the grammar of a
rendition URI is written down in one place.

## Generating the opt-in renditions after deposit

`DepositDerivativesJob` generates the small, medium and large renditions a
depositor chose on the metadata page. It runs *after* the deposit's IIIF assets
already exist.

The chosen sizes render from the Work's **gated** full-resolution JP2, whose
base is recoverable from the `service_file` Delegate that `IiifAssetsJob` set at
ingest.

### The race with `IiifAssetsJob`

A depositor can submit the metadata form before `IiifAssetsJob` has PATCHed the
service. `ServiceNotReady` rides `retry_on` for six attempts of polynomially
longer waits — roughly 16 minutes of cover.

If the service never appears — a `MasterJp2` failure, a dead queue — the
attempts exhaust, and the block logs and swallows. The deposit and its metadata
are untouched, and the depositor can revisit the metadata page to request sizes
again. There is no ingest row to mark failed here, so the log line is the whole
exhaustion story.

The `StandardError` handler also absorbs transient Atlas failures, including the
optimistic-lock 500 raised when another job is still PATCHing the same FileSet.
That serial-PATCH constraint is documented on `IiifAssetsJob`.

## Rendering Word and PowerPoint to PDF

`PdfRenditionJob` enriches a Word or PowerPoint deposit with a PDF rendition —
v1 parity, `thesis.docx` alongside `thesis.pdf`. It also seeds the Work's
thumbnails from the rendition's first page. `IngestDispatch` routes those two
types here; see `docs/ingest.md`.

### Convert first, then wait

`ContentCreationJob` owns the primary Blob. Rather than race it with a second
concurrent Blob writer, this job converts first. Conversion is the slow part, so
the wait is overlapped for free. It then waits for that primary Blob to
appear. The wait
is the `ServiceNotReady` idiom `DepositDerivativesJob` uses.

The wait keys on the **artifact**: an asset whose role is `original_file`. That
is the real precondition. Keying it on the Work's `in_progress` flag reads as
equivalent and is not. That flag means "no depositor has confirmed this
deposit", which an abandoned deposit never does. So a flag-based wait would
strand the rendition on a human rather than on the writer it actually races.

Office documents also get their full text from this rendition rather than from
the original, so LibreOffice runs once rather than twice.

### Enrichment never fails a deposit

The failure posture matches v1. A corrupt document, a hung `soffice`, or a
primary Blob that never lands all exhaust their retries, log, and leave the
deposit intact. `bin/soffice-timeout` kills a hung `soffice` at 120 seconds.
The deposit is left with its primary file present, no rendition, no thumbnail.
A missing `soffice` binary skips the rendition outright.
