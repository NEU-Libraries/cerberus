# Usage analytics

How Cerberus records an impression, filters it down to human traffic, and scopes
the resulting figures. That covers the repo-wide `/admin` dashboard and the
Analytics tab on a Collection or Community edit page.

Source files:

- `app/controllers/concerns/records_impressions.rb`
- `app/queries/human_impressions_query.rb`
- `app/controllers/concerns/container_analytics.rb`
- `app/helpers/container_analytics_helper.rb`
- `app/helpers/admin/impressions_helper.rb`
- `app/services/repository_composition_report.rb`

## Recording an impression

`RecordsImpressions` is a concern a controller mixes in. It records append-only
usage impressions through Rails callbacks.

The concern is fire-and-forget. The insert, and the dedup throttle in front of
it, run off-request in `RecordImpressionJob`. Recording is therefore cheap
enough to sit immediately before an `ActionController::Live` stream begins.

| Callback | Where it goes | What it records |
|---|---|---|
| `record_view_impression` | `after_action` on `:show` for Work, Collection and Community | a `view` |
| `record_download_impression` | `before_action` on `:show` for Downloads, declared after `authorize_show!` | a `download` |
| `record_media_impression` | the media endpoint | a `stream` or a `download` |

A view is recorded only when the request actually rendered. A tombstone 410 and
an authz 403 are not views, so `record_view_impression` returns early unless the
response was successful.

A download carries the blob id rather than a noid. `RecordImpressionJob` resolves
the containing Work's noid from that blob id.

### Stream against download on the media endpoint

The media endpoint decides between the two by the `Range` header, which is v1's
heuristic:

- A ranged request is a stream — someone seeking or playing back.
- A full request is a download.

One playback session issues many ranged requests. The one-hour `(noid, action,
ip)` throttle collapses them into a single impression.

### Passing the request fields

`record_impression` takes either a resolved `noid` (a view) or a `blob_id` (a
download). The request-derived fields — session id, IP address, referrer, user
agent — are grouped into a single `request_meta` hash so the job's signature
stays small. A missing referrer is recorded as `direct`.

## Filtering to human traffic

`HumanImpressionsQuery` builds the "human" filter: it excludes known-bot
user-agents through the `UserAgent` dimension, excludes volume-offending
`(ip, day)` pairs, and rescues the IP allowlist.

It is a pure SQL-fragment builder. It reads and writes nothing itself. A caller
writes its own `SELECT` or aggregate and appends `from_where_sql`, which aliases
the impressions table `i`.

Two callers share it:

| Caller | Why it uses this |
|---|---|
| `RollupImpressionsJob` | repo-wide figures, persisted hourly |
| `ImpressionsReport` | live scoped reads. A single item's or facet's unique-visitor series cannot wait for the next rollup, and is not worth persisting a table for |

### Volume-offender detection is never noid-scoped

The subquery that finds volume offenders deliberately ignores the `noids`
filter, though it does respect the same date window as the outer query.

An IP hammering the repository across many different noids is abusive traffic
even when the caller only wants one noid's numbers. Scoping the detection would
under-detect it.

### The constructor's parameters

| Parameter | Meaning |
|---|---|
| `conn` | an `ActiveRecord` connection adapter, used for quoting |
| `window_start` | the earliest `created_at` to match |
| `range_end` | an exclusive upper bound on `created_at`, or `nil` for an open-ended trailing window. The repo-wide rollup passes `nil`; it only ever re-derives "since `window_start`" |
| `noids` | restrict matched rows to these noids, or `nil` for every noid — also the repo-wide rollup's case |

The volume threshold and the IP allowlist come from
`config.x.cerberus.impression_volume_threshold` and
`config.x.cerberus.impression_ip_allowlist`.

## Scoping a report to one container

`ContainerAnalytics` loads the scoped `ImpressionsReport` and the composition
report for the Analytics tab on a Collection or Community edit page.
`CollectionsController` and `CommunitiesController` both include it.

### Who can see it

Anyone who can reach the edit page at all. The tab uses the same `:edit` ability
gate as the Metadata and Permissions tabs, with no separate admin check. A group
editor's own container's traffic is not privileged the way the repo-wide
`/admin` dashboard's cross-container view is.

The shared partial `shared/_container_analytics` gates one thing separately. The
"Open in Usage Analytics" drill-down link is shown only to an admin or admin
delegate. That is because it leads to the admin-only dashboard, and would
otherwise 403 for most viewers.

### Containment is enforced on the drill-down, not on the search box

