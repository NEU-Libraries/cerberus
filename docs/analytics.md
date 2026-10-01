# Usage analytics

How Cerberus records an impression, filters it down to human traffic, and scopes
the resulting figures. That covers the repo-wide Usage analytics dashboard at
`/admin/impressions`, the Analytics tab on a Collection or Community edit page,
and the Analytics tab on a Work's show page.

Source files:

- `app/controllers/concerns/records_impressions.rb`
- `app/jobs/record_impression_job.rb`
- `app/queries/human_impressions_query.rb`
- `app/queries/scoped_visitors_query.rb`
- `app/lib/impression_day.rb`
- `app/models/impression_count_by_day.rb`
- `app/controllers/concerns/container_analytics.rb`
- `app/helpers/container_analytics_helper.rb`
- `app/views/works/_analytics.html.haml`
- `app/helpers/admin/impressions_helper.rb`
- `app/services/repository_composition_report.rb`

## Recording an impression

`RecordsImpressions` is a concern a controller mixes in. It records append-only
usage impressions through Rails callbacks.

The concern is fire-and-forget. `RecordImpressionJob` runs the insert, and the
dedup throttle in front of it, off the request on the `:background` queue.
Recording is therefore cheap enough to sit immediately before an
`ActionController::Live` stream begins.

| Callback | Where it goes | What it records |
|---|---|---|
| `record_view_impression` | `after_action` on `:show` for Work, Collection and Community | a `view` |
| `record_download_impression` | `before_action` on `:show` for Downloads, declared after `authorize_show!` | a `download` |
| `record_media_impression` | `before_action` on `:show` for Media, declared after `authorize_show!` | a `stream` or a `download` |

A view is recorded only when the request actually rendered. A tombstone 410 and
an authz 403 are not views, so `record_view_impression` returns early unless the
response was successful.

A download or stream carries the Blob id rather than a noid.
`RecordImpressionJob` resolves the containing Work's noid with
`AtlasRb::Blob.work`, and records nothing when the Blob resolves to no Work.

### Stream against download on the media endpoint

`MediaController` decides between the two by the `Range` header, which is v1's
heuristic:

- A ranged request is a stream — someone seeking or playing back.
- A full request is a download.

One playback session issues many ranged requests. `Impression`'s one-hour
`(noid, action, ip_address)` throttle collapses them into a single impression.

### Passing the request fields

`record_impression` takes either a resolved `noid` (a view) or a `blob_id` (a
download or stream). The concern groups the request-derived fields (session
id, IP address, referrer, user agent) into one `request_meta` hash, so the
job's signature stays small. A missing referrer is recorded as `direct`.

## Filtering to human traffic

`HumanImpressionsQuery` builds the "human" filter. It excludes known-bot
user-agents through the `UserAgent` dimension. It excludes volume-offending
`(ip, day)` pairs, except for IPs on the allowlist.

It is a pure SQL-fragment builder. It reads and writes nothing itself. A caller
writes its own `SELECT` or aggregate and appends `from_where_sql`, which aliases
the impressions table `i`.

Two callers share it:

| Caller | Why it uses this |
|---|---|
| `RollupImpressionsJob` | repo-wide figures, persisted hourly |
| `ScopedVisitorsQuery`, for `ImpressionsReport` | live scoped reads. A single item's or facet's unique-visitor series cannot wait for the next rollup, and is not worth persisting a table for. The repo-wide visitor rollup has no noid dimension, so a scoped count cannot be derived from it |

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
| `noids` | restrict matched rows to these noids, or `nil` for every noid — also the repo-wide rollup's case. An empty array matches no rows |

The volume threshold and the IP allowlist come from
`config.x.cerberus.impression_volume_threshold` and
`config.x.cerberus.impression_ip_allowlist`.

## Counting by Eastern day

Every figure counts an impression toward its calendar day in the app's time
zone, Eastern, not in UTC. `created_at` is stored as UTC in a plain `timestamp`,
so `::date` alone gives the UTC date, and an evening's traffic after 7 or 8 p.m.
Eastern lands on tomorrow.

`ImpressionDay.of(column)` is the one SQL expression for that day. It converts
the UTC time to Eastern with Postgres's own rules for `America/New_York`, so
daylight saving is handled there. `RollupImpressionsJob`, `HumanImpressionsQuery`'s
per-(IP, day) volume check and `ScopedVisitorsQuery` all group by it. That keeps
the volume threshold and the counts on the same day.

The "All traffic" segment reads a TimescaleDB continuous aggregate, and that
layer works differently. A continuous aggregate can bucket a plain `timestamp`
only at a fixed offset, which is wrong for part of every year once daylight
saving shifts. So `impression_counts_by_day` buckets by UTC **hour**, and the
report folds hours into Eastern days when it reads them. Eastern offsets are
whole hours, so every hour falls wholly inside one Eastern day.

Two methods read the aggregate. Never read its `hour` column directly:

