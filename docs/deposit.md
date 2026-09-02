# Deposit

How an uploaded file becomes a Work, how the depositor confirms its metadata,
and how a Work that partly failed its pipeline is recorded.

Source files:

- `app/controllers/works_controller.rb`
- `app/controllers/concerns/work_deposit.rb`
- `app/controllers/concerns/descriptive_metadata.rb`
- `app/services/incomplete_flag.rb`
- `app/jobs/application_job.rb`

Per-type enrichment routing — what a PDF or a Word document gets after the
bytes land — is `IngestDispatch`, covered in `docs/ingest.md`. The ACL
vocabulary is in `docs/permissions.md`.

## The controller spans the whole lifecycle

`WorksController` covers deposit, show, edit, tombstone, manifest and
downloads as one cohesive controller rather than being split by verb. That is
why it runs past the default class-length budget and disables the cop.

It pulls in two Blacklight modules that a plain controller does not have:

| Module | Why it is here |
|---|---|
| `Blacklight::Configurable` | The deposit fork's context queries — the depositor's own workspace Collections, and a community's publish showcases via `ShowcaseFinder` — run through the Blacklight `SearchBuilder`, so this controller needs the catalog config. `Admin::PeopleController` uses the same wiring for its community picker |
| `Blacklight::Searchable` | `Blacklight::Controller` supplies `search_state` and the config, but `search_service` itself lives in `Searchable`. `CatalogController`'s subclasses get it by inheritance; this controller does not. The associations box needs it to resolve its edges through the gated search |

`WorksController#search_service_context` plumbs the acting user into the search
service, as `CatalogController` does for its own subtree. Blacklight 8 scopes
every `SearchBuilder` to the `SearchService` rather than the controller. So
without it `SearchBuilder#gated_user` is nil, and the associations box gates as
anonymous. That hides a viewer's own restricted associated Works from them.
`effective_user` honours a view-as session.

## Depositing a file

The form asks what to deposit, never where. The destination is the route's
parent segment, already resolved and `:edit`-gated by
`authorize_destination!`. There is one destination path: the Work lives where
the depositor navigated, and nothing later in the request moves it.

`WorksController#new` renders the form. `@create_path` is the POST target.
Without it `form_tag` falls back to the current URL —
`/collections/:id/works/new`, which routes nowhere for POST — and the deposit
404s on submit.

### Attribution

`WorksController#deposit_attribution` resolves the depositor NUID for a new
Work.

| Situation | Depositor written |
|---|---|
| Acting-as session | The target. This is **pure impersonation**: `proxy_uploader` is left empty server-side, so the resource reads exactly as if the target deposited it. The operating admin's hand is recorded in the `AuditEvent` (actor = admin, `on_behalf_of` = target), not stamped on the Work. The proxy radio is hidden while acting-as (see `works/new`), so this branch wins unconditionally and the radio value is irrelevant |
| `upload_as` is `"proxy"` | The collection's configured depositor. The acting user becomes `proxy_uploader` server-side |
| Anything else, including the default `"myself"` | The acting user, explicitly |

The last row has to be explicit. Passing nil would let Atlas fall through to
the collection's configured depositor, silently flipping "myself" into a
collection-default attribution on collections that have one set.

### The A/V codec gate

`WorkDeposit#unsupported_av?` runs before the Work is created. An A/V file
whose codec is outside the streaming safe set — H.264 8-bit, AAC, MP3 — never
enters the repository; depositors normalise before deposit.

Wrong *containers* are fine, and are remuxed downstream by
`MediaRenditionJob`. Only the codec is gated. The check is a no-op when ffmpeg
is not on the image: it degrades, it never blocks.

### The shared tail

`WorkDeposit#finalize_new_work` runs after the Work is minted. It seeds the
title through the structure-safe MODS merge (raw `mods_xml=`, not the flat
`plain_title=` setter — see `DescriptiveMetadata#save_descriptive!`). It then
applies the parent Collection's derivative-permission default, stages the
upload, and enqueues ingest.

It also holds the filename in `@deposit_title` for the showcase-promotion
notice. That notice runs after it and has no file of its own to read the title
from.

`WorkDeposit#apply_derivative_default` applies the collection's
derivative-access default to the new Work, and is a no-op when the collection
has no Sentinel. The gate is set before any derivative exists; Atlas stores
the policy and applies it when the async renditions arrive.

Atlas refuses a tier more visible than its Work, so a default naming an
audience the Work does not have is rejected. That should not happen — the
authoring form checks the default against its collection, and a visibility
cascade re-clamps it. But the deposit must not die on the Rails error page if
it ever does. The Work and its file already exist by that point, so raising
abandoned a half-made deposit and told the depositor nothing.

It is not silent, though. The default exists to make renditions *more*
restrictive than the Work. So skipping it leaves them at the Work's own
audience — wider than intended, and the depositor is the one who needs to
know.