The tab offers the same item lookup and facet drill-down the admin dashboard
has, but permanently contained to this container's own subtree. That subtree is
the container itself, its descendant containers, and every descendant Work. An
editor can narrow their own view further; they can never escape it.

`ResourceSearch`'s `within_fq` already keeps the item-lookup search box's results
inside the subtree. That is not the boundary. A drill-down also arrives as plain
GET params, which an editor can hand-edit. So `contained_drilldown_item`
re-validates every candidate against the subtree before honouring it — by
container uuid for a Collection or Community, by Work noid otherwise. That check
is the actual containment boundary.

### The searches read system-wide

`analytics_item_search` bypasses `ResourceSearch`'s own SearchBuilder and its
gated-discovery chain. A group editor has to be able to find every item in their
own container's subtree, regardless of that item's own visibility. That is the
same reason the rest of container analytics reads system-wide. It reuses
`ResourceSearch#filters` — pure, and already covering type, tombstone and
`within_fq` — without the SearchBuilder path that `#call` would take.

The search box submits a field literally named `q`. It is rendered through the
shared `admin/finder/_search_form` partial, so that name is not Cerberus's to
pick. Every other analytics param is Cerberus's own and carries the `analytics_`
prefix.

### Composition ignores the drill-down

Overview, Top files and Top collections all follow the drill-down. Composition
does not. This mirrors the admin dashboard's own Composition tab, which is
always unscoped by item and facet. On the edit page it always means "composition
of this container's own subtree", whatever is drilled into above it.

### The facet picker

`analytics_facet_groups` builds grouped `<select>` options. Content-type values
are restricted to the classifications that actually occur within this subtree.
Featured Content genres are not Solr-derived, so they are never
subtree-filterable — the admin dashboard's own picker behaves the same way.

`parsed_analytics_facet` accepts two shapes, and needs both:

- the packed single-select `analytics_facet` param (`"content::Image"`), which
  is the only form the facet `<select>` emits;
- the canonical `analytics_facet_type` and `analytics_facet_value` pair, which
  every link this tab renders uses, including the clear links.

Accepting both is what lets a bookmarked or shared URL round-trip cleanly.
`Admin::ImpressionsController#parsed_facet` does the same for the same reason.

### What `load_container_analytics` needs

It takes the resource being edited and a `klass` string of `'Collection'` or
`'Community'`. The resource must respond to `.id` (the noid), `.valkyrie_id`
(the Solr uuid) and `.title`.

## Building the scoping UI

Two helpers build the scoping controls. They are counterparts, not duplicates.

| Helper | Dashboard | URLs route to |
|---|---|---|
| `Admin::ImpressionsHelper` | the repo-wide `/admin` usage-analytics dashboard | `admin_impressions_path` |
| `ContainerAnalyticsHelper` | the Collection or Community edit page's Analytics tab | the same edit page, anchored to `#analytics` |

Chartkick dataset formatting lives in `UsageChartsHelper`, which both dashboards
share. Keeping all of this in helpers keeps the controller thin and the report
data-only.

Neither helper re-opens the containment boundary. `ContainerAnalyticsHelper` only
ever builds URLs from noids and uuids that `ContainerAnalytics` has already
resolved, or that a search result already returned.

### Anchoring back to the Analytics tab

`container_analytics_path` appends `#analytics` as a string rather than handing
`:anchor` to `url_for`.

`params` is usually `request.query_parameters`, a
`HashWithIndifferentAccess`. Merging `:anchor` into one stringifies the key, and
`url_for` honours only the symbol form. The anchor would come out as a literal
`anchor=analytics` query param and the tab would be lost.

### Preserving params across a GET form

`usage_preserved_params` and `container_analytics_preserved_params` return every
current query param except `q` — a search box's own field — and whatever the
caller names. A GET form carries them as hidden fields so it does not clobber
state it does not itself edit.

The clear links follow the same rule, each dropping only its own params:

| Helper | Drops |
|---|---|
| `usage_clear_item_path` / `container_analytics_clear_item_path` | `q` and the item params |
| `usage_clear_facet_path` / `container_analytics_clear_facet_path` | the facet params |

`container_analytics_clear_item_path` drops back to the base container's own
scope. It never goes fully unscoped.

### Packing a facet as `type::value`

`usage_facet_groups` and `analytics_facet_groups` return
`[[group_label, [[option_label, option_value], ...]], ...]`, the shape
`grouped_options_for_select` expects. The option value packs `"type::value"`.

Content values are Solr-discovered strings that could in principle collide with a
genre label. The `::` separator keeps the two namespaces unambiguous without a
second `<select>` and cascading JS, for what is a combined list of roughly
twenty options.

