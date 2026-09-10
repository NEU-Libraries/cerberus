# Derivatives and attached tracks

What a Work's IIIF assets are, which of them are gated, and why a caption upload
has to wait.

Source files:

- `app/jobs/iiif_assets_job.rb`
- `app/jobs/caption_job.rb`
- `app/services/streaming_only.rb`

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
have since been replaced. That is exactly when the assets most need rebuilding.
`refresh: true` is how a replace or rollback says the guard does not apply.

## Attaching a caption track

`CaptionJob` attaches a depositor's WebVTT file to a Work. It is backgrounded
like the other Blob writers, so the request returns before the bytes cross the
wire. It stages to disk first (`UploadStaging`) for the same reason.

### It replaces rather than accumulates

A Work has one caption track. A second upload rewrites the bytes of the Blob
already there. `Blob.update` appends an OCFL revision and preserves the NOID.
The superseded captions therefore stay retrievable, and every page already
pointing at that Blob keeps working. Only the first upload creates.

### Waiting for the primary file is load-bearing

The guard that waits for the Work's primary file is not defensive. Removing it
corrupts the preservation record.

Atlas gives every content Blob the role `original_file`, so a caption satisfies
the `PrimaryFilePresence` test that `ConfirmDepositJob` waits on. Attaching a
caption first would let a deposit complete around captions alone. Atlas builds
the Work's METS structMap at completion, recording a preservation structure that
omits the video.

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

## Streaming-only video

`StreamingOnly` decides whether a Work's video may be played but not taken away.

It is a **licensing affordance, not a security boundary**. Anyone who can play a
file can capture it, and nothing here pretends otherwise. What it owes the
depositor is that the repository makes no offer it should not.

The repository therefore offers none of these:

- a download row
- a "download it instead" line under the player
- anything in a bulk zip
- anything but a refusal on the download route itself

### It is expressed in vocabulary Atlas already has

There is no flag of its own. A video Blob is reachable by two routes that are
gated differently:

| Route | Gated by |
|---|---|
| `MediaController` — playback | the Work's own read ACL |
| `DownloadsController` — download | the Work's read ACL **and** the per-asset derivative gate |

So "may I watch this" is a property of the Work, and "may I keep a copy" is a
property of the `video` tier. Restricting that tier is the whole feature.

An absent `video` key means the tier rides the Work's own visibility, which is
what "not streaming only" means. Turning the toggle off therefore **removes**
the key rather than setting it public.

### Computing the audience

Atlas refuses a tier more visible than its Work, so the audience is computed
against the Work's own read ACL rather than assumed. Naming the admin group on a
Work that does not grant it would be refused outright as
`tier_exceeds_resource`.

Intersecting instead always yields a legal policy, and errs restrictive:

- On a public Work, the admin group survives.
- On a group-restricted Work, the tier collapses to `[]` — private, reachable
  only through a full admin's blanket ability.

A restricted Work's video is already limited to the people who can read it, so
that is a coherent floor rather than a degradation.

`ADMIN_AUDIENCE` names only the group. Full admins reach a restricted tier
through `Ability`'s `can :manage, :all`, and a devolved admin is by definition a
member of that group. Naming the group alone therefore covers both. `Ability`
never has to learn about `User#admin_delegate?`, which it deliberately does not
consult.

### Reading the toggle back

`on?` is an exact match on purpose. A `video` tier written by something else,
such as a Collection's Sentinel default, leaves the toggle reading "off".
Turning it off can therefore never quietly widen a restriction this feature did
not impose.

The `key?` test is not redundant with the comparison. On a Work that does not
grant the admin group, `audience_for` is `[]`, and an **absent** tier would
compare equal to it. Without the key test the toggle would read stuck-on for
every restricted Work, and `apply!` would believe it had nothing to write.

### Writing it back

The Atlas write is a whole-object REPLACE, so `apply!` reads the stored policy
back and merges rather than posting bare. Posting bare would silently drop the
Work's image-ladder tiers. It returns without writing when nothing would change,
which keeps a no-op save out of the audit log.

`stored_policy` reads the tier map off the Work payload, because there is no
dedicated reader on the API. The write's own response carries the map too. It
nests it under `work` rather than at the top level the gem's docstring promises,
so it is not used.

### When the toggle is offered at all

`applicable?` asks whether the Work has a video Blob. Both the deposited master
and any remuxed MP4 are `video/*`. A Work therefore matches from the moment its
content lands, not only once it is playable. Delegates — the image tiers — carry
a `uri` and are not content.