- `ImpressionCountByDay.in_range` bounds a range of dates by Eastern midnight,
  through `ImpressionDay.utc_bounds`. Each end is its own day's midnight, so a
  daylight-saving day is 23 or 25 hours long.
- `ImpressionCountByDay.day_sql` groups by the Eastern date. `ImpressionsReport`
  asks each leaf for its `day_sql`, and the human leaf's is its stored `day`.

`RollupImpressionsJob` re-derives only its last 90 days. Rows older than that
keep the day they were rolled up on until the job runs once with a longer
`window:`.

## Scoping a report to one container

`ContainerAnalytics` loads the scoped `ImpressionsReport` and the composition
report for the Analytics tab on a Collection or Community edit page.
`CollectionsController` and `CommunitiesController` both include it.

### Who can see it

Anyone who can reach the edit page. The tab uses the same `:edit` ability gate
as the Metadata and Permissions tabs, with no separate admin check. A group
editor's own container's traffic is not privileged the way the repo-wide
dashboard's cross-container view is.

The shared partial `shared/_container_analytics` gates one thing separately. It
shows the "Open in Usage Analytics" link only to an admin or admin delegate.
`Admin::ImpressionsController` admits only those two, so the link would
otherwise 403 for most viewers.

### Containment is enforced on the drill-down, not on the search box

The tab offers the same item lookup and facet drill-down the admin dashboard
has, but permanently contained to this container's own subtree.
`ContainerDescendantsQuery` defines that subtree: the container itself, its
descendant containers, and every Work structurally homed in any of them. A Work
merely linked into the subtree is outside it, because a Work's impressions
accrue to its structural home. An editor can narrow their own view further, but
can never escape it.

`ResourceSearch`'s `within_fq` keeps the item-lookup search box's results
inside the subtree. That is not the boundary. A drill-down arrives as plain GET
params, which an editor can hand-edit. So `contained_drilldown_item`
re-validates every candidate against the subtree before honouring it. It checks
a Collection or Community by container uuid, and anything else by Work noid.
That check is the containment boundary.

### The searches read system-wide

`analytics_item_search` bypasses `ResourceSearch`'s own SearchBuilder and its
gated-discovery chain. A group editor has to find every item in their own
container's subtree, whatever that item's visibility. The rest of container
analytics reads system-wide for the same reason. The method reuses
`ResourceSearch#filters`, which is pure and already covers type, tombstone and
`within_fq`, and skips the SearchBuilder path that `#call` would take.

The search box submits a field named `q`. The shared
`admin/finder/_search_form` partial renders it, so this tab cannot rename it.
Every other param on this tab carries the `analytics_` prefix.

### Composition ignores the drill-down

Usage history, Top files and Top collections all follow the drill-down. The
Content overview, which renders the composition report, does not. On the edit
page it always means "composition of this container's own subtree", whatever is
drilled into above it.

### The facet picker

`ContainerAnalytics#analytics_facet_groups` builds grouped `<select>` options.
It restricts Content type values to the classifications that occur on Works in
this subtree. Featured Content genres are not Solr-derived, so they are never
subtree-filtered. The admin dashboard's picker lists the same genres.

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

## A Work's Analytics tab

A Work's analytics sit on its **show** page, not its Edit page, as v1's
Statistics tab did. v1's Work page was tabbed, with Metadata as one tab, and the
librarians looked for analytics there.

`WorksController#load_work_analytics` builds an `ImpressionsReport` scoped to
the one Work, only when the viewer holds `:edit`. That is the same audience as a
container's tab. Everyone else sees the show page without tabs, because a single
Metadata tab would be noise. For an editor the metadata column becomes the
Metadata and Analytics tabs, and `tab-hash` makes `#analytics` a link that
opens the tab.

The tab is smaller than a container's on purpose:

- A Work scope resolves to its own noid, so there is no drill-down, no facet
  picker and no Solr query.
- It shows views, downloads and streams over the last 90 days of human traffic.
  Streams appear only for a Work that plays in the browser.
- Each action gets its own chart on its own scale, rather than one stacked
  chart. A Work's downloads and streams are usually a fraction of its views,
  and would flatten under them.
- It leaves out unique visitors, which the librarians do not use.
- An admin or admin delegate gets a link to the Usage analytics dashboard,
  scoped to the Work, for other date ranges.

`app/views/works/_analytics.html.haml` renders the tab.

## Building the scoping UI

Two helpers build the scoping controls. They are counterparts, not duplicates.

| Helper | Dashboard | URLs route to |
|---|---|---|
| `Admin::ImpressionsHelper` | the repo-wide Usage analytics dashboard | `admin_impressions_path` |
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

`usage_facet_groups` (a helper) and `analytics_facet_groups` (in the
`ContainerAnalytics` concern) return
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

`Admin::ImpressionsHelper::COMPOSITION_COLORS` leads with the dashboard's view,
download and visitor hues. So the typically largest categories, Image and Text,
land on colours an admin has already seen elsewhere on the page. The long tail
takes further Cerberus palette colours. Chartkick repeats the array when there
are more slices than colours.

## Composition counts