### What the depositor is told

`WorksController#create_notice` names both post-deposit steps that can fail
without failing the deposit itself. Neither hides that the file is in.

| Constant | What failed |
|---|---|
| `PUBLISH_LINK_FAILED` | Either promotion failure: an unresolvable showcase, or a refused link. Either way the deposit succeeded, which is what the depositor needs to know; the distinction only matters in the log |
| `DERIVATIVE_DEFAULT_FAILED` | Only the collection's per-rendition default was refused, which leaves this Work's renditions at its own visibility rather than the narrower one the collection asked for. Named to the depositor because that is wider access than intended, even though it is never wider than the Work |

`WorksController#enqueue_ingest_jobs` passes `complete_work: false`: the
depositor still owes the metadata page, so ingest must not complete this Work.
No `derivative_widths` go through this path either. Small, medium and large
are opt-in download renditions chosen on the metadata page and applied later by
`DepositDerivativesJob`.

## Promoting a Work into a community showcase

Promotion surfaces the new Work in a community genre showcase via a
linked-member edge. It is orthogonal to placement: the Work's structural home
is wherever it was just deposited, and promotion does not touch it.

`WorkDeposit#publish_offered?` offers promotion only when the destination is
the depositor's own personal root. That is what keeps a promoted Work in the
depositor's own space, now that the route, not a publish branch, decides
placement. It is the property the old publish branch got by relocating the
Work.

The showcase link is a `:system`-attributed write (`AtlasRb::System::Work`),
not a call the depositor's own credential could make. Atlas scopes `:system`'s
grant to a featured Collection on one side and, on the other, to a Work whose
depositor matches the asserted `on_behalf_of` NUID.

`WorkDeposit#promote_to_showcase` rescues `AtlasRb::ForbiddenError` as a
safety net for that scoping — a misconfigured showcase, or an
`on_behalf_of`/depositor mismatch — not as the expected path. The Work is
already deposited and intact by the time it can fire, so only the promotion
failed. `@publish_link_failed` lets `#create` say exactly that, rather than a
false "published" notice or a 403 page hiding a Work the depositor can already
see.

### The two refusals

`WorkDeposit#promote_if_requested` refuses in two cases before it tries:

| Reason token | Meaning |
|---|---|
| `not_personal_root` | The destination is not the depositor's own root, so the form never offered promotion here — a typed URL, or a tampered field |
| `no_showcase` | No showcase exists for that genre in that community, or the depositor cannot see the one that does |

A promotion that cannot be honoured leaves the deposit standing. The Work
already exists and is correctly placed, so there is nothing to roll back.

### The ledger

`WorkDeposit#record_promotion` writes an `AdminNotice` for every promotion
attempt, refusals included.

A showcase is a curated public surface that nobody approves onto. So staff read
the list afterwards to catch a Work promoted that belongs on no showcase at
all, or filed under the wrong genre. That is why it carries every attempt
rather than only the anomalies.

A refusal is the outcome nobody else can see. The Work deposits correctly, the
depositor gets one flash and moves on, and the showcase silently does not gain
it. So without this row, only a log line records that somebody asked to publish
and did not.

The payload carries `work_title`, the filename the deposit was titled with. It
is the strongest wrong-genre signal available, and it is free: a `.pptx` filed
under "Datasets" reads wrong at a glance. It is a snapshot, so a later rename
leaves it alone, which for a review list is what you want to see.

`WorkDeposit#promotion_community_name` resolves the community name here rather
than through `DepositorContext#community_name`, which assumes a real
affiliation and dereferences the resource unguarded. This noid comes straight
from the form, so it can name nothing at all.

## Confirming the deposit

`WorksController#metadata` renders the second page of the deposit, and
`#update_metadata` is the depositor confirming it.

Both probe the **staged file**, not the Work's assets. `ContentCreationJob`
may still be in flight when the page renders. And asking Atlas would hide the
streaming-only toggle and the caption field from exactly the deposits that
want them. `StagedVideoProbe` is called once and shared, since both sections
ask the same question of the same upload. `StagedImageProbe` gates the opt-in
Image Derivatives section and is nil for non-image deposits.

By `#edit` time the situation has reversed. The content Blob has landed and
the staged upload is long gone, so that action decides off the Work's own
assets.

The order inside `#update_metadata` is load-bearing:

1. `handle_metadata_update` — the descriptive save.
2. `process_derivative_widths` — after the descriptive save, deliberately.
   With a live worker, `DepositDerivativesJob` can execute within this same
   request, and its Delegate PATCH bumps the Work's optimistic lock.
   Enqueueing first raced `save_descriptive!` into
   `AtlasRb::StaleResourceError`. It was seen live and is invisible to specs,
   whose test adapter never runs the job inline.
