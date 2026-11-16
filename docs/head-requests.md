# HEAD requests

A HEAD request gets the status and headers a GET would, and Cerberus builds no
body for it. Link checkers, uptime monitors, download managers and crawlers send
HEAD, and most of them read only the status. Without these rules, each one cost
as much as a reader: the whole action ran, a download pulled its file from Atlas,
an archive packed its ZIP, and Rack then threw the body away.

Source files:

- `app/controllers/concerns/answers_head.rb` (pages: skip the template)
- `app/controllers/works_controller.rb`, `collections_controller.rb`,
  `communities_controller.rb` (record pages: stop after the gates)
- `app/controllers/concerns/streams_blob.rb` and `media_controller.rb` (files)
- `app/controllers/concerns/streams_zip.rb` (archives and exports)
- `app/controllers/concerns/records_impressions.rb` (HEAD is not counted)
- `lib/head_without_length.rb` and `config/initializers/head_without_length.rb`
  (the length header)

## The rule: the gates run, the body does not

Rails routes HEAD to the GET action. That is what keeps the status right: the
find, the tombstone check and the authorization gates all run as they do for
GET, so a missing record is still a 404, a tombstone a 410 and a refusal a 403.
What changes is everything after them.

| Response | What HEAD skips |
|---|---|
| Any page | The template. `AnswersHead` overrides `_render_template`, so the status and content type that `render_to_body` applies first still go out. JSON and plain renderers never reach it, so the manifest keeps `application/json`. |
| A Work, Collection or Community page | Also the data only the page shows. `show` returns right after its gates, so a Work makes 2 Atlas calls instead of 9. |
| A download or media file | The bytes. `stream_blob` sets the same headers and answers without calling `AtlasRb::Blob.content`. |
| An archive or export | The ZIP. `StreamsZip#zip_kit_stream` sends ZipKit's headers and answers without packing. |

Other actions still load their data under HEAD; only their template is skipped.
They are rarely the target of HEAD, and a rule that every action must remember
would be easy to miss.

### Include `StreamsZip`, never `ZipKit::RailsStreaming`

`StreamsZip` includes ZipKit and overrides `zip_kit_stream`. A controller that
includes ZipKit directly gets ZipKit's own method, which packs the whole archive
for HEAD.

### What HEAD cannot know

HEAD on a file does not fetch it, so it cannot see that the bytes are missing
from storage behind a valid Blob. GET finds out and answers 404; HEAD answers
200. A missing Blob record still gives 404, because the gates read it.

Media ignores `Range` under HEAD and answers 200 with the whole length. HTTP
defines range handling for GET only.

## The length header

HTTP lets a HEAD response leave out `Content-Length`, but forbids one that
differs from what GET would send. Puma broke that on every HEAD: `Rack::Head`
swaps the body for an empty array, and Puma sizes an array body, so it sent
`Content-Length: 0`.

`HeadWithoutLength` sits outside `Rack::Head` and hands Puma a body with only
`#each`, which Puma cannot size, so it sends no length. A `Content-Length` the
app sets itself is a header, not a computed size, so it still goes out: media
sends its real size. Downloads send none, for GET or HEAD, because they stream
in chunks.

## Analytics

`record_impression` returns early for HEAD, so a HEAD is never a view, a
download or a stream. See [`analytics.md`](analytics.md#recording-an-impression).

## Testing it

`spec/requests/head_requests_spec.rb` covers each kind of response. Request
specs run without Puma, so they cannot see the length header;
`spec/lib/head_without_length_spec.rb` checks the body Puma would be handed.
