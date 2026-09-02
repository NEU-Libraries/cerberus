# Derivatives and attached tracks

What a Work's IIIF assets are, which of them are gated, and why a caption
upload has to wait.

Source files:

- `app/jobs/iiif_assets_job.rb`
- `app/jobs/caption_job.rb`

## Seeding a Work's IIIF assets

`IiifAssetsJob` seeds from one staged source: an image, or a PDF whose first
page `MasterJp2` rasterizes. The PDF may have been deposited directly or
converted from Word or PowerPoint by `PdfRenditionJob`.

`MasterJp2` mints two JP2s — a capped display copy and a full-resolution copy.
This job PATCHes their Delegate URLs to Atlas.

### Three asset families, each on its own pipe

| Family | Source JP2 | When it is generated |
|---|---|---|
| Thumbnails (`thumbnail`, `thumbnail_2x`, `preview`) | the **open**, display-capped copy | always. Catalog rows and show pages need them for every image-bearing Work |
| `service_file` | the **gated** full-resolution copy | always. PATCHed onto the content FileSet |
| Small, medium, large | the **gated** base | only when the caller passes `derivative_widths:` |

`service_file` does double duty. It is the deep-zoom source, and it is the
anchor from which `DepositDerivativesJob` later recovers the gated base for
opt-in S/M/L. `persist_service!` writes it onto the single content FileSet, and
skips when that FileSet is not listed yet.

### Who passes widths, and who does not

- **IPTC ingest** passes per-image widths from its own `widths_for`, which
  reproduces v1 sizing.
- **The single-file deposit** chooses sizes on the metadata page, *after* this
  job has run. `DepositDerivativesJob` handles them, recovering the gated base
  from the `service_file` Delegate this job set.
- **Callers that pass nothing** at seed time — deposit, XML loader, multipage
  page 1 — get thumbnails and `service_file` only.
- **A replace passes no widths either**, but it is not a first seed. The sizes
  were chosen once, at deposit, and only the Work's stored rendition URIs still
  record them, so `existing_widths` reads them back. That keeps the download
  renditions in step with everything else the refresh rebuilds.

### `refresh:` versus a first seed

`refresh:` distinguishes "seed the assets" from "re-derive them".

The existing-thumbnail guard is what makes a *deposit* idempotent under Solid
Queue retries. But that same guard reads as "already done" on a Work whose bytes
have since been replaced, which is exactly when the assets most need rebuilding.
`refresh: true` is how a replace or rollback says the guard does not apply.

## Attaching a caption track

`CaptionJob` attaches a depositor's WebVTT file to a Work. It is backgrounded
like the other Blob writers, so the request returns before the bytes cross the
wire, and it stages to disk first (`UploadStaging`) for the same reason.

### It replaces rather than accumulates

A Work has one caption track. A second upload rewrites the bytes of the Blob
already there: `Blob.update` appends an OCFL revision and preserves the NOID, so
the superseded captions stay retrievable and every page already pointing at that
Blob keeps working. Only the first upload creates.

### Waiting for the primary file is load-bearing

The guard that waits for the Work's primary file is not defensive. Removing it
corrupts the preservation record.

Atlas gives every content Blob the role `original_file`, so a caption satisfies
the `PrimaryFilePresence` test that `ConfirmDepositJob` waits on. Attaching a
caption first would let a deposit complete around captions alone — and Atlas
builds the Work's METS structMap at completion, recording a preservation
structure that omits the video.

Waiting also orders this write after the deposit's own, so the two Blob writers
do not race.

### What happens when the wait runs out

Exhausting the retry budget leaves the Work with no captions, and says so in the
log. That is the right outcome. A Work whose video never landed has nothing to
caption, and the deposit itself is already on the needs-attention list for the
missing video.

### Attach-only

Like `AddFileJob`, this job runs no derivative enrichment. A caption upload
leaves the Work's thumbnail, poster and player untouched.