3. `apply_streaming_only!`.
4. `apply_caption!` — before the confirm, so the caption Blob is queued behind
   the deposit's own finalization rather than ahead of it. `CaptionJob` waits
   for the primary file regardless; see `docs/derivatives.md`.
5. `ConfirmDepositJob.perform_later` — this save is the depositor confirming
   the deposit, and confirmation is what completes the Work. Ingest
   deliberately leaves it `in_progress`. The completion is deferred to a job
   because Atlas asks callers to complete only once the expected children are
   deposited. The primary Blob may still be in flight.

`WorksController#reject_if_in_progress` blocks `#edit` on an unfinished
deposit. It is a lock, not housekeeping. An unfinished deposit is probably
open on its depositor's screen at the metadata page, and this stops a second
person editing underneath them. The metadata page itself stays reachable to
anyone with edit rights, because it rides `extra_edit`, so an abandoned
deposit can always be finished or withdrawn.

`WorksController#requested_work` memoises that read. `#edit` needs the same
payload the in-progress gate already fetched, and the gate runs as a
`before_action`. So without the memo the edit page reads it twice.

## Editing descriptive metadata

`DescriptiveMetadata` owns the simple-form fields — title, abstract, keywords
— on the Metadata tab. It parses them out of the resource's raw MODS to
pre-fill, and validates what comes back. It merges the edits into the existing
MODS rather than replacing it, so every curated node the form does not own
survives.

The Metadata tab and the Permissions tab are separate forms that both PATCH
`#update` with disjoint fields. `descriptive_submitted?` asks which one
arrived, by looking for `:title`.

### The parameters

`descriptive_params` returns the MODS fields symbol-keyed, which is what
`MODSMerge` expects. `keywords: false` — the container case — passes nil, and
leaves keyword subjects untouched.

`curated_subjects_posted?` casts a flag the same form posts, and is
deliberately kept out of `descriptive_params`. That hash is splatted straight
into `save_descriptive!` as the MODS payload, and this is not a MODS field.
Trusting a form value is fine here. The guard is a curation prompt, not a
security boundary — Atlas is that. So the worst a tampered value buys is a
Work saved with no subjects, which the API permits anyway.

### Validation

`descriptive_valid?` requires a title always, and with `keywords: true`
requires that the resource carry at least one subject. The Keywords box is how
a depositor supplies one.

A record whose subjects are all authority-controlled already satisfies that
requirement, and those subjects are curated. `MODSFields` keeps them out of
the box on purpose, and `MODSMerge` never writes over them. So the form posts
`curated_subjects` and it counts. Without that, a curator fixing a title on
such a record would have to invent a redundant keyword to save.

### Writing

`save_descriptive!` merges the fields into the existing MODS and writes via
the raw, structure-safe update path. It preserves every curated node the form
does not own, and skips the write — and a needless OCFL MODS version — on a
no-op.

It is wrapped in `with_stale_retry`. Right after a deposit the async
ingest and derivative jobs are still finalizing the same Work, so this
read-merge-write can lose an optimistic-lock race. Re-reading picks up the
current MODS and token.

`load_descriptive!` is the read half. It pre-fills the edit form with the bare
title plus read-only structured parts, the abstract, and the free-text
keywords — exactly what `#update` merges back.

### Creating a container: mint, then title

`mint_titled!` mints a container and gives it its title, in that order and in
one place. It returns the minted resource, or nil when the title was missing.
In that case the flash is already set, and the caller only has to send the
reader back to the form.

The two steps belong together because the invariant spans them. `MODSMerge`
leaves a blank title untouched, so minting first and titling second would
leave an untitled resource in the repository whenever the title is missing.
The guard, `title_missing?`, therefore runs before the mint. The client-side
`required` attribute is only the first line of it; this is the backstop for
JS-off and for a direct POST.

The title is written before anything else the caller wants to do, because
either call can fail against Atlas. This order picks the better wreckage: a
titled resource still holding the ACL it was minted with, which the
Permissions tab can correct. The alternative is a correctly-restricted resource
with no title.

## Adding a file to a finished Work

`WorksController#upload` is the "Upload File" affordance on the show page and
renders the form; `#add_file` handles the POST.

`#add_file` stages the binary to disk and defers the Blob create to
`AddFileJob`, so the request returns immediately — the upload may be multi-GB.
It is attach-only: no derivative enrichment runs, so the Work's thumbnail,
viewer and existing files are untouched. The added file simply appears in the
Downloads card once processing finishes.

## Reading a Work

`WorksController#prepare_show_view` runs the show page's four independent
Atlas reads concurrently through `parallel_show_reads`: MODS, assets, file
sets, and associations.