`usage_selected_facet_value` and `container_analytics_selected_facet_value`
return that same packed value for the currently active facet, so re-rendering
after a filter keeps the picked option selected.

### The rest of the helpers

- `usage_segment_link` renders one segment-toggle option, merging the segment
  into the full current query string so the date range, item scope and facet all
  survive the toggle.
- `usage_export_params` gives the export links the range, segment and scope
  params — the format is passed separately — so a scoped dashboard's CSV or
  Excel matches what is on screen.
- `usage_item_select_url` and `container_analytics_item_select_url` build the
  href for picking one item-search result row as the scope.
- `container_analytics_drilled?` reports whether a drill-down to a descendant is
  active rather than the base container's own scope.
- `open_in_usage_analytics_params` carries the *effective* item — the
  drilled-into sub-item if one is active, otherwise the container itself. It
  adds any active facet, so the full dashboard opens already showing what is on
  screen.

### The Analytics tab's intro sentence

`container_analytics_scope_blurb` has three shapes, because a fixed sentence
overclaims. Consider "Everything under this collection" sitting directly above
figures for a single drilled-into Work, or above facet-narrowed figures. It
contradicts what the reader is looking at. The three subjects are the
drilled-into item, the facet-matching Works, and the whole subtree.

### The Composition pie's colours

`COMPOSITION_COLORS` leads with the dashboard's already-established view,
download and visitor hues. So the typically largest categories — Image and Text
— land on colours an admin has already seen elsewhere on the page. It then
extends into the rest of the Cerberus palette for the long tail. Chartkick
repeats the array when there are more slices than colours.

## Composition counts

`RepositoryCompositionReport` produces the inventory figures behind the
Composition tab. In v1 there was a flat table of entity counts plus a file-type
breakdown. This is the v2-data-shape equivalent in substance, not a literal
port.

Composition is not a traffic metric. It ignores the date range and the segment,
whatever `scope_fq` is. There is no "composition of the last 90 days" —
only "composition of this subtree, or of the whole repository".

Counts are un-gated. They go through `Blacklight.default_index.search` system-wide
with no SearchBuilder, the same posture as `ContainerDescendantsQuery`,
`ImpressionsReport` and `SolrFacetValues`. An inventory count has to include
every resource regardless of the viewer's own visibility.

### Scoping it

`scope_fq` is an additional raw `fq` fragment — for example
`ContainerDescendantsQuery#subtree_fq` — restricting every count to one
container's subtree. `nil`, the default, is unscoped: the repo-wide behaviour the
admin dashboard's Composition tab has always had.

Person docs sit outside the structural containment tree that `subtree_fq`
matches, so a scoped `entity_counts` always reads 0 Person whatever the
container. That is correct for a Collection, since a Person never belongs to one,
and a minor accepted undercount for a Community.

### What each method returns

| Method | Returns |
|---|---|
| `entity_counts` | a count per `ENTITY_TYPES` member, `0` rather than a missing key for a type with no documents |
| `work_visibility` | `:public` and `:private` Work counts |
| `classification_counts` | `[classification, Work count]` pairs, count-descending |

`work_visibility` measures discoverability — whether `read_access_group_ssim`
includes `public` — not "downloadable right now". An embargoed Work is still
publicly discoverable and counts as public here, matching v1's inventory framing.

`classification_counts` is multivalued. A mixed-media Work counts under every
classification it holds, so these do not sum to the Work total in
`entity_counts`.

### Faceting a `_tesim` field needs the downcased key

`internal_resource_tesim` is a tokenized *text* field — the `tesim` Hydra suffix
— not a string field like `classification_ssim`. Solr facets a text field over
its lowercased indexed tokens, so the facet result is keyed `work`,
`collection`, and so on.

Filter queries do not have this problem. `fq: 'internal_resource_tesim:Work'`
still matches, because the query analyser lowercases too. Only the facet lookup
needs the downcased key.

### Two v1 stats have no v2 equivalent

Both are omitted rather than faked.

| v1 stat | Why it is gone |
|---|---|
| "Users", the raw SSO account count | No atlas_rb binding lists or counts Atlas's users table. `System::User` supports only find and create by NUID |
| Per-format breakdown — PDF against Word, real Zip against generic | Atlas's `ClassificationIndexer` collapses both PDF and Word into "Text", and the Label enum that would distinguish them is never projected to Solr |

`classification_counts` reports the real v2 taxonomy instead of forcing a
v1-shaped split that does not exist.