`RepositoryCompositionReport` produces the inventory figures behind the
Content overview tab. v1 had a flat table of entity counts plus a file-type
breakdown. This report is the equivalent in substance for v2's data shape, not a
literal port.

Composition is not a traffic metric. It ignores the date range and the segment,
whatever `scope_fq` is. There is no "composition of the last 90 days" —
only "composition of this subtree, or of the whole repository".

Counts are un-gated. They call `Blacklight.default_index.search` directly, or
through `SolrFacetValues`, with no SearchBuilder. That is the same posture as
`ContainerDescendantsQuery`,
and `ImpressionsReport`. An inventory count has to include
every resource regardless of the viewer's own visibility.

### Scoping it

`scope_fq` is an extra raw `fq` fragment that restricts every count, for example
`ContainerDescendantsQuery#subtree_fq`. `nil`, the default, counts the whole
repository.

The admin dashboard scopes Composition to its picked item, and never to its
facet (`Admin::ImpressionsController#composition_scope_fq`). A Collection or Community counts its own subtree, through `subtree_fq`.
A Work counts only itself, through `MembershipQuery.identity_fq`. A facet
narrows the traffic figures only, because the Content overview is an inventory
of the scoped item, not of its traffic.

### Storage used

`storage_bytes` sums Atlas's `storage_bytes_ls` over the same scope, with a Solr
JSON facet, `sum(storage_bytes_ls)`. Atlas gives each Work, Collection and
Community the bytes its own OCFL objects hold on disk: every revision of every
file, withdrawn files, MODS and METS versions, and OCFL's bookkeeping. The
measure is storage cost, so a Work replaced a hundred times outweighs one that
never changed. `subtree_fq` keeps tombstoned documents, so withdrawn files
count, as they still take disk. Bytes outside OCFL are not counted: Cerberus's
JP2s, its staged uploads and the IIIF cache.

#### Checking the figure

Two equations should hold. Each can be checked without touching the code.

**The repository total is the disk, less the root's own files.** Atlas counts
bytes as it writes them, so its ledger is checkable against a walk of the
storage root. A storage root holds three files that belong to no object, and
so to no owner: `0=ocfl_1.1`, `ocfl_layout.json` and `extensions/`. With one
root:

```
bytes of every file under the storage root
  = sum(storage_bytes_ls) over the whole index + the root's own files
```

Walk the root inside the Atlas container, then sum the field in Solr:

```bash
docker exec cerberus-atlas-1 sh -c \
  'find /home/atlas/storage -type f -printf "%s\n" | awk "{s+=\$1} END {print s}"'
curl -s http://localhost:8983/solr/blacklight-core/select \
  --data-urlencode 'q=*:*' --data-urlencode 'rows=0' \
  --data-urlencode 'json.facet={"total":"sum(storage_bytes_ls)"}'
```

A difference larger than those three files means the ledger has drifted from
the disk, and Atlas's `atlas:storage:rebuild_footprints` corrects it.

**The repository total is the root community, plus the People community.**
Every community hangs off the root, except the People community, which holds
personal workspaces and the Works deposited into them. It is a system
container outside the root's tree. So the root community's Analytics tab reads
less than the dashboard by exactly the People community's subtree:

```
dashboard total = root community's subtree + People community's subtree
```

Sum the People subtree in Solr through `a_member_of_ssi`, the membership field
`subtree_fq` uses, over the personal roots and the system container plus the
docs that are their members. Do not filter on `ancestor_ids_ssim`: only
containers carry it, so it bounds a subtree's collections but none of its Works.

A worked example, from development data: the walk gave 53,446,800 bytes and
the ledger 53,446,414, a difference of 386 bytes, which is
`0=ocfl_1.1` (9), `ocfl_layout.json` (137) and `extensions/` (240). The People
subtree held 925,016 bytes, and 53,446,414 − 925,016 = 52,521,398 bytes is the
root community's 50.1 MB. The figure is shown in units of 1,024.

Person docs sit outside the structural containment tree that `subtree_fq`
matches, so a scoped `entity_counts` always reads 0 Person whatever the
container. That is correct for a Collection, since a Person never belongs to one,
and a minor accepted undercount for a Community.

### What each method returns

| Method | Returns |
|---|---|
| `entity_counts` | a count per `ENTITY_TYPES` member, `0` rather than a missing key for a type with no documents |
| `work_visibility` | `:public` and `:private` Work counts |
| `classification_counts` | `[classification, Work count]` pairs, in Solr's count-descending facet order |

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
| "Users", the raw SSO account count | No atlas_rb binding lists or counts Atlas's users. `AtlasRb::User.search` is a typeahead capped at 10 entries, and every other `AtlasRb::User` and `AtlasRb::System::User` method reads, resolves or creates one account |
| Per-format breakdown — PDF against Word, real Zip against generic | Atlas's `ClassificationIndexer` collapses both PDF and Word into "Text", and the Label enum that would distinguish them is never projected to Solr |

`classification_counts` reports the real v2 taxonomy instead of forcing a
v1-shaped split that does not exist.
