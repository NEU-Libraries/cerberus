# Uploads

How a file gets from the browser to the staging volume. Every upload form shows
a measured progress bar, and the four large-file forms send their file over TUS,
a resumable protocol, before the form itself is submitted.

Source files:

- `app/javascript/controllers/upload_progress_controller.js` (the bar, and both
  ways of sending)
- `app/views/shared/_upload_progress.html.haml` and
  `app/assets/stylesheets/_upload_progress.scss` (the panel)
- `app/helpers/uploads_helper.rb` (`upload_progress_form_data`, the form wiring)
- `app/controllers/tus_uploads_controller.rb` (the TUS endpoint)
- `app/services/tus_store.rb` (where the endpoint keeps uploads)
- `app/controllers/concerns/upload_staging.rb` (`submitted_file`, the claim)
- `app/jobs/tus_sweep_job.rb` (removing abandoned uploads)
- `vendor/javascript/tus-js-client.js` (the TUS client, version 4.3.1)

## Why the bar is ours, not Turbo's

Turbo's progress bar is driven by time, not bytes. It eases toward full while a
request is in flight, so it reads as finished long before a large file has
left the browser, and a stalled upload looks the same as one that is about to
finish. UAT reviewers preferred the measured bar the loader form already had,
so every upload form now uses it.

Only XMLHttpRequest reports upload progress. `fetch` has no upload progress
event, and a plain form submit reports nothing, so Turbo cannot be asked for
this.

The bar has two phases, and keeping them apart is the point. The bytes leaving
the browser are a measurable fraction. The server's work afterwards is not, so
once the last byte is sent the bar turns indeterminate and the label says what
the server is doing. Reporting that wait as 100% is what made the old bar
misleading.

## Wiring a form

Give the form the helper's data attributes, and render the panel inside it:

```haml
= form_with url: …, multipart: true, data: upload_progress_form_data(resumable: true) do
  = render layout: 'shared/file_field' do
    %input#binary.file-field__input{name: 'binary', type: 'file', required: true}
  = render 'shared/upload_progress', extra_class: 'mt-3'
```

`upload_progress_form_data` keeps the form's own controllers and actions. It
takes `processing_label:` and `processing_note:` for the indeterminate phase,
as the loader does with "Unpacking on the server".

The controller only steps in when a file is chosen. A metadata form whose
optional thumbnail or caption field is empty submits through Turbo as usual.

## The two ways of sending

| Way | Forms | How |
|---|---|---|
| Resumable | deposit, Upload a file, admin Replace a file, loader archive | The file goes to `/tus` in 16 MiB chunks. The form is then submitted through Turbo, with the file input disabled and a hidden `tus_upload_id`. |
| Whole | thumbnails, captions, Darwin Core | The form goes as one multipart XHR. |

Pass `resumable: true` only for an action that claims `tus_upload_id`. Any
other action would receive the form with no file.

**The resumable way falls back to the whole way.** If tus-js-client fails to
load, or the browser lacks what it needs, the controller sends the multipart
form instead. The file input keeps its name for this reason, and the form still
works with JavaScript off.

**A whole-way response is rendered from the XHR, not fetched again.** XHR
follows the action's redirect itself, so its response is already the page to
land on, flash included. The controller hands that HTML to `Turbo.visit` as a
preloaded response. Navigating to `responseURL` instead would issue a second
GET, which finds the flash already spent. A 422 response replaces the body in
place, which keeps its inline alert.

## The TUS endpoint

`TusUploadsController` implements TUS 1.0.0: the core protocol plus the
`creation` and `termination` extensions.

| Request | Route | Answer |
|---|---|---|
| `OPTIONS` | `/tus` | 204, with `Tus-Version` and `Tus-Extension` |
| `POST` | `/tus` | 201, with `Location` |
| `HEAD` | `/tus/:id` | 200, with `Upload-Offset` and `Upload-Length` |
| `PATCH` | `/tus/:id` | 204, with the new `Upload-Offset` |
| `DELETE` | `/tus/:id` | 204 |

The rules that differ from a typical Rails action:

- **It answers 401, not a sign-in redirect.** The caller is tus-js-client, not
  a page.
- **Uploads belong to a NUID.** A session-built `User` has no other stable
  identity. An upload that belongs to someone else is a 404, the same as an
  unknown id, so an id cannot be probed.
- **The upload's offset is the data file's size.** If a chunk half-lands, the
  offset still matches the bytes on disk, and the client resumes from there.
- **A chunk never grows the file past its declared length.**
- **CSRF protection stays on.** The client sends the page's `csrf-token` in
  `X-CSRF-Token`.
- **Each chunk fits inside the request deadline.** Puma buffers a request body
  before the action runs, so the 20-second deadline covers only the copy of
  one 16 MiB chunk to disk. One multi-gigabyte request never has to.

## Where uploads live

`TusStore` keeps each upload under `<uploads_root>/tus/` as two files: the data,
named by a 32-character hex id, and `<id>.json`, holding the declared length,
the filename, the type and the owner's NUID. The filename is reduced to its
basename on the way in, because it becomes a path under the staging root.

`submitted_file` in `UploadStaging` claims a finished upload for the signed-in
user. An unfinished upload, an unknown id or another user's upload all claim as
nil, which the action treats as no file at all. Staging then *moves* the data
file into place rather than copying it. The upload is already on the staging
volume, and copying a multi-gigabyte file a second time is the cost TUS is here
to avoid.

## Abandoned uploads

A finished upload leaves the TUS store as soon as its form claims it. An upload
nobody claims is a tab that closed mid-upload, or a form that was never
submitted. `TusSweepJob` runs hourly (`config/recurring.yml`) and removes any
upload whose files have not changed for `TusStore::EXPIRY` (24 hours). Every
chunk updates the data file, so an upload that is still arriving is never swept.

Development runs no recurring tasks, so uploads abandoned there stay until you
remove them.

## Resuming

tus-js-client remembers an unfinished upload in `localStorage`, keyed on the
file's name, size, type and modification time. If an upload fails, the panel
says so and the submit button comes back. Submitting the same file again
resumes from the last offset the server holds. The client also retries a
dropped chunk on its own, with backoff, before it reports a failure. A finished
upload's entry is removed, so the next upload of the same file starts afresh.