`mods` carries no nuid and is gated by `Current.nuid`, the real user. Assets
and file sets gate on the effective (view-as) user, whose NUID is resolved on
the request thread because the workers must not touch ActiveRecord.
`WorkAssociations` is resolved on the request thread for the same reason. Its
gate is the search service, which reads the acting user, and a worker holds no
database connection.

`associations_or_none` swallows a failed associations read. The box is
supplementary, so a failure must not take the page with it. That is unlike
MODS, assets and file sets, which the page cannot render without.
`parallel_atlas_reads` re-raises any task's error, so the rescue has to be
inside the task. A nil reads as "no associations" downstream.

`WorksController#manifest` renders an IIIF Presentation 3.0 manifest, one
Canvas per page FileSet in page order. It is read-gated like every other view
of the Work, and the underlying Atlas reads are caller-gated too.

`upload_breadcrumbs` builds the trail for the upload form. The trail is the
Work's structural ancestors, then the Work itself as a link back to its show
page. Then comes a final "Upload File" you-are-here crumb. It mirrors
`ApplicationController#edit_breadcrumb_tail` and differs only in the tail
label, so an editor can back out to the Work via the trail. The Work crumb
passes `match: :exact` so loaf does not mark it current on the `/upload`
sub-path.

## Recording a partly-failed pipeline

`IncompleteFlag` is the one place Cerberus writes Atlas's `incomplete` state.
It records that a Work's pipeline partly failed, and clears the record when it
later succeeds.

An enrichment job that exhausts its retries leaves a Work that is complete and
readable. What it is missing is a PDF rendition, a poster frame, its
thumbnails, its full text. Enrichment deliberately never fails a deposit, so
without the flag the only trace was a line in the log, and nobody found out.
The flag makes that visible without withholding the record.

It is deliberately **not** used for the two failures that already have a
surface:

| Failure | Existing surface |
|---|---|
| A deposit whose confirmation never lands | Stays `in_progress`, which hides it and lists it under "Deposits to finish" |
| A loader row that fails | Named in its load report, with the row and the reason |

Flagging those as well would report the same fact twice, in a weaker way.

The reason is a machine token, and the vocabulary is ours: Atlas stores it
opaquely and does not validate it. `IncompleteReasons` maps tokens to what a
person reads, with a fallback, so adding one needs no view change.

### Which NUID each call uses

`IncompleteFlag.set` takes `nuid:` and requires it from a give-up handler,
where it must come from the job instance the handler is passed
(`job.current_nuid`). A handler runs *outside* `perform`, so
`ApplicationJob`'s `around_perform` has already unwound and the ambient
`Current.nuid` is gone. Atlas then has no principal to authenticate and
refuses the write with a `ConfigurationError`. That failure is caught, so the
symptom is a flag that silently never appears.

`IncompleteFlag.clear` takes no `nuid:`, deliberately. It runs inside
`perform`, where the ambient `Current.nuid` is set and is the more correct
source. A child job invoked with `perform_now` carries no `current_nuid` of
its own, and inherits the caller's through `Current`. So reading the instance
attribute would lose it.

`clear` is called on every successful enrichment run, not only after a flagged
one. Asking Atlas whether the flag is set costs the same round trip as
clearing it, and the clear is idempotent. So a re-run that fixes a Work — a
replaced file re-deriving its assets, say — heals the state on its own.

Neither method raises into its caller. Every call site is either a job's
give-up handler, already the end of a failure path, or the tail of a
successful enrichment. In both, an unreachable Atlas must not turn into a
second failure. The log line is the fallback the flag was invented to replace,
so losing the write costs visibility, not correctness.

## Carrying the acting NUID into a job

`ApplicationJob` carries the ambient acting NUID across the enqueue-to-perform
boundary.

Rails 8.1 has no built-in ActiveJob-to-`ActiveSupport::CurrentAttributes`
propagation: `Current.nuid` set on the request thread does *not* automatically
reach the worker thread that runs the job. Background jobs that call
`AtlasRb::*` without an explicit `nuid:` kwarg rely on the configured
`default_nuid` resolving to `Current.nuid`. If the value is not restored at
perform, the request goes out with no `User:` header, and Atlas's
`require_auth` rejects it with 400. That surfaces as an unrelated
`NoMethodError` when the gem parses the error envelope and returns nil.

`before_enqueue` captures `Current.nuid`, and `around_perform` re-sets it for
the duration of `perform`. Child jobs enqueued mid-perform inherit the value
the same way, because their own `before_enqueue` runs while the parent's
`around_perform` has `Current` populated.

`before_enqueue` does **not** fire on `perform_now`. When a parent job invokes
a child that way — `IiifAssetsJob` coordinating `ThumbnailCreationJob` and
`DerivativeCreationJob` serially, for instance — the child's `current_nuid` is
nil. Falling through to the caller's `Current.nuid` in `around_perform` keeps
the inherited NUID instead of wiping it.
