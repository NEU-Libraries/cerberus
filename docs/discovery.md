# Discovery surfaces

The pages that ask Solr "what is here, and what may this person see?" — the
community landing page and My DRS. Also the admin finders, the genre showcases
the deposit fork publishes into, the Google Scholar tags on a Work, and the
browsable values in a Work's metadata block.

Source files:

- `app/services/mods_browse_links.rb`
- `app/services/resource_search.rb`
- `app/services/showcase_finder.rb`
- `app/services/search_explanation.rb`
- `app/controllers/search_explanations_controller.rb`
- `app/services/showcase_provisioner.rb`
- `app/services/work_showcase.rb`
- `app/controllers/concerns/work_showcase_category.rb`
- `app/services/collection_contents_resolver.rb`
- `app/services/google_scholar_metadata.rb`
- `app/controllers/communities_controller.rb`
- `app/controllers/concerns/community_showcases.rb`
- `app/controllers/my_drs_controller.rb`
- `app/controllers/concerns/show_scoped_search.rb`
- `app/controllers/concerns/without_facet_modal.rb`

Three neighbouring pages carry the machinery these files reuse:

- `docs/search.md` holds `MembershipQuery`: the membership fields, and why every
  fragment goes in `:fq`.
- `docs/permissions.md` holds the ACL vocabulary and `UNOWNED_NUID`.
- `docs/sets.md` holds `SetResolver`, whose export surface
  `CollectionContentsResolver` mirrors.

## The queries on this page are gated, with two exceptions

Almost every query here reaches Solr through the Blacklight `SearchBuilder`
chain. It uses either `SearchBuilder.new(scope)` with the controller as scope,
or the controller's own `search_service.search_builder`. That chain applies
gated discovery for the acting user.

Gating is the reason these lookups can be written plainly. A showcase a
depositor may not discover never reaches the publish menu. A restricted Work
never reaches a collection export. An admin sees non-public resources in the
finders, which is what makes the finders useful.

The failure mode is silent. A hand-built `Blacklight.default_index.search` with
literal params returns the ungated set, and nothing raises. The inline comments
in these files mark the gating for that reason.

Two queries are deliberately ungated:

- `DepositorContext#workspace_collections` fills My DRS's workspace panel. A
  depositor's own private Collections must stay visible there.
- `GoogleScholarMetadata.for` reads one Work's citation fields. The show page
  has already authorized that Work, and the tags emit only for a public one.

## Finding a resource to move or link

`ResourceSearch` answers "which resources of these types match what the user
typed?". It is the finder behind these flows:

| Flow | Step | Types searched |
|---|---|---|
| Re-parent | Pick the node to move | `ALLOWED_PARENTS.keys`: Work, Collection, Community. Anything can be moved |
| Re-parent | Pick the destination | Whatever `ALLOWED_PARENTS` permits for that node's class |
| Linked members | Pick the Work, then the Collection | Work, then Collection |
| Work associations | Pick the Work, then the Work to associate | Work, excluding the Work itself the second time |
| Person affiliation | Pick a Community | Community |
| Loader destination | JSON typeahead in `LoadsController#collection_search` | Collection |
| Usage analytics | Pick an item to scope the dashboard to | Work, Collection, Community |
| Container Analytics tab | Look up an item in one container | Work, Collection, Community, constrained by `within_fq` |

The Container Analytics tab calls only `#filters`, not `#call`, and runs its
own ungated search. `docs/analytics.md` explains why.

It runs the same `Blacklight.default_index.search(params: builder)` idiom as the
other Solr service objects. Unlike them it resolves no subtree; it matches a
keyword, 25 rows at a time (`DEFAULT_PER_PAGE`).

### Arguments

| Argument | Meaning |
|---|---|
| `scope:` | The controller. Supplies the Blacklight config, copied from `CatalogController`, and the `current_user` that gated discovery reads |
| `query:` | The admin's keyword query. Blank returns an empty response |
| `types:` | `internal_resource` types to match, such as `%w[Collection Community]` |
| `exclude_node_uuid:` | Solr `id` (uuid) of the node being moved, so a node cannot be its own parent |
| `exclude_subtree_noid:` | Noid of the node being moved. Excludes every container whose `ancestor_ids_ssim` contains it — that is, its descendants |
| `exclude_noid:` | Noid of the node's current parent, matched on `alternate_ids_tesim`. A move there would move it nowhere |
| `within_fq:` | An extra raw fq fragment ANDed onto the search, such as `ContainerDescendantsQuery#subtree_fq`, for a finder that must stay inside one container's subtree rather than search the whole repository |

A blank query returns an empty `Blacklight::Solr::Response` rather than
everything. The container tree runs to thousands of rows, and an empty search
box is not a request for all of them.

The node and subtree exclusions pre-empt Atlas. Atlas rejects a move into the
node itself or into its own descendant with a `cycle` error. Filtering those
candidates out of the finder means the admin cannot pick one.

`filters` is public and pure, so specs assert the fq fragments directly without
running a search.

## Genre showcases

A showcase is a featured Collection under a community, titled after one
scholarly genre. The weighted deposit fork publishes into them: a depositor's
workspace holds their drafts, and a showcase holds what they promote.

Two services own the pair of questions.

| Service | Question |
|---|---|
| `ShowcaseProvisioner` | Create this community's showcases, one per genre |
| `ShowcaseFinder` | Which showcases does this community have, and which one is "Datasets"? |

### Provisioning

`CommunitiesController#create` provisions every new community. The
development and staging reset seed (`lib/tasks/reset.rake`) provisions every
community it creates, the root included.

Each showcase is a featured Collection titled after its genre. The provisioner
writes the title and abstract through `AtlasWrite#merge_mods!`, the
structure-safe MODS merge the descriptive forms use through
`DescriptiveMetadata#save_descriptive!`. That merge reads the freshly minted
MODS, merges the fields in, and writes the raw XML back.

A failed showcase create is logged and skipped, so one failure cannot abort the
rest. The rescue covers `AtlasRb::Error` as well as transport faults, because
Atlas's container-create gate raises a 403 as an exception. The community
already exists by then, and an administrator can create a missing showcase
later. That tolerance is also why `CommunitiesController` still
tests for showcases rather than assuming them.

The acting principal comes from the ambient `Current.nuid`, set by the
controller or by the reset seed's `Current.set` block. The showcase itself
records `Permissions::UNOWNED_NUID` as depositor. Falling through to the acting
principal would make the community's creator the depositor, and so an editor,
of every showcase under it. See `docs/permissions.md` for why the anonymous
NUID is the safe choice for a container nobody personally owns.

### Finding

`ShowcaseFinder` has two shapes, and the second argument chooses between them.

```ruby
ShowcaseFinder.call(scope:, community_noid:)
# => { "Presentations" => "<noid>", "Datasets" => "<noid>", ... }

ShowcaseFinder.call(scope:, community_noid:, genre_label: "Datasets")
# => "<noid>", or nil
```

`DepositorContext#publish_targets` uses the map form to build the publish
categories `WorksController#new` offers. `DepositorContext#publish_showcase_id`
uses the single-noid form to find the linked-member edge target that
`WorksController#create` writes on publish.

The lookup matches the community's **direct** featured Collection members
(`MembershipQuery.members_fq`) whose title is one of the shared genre labels
from `FeaturedContent`. It must not search the whole subtree. Every descendant
community holds showcases with the same genre titles, so a subtree lookup at
the root would resolve "Datasets" to whichever showcase Solr listed last. A
community holds one showcase per genre, so the map stays small. A duplicate
title, which provisioning does not produce, resolves last-writer-wins.

The finder first resolves the community's noid to its uuid through
`alternate_ids_ssim`, because the structural parent edge holds the uuid.

### Changing a Work's showcase category

The Work Edit page offers a Showcase category choice when the Work is already
in a genre showcase. The Work's depositor and admins see it. Nobody else does,
because Atlas links a Work into a showcase only on its depositor's behalf.
`WorkShowcaseCategory` makes every change, a depositor's own included, through
`AtlasRb::System::Work` with `on_behalf_of` set to the depositor.

`WorkShowcase` reads where the Work is now. Atlas's `find_many` digest carries
neither `featured` nor a parent. So `WorkShowcase` takes the Work's linked
collections from `AtlasRb::Work.linked_members`, then asks Solr which one is a
featured genre showcase and which community holds it. A Work an admin has
linked into two showcases reports the first one Solr returns. `ShowcaseFinder`
then lists the community's other showcases. A depositor is never offered a
staff-only genre (`FeaturedContent::STAFF_ONLY`), as at deposit.

The swap adds the new link before it removes the old one. If the second call
fails, the Work sits in both showcases, which an admin can see and fix. Removing
first could leave it in neither. Every change reaches the admin ledger as a
`showcase_promotion` `AdminNotice`, like a publish at deposit. An Atlas refusal
is recorded too, with the outcome `refused`.

## The community landing page

`CommunitiesController` inherits `CatalogController`, so browse, faceting and
pagination are Blacklight's.

### Scoping the index

`CommunitiesIndex#search_service_context` scopes the index action to
Communities, and only the index action. Two things depend on that split:

- Without the scope, `/communities` inherits the unscoped browse and lists every
  resource type, Collections, Works and People included. The context key is
  `resource_type_scope`, and `SearchBuilder#scope_to_resource_type` applies it.
- The show page must not be scoped. Its `find_children` surfaces the child
  Collections inside a community, which a Community-only filter would remove.

The index is the homepage's Communities gateway, so it has its own view,
`communities/index`, with the People index's heading well and a search scoped to
communities. With no query it sorts by title, as v1's did, because relevance has
nothing to rank and would list communities in the order they were made. A query
keeps relevance.

### Hiding empty showcases

The browse lists a featured Collection only when it has content, as v1 did.
Provisioning seeds every community with the full genre set, so without this the
browse fills with empty showcase rows.

The controller computes the empty showcases first and passes them to
`find_children` as an exclusion at query time. It is deliberately not a Ruby
post-filter over the returned documents. Solr computes its facet counts
server-side, so a post-filter leaves the Type facet counting rows the reader
cannot see.

Admins and delegated admins see the empty showcases anyway, each with an "Empty"
pill (`showcase_manager?`, `hidden_showcase_uuids`). They are the people who
load into a showcase, and a load asks for the destination's PID: a new
community's Theses & Dissertations Collection has to be findable before it holds
anything. The check reads `effective_user`, so an admin viewing as someone else
sees that person's listing. A response document is frozen, so
`mark_empty_showcases` swaps in a flagged copy rather than setting the flag.

Only `featured?` showcases are hidden. An ordinary empty Collection stays
listed, because showing someone the empty collection they just made is the point.
The rule pairs with the Faculty & Staff row: both curated affordances appear
only when populated.

`CommunityShowcases#populated_showcase_ids` asks one gated, `rows: 0` facet query over the two
membership fields (`MEMBERSHIP_FIELDS`), restricted to members of those
showcases. It reads the raw
`facet_counts` rather than a Blacklight facet, so the answer does not depend on
the facet configuration in `CatalogController`. Solr returns each field as a
flat `[value, hits, value, hits, ...]` array, and the values carry the `id-`
prefix that `docs/search.md` describes.

### Whether Delete is offered

The listing is not the whole test. Atlas refuses to tombstone a container while
any live member remains. A showcase Collection is a live member even when it is
empty and therefore hidden from the listing.

A test of the listing alone would offer Delete on a community reading "This
community is empty". The delete would then fail and tell the reader to withdraw
contents they could not see. So `deletable?` requires both an empty listing and
no showcases.

In practice that makes Delete unavailable for any community that provisioned
normally. It stays a real test rather than a flat "never", because
`ShowcaseProvisioner` tolerates a failed create and a community can legitimately
have no showcases.

### The Faculty & Staff row

A community with affiliated People gets a synthetic "Faculty & Staff" row at
the top of its browse (`prepend_faculty_staff_entry`). It is rendered through the normal Blacklight pipeline, so
it matches the list and gallery rows exactly.

It appears only on the unfiltered first page, mirroring v1's `current_page == 1
&& no constraints`. It drops out as soon as the visitor searches within the
community or applies a facet.

The row is a `SolrDocument` built in Ruby; no such document exists in Solr.
Besides its title and description, four fields shape it:

| Field | Effect |
|---|---|
| `nav_url_ssi` | Links the row to the community's People browse (`community_people_path`) |
| `internal_resource_tesim: ['Person']` | Person icon and type pill |
| `people_browse_bsi: true` | Pluralizes the pill to "People", because the row browses to many (`SolrDocument#people_browse?`) |
| `read_access_group_ssim: ['public']` | Keeps `document_status_icons` from drawing a lock on a public directory affordance |

Because the row is synthetic, the controller also raises the response total by
one, so "Displaying N entries" matches the rows on screen.

The document is constructed with the live `@response` as its second argument.
`SolrDocument#response` defaults to nil, and Blacklight's per-row highlight
check reads `response['highlighting']`, which raises `NoMethodError` on nil.
Sharing the real response gives the check a blank highlighting section to find.

Affiliation is indexed as community noids in `affiliated_community_ids_ssim`, so
the gated count of affiliated People filters on that field.

### Narrowing a community

The edit form offers Private to administrators only. `CommunitiesController#edit`
sets `@narrowing_allowed` to `current_user.admin?` and so carries that decision
to the view.

A community narrows its own object alone. No cascade reaches the collections
inside it, which stay exactly as visible and as searchable as they were. That
shallowness is the feature — it holds a community's landing page back without
touching its contents. But it is sharp enough to be administrator-only, and the
form has to say what it does and does not do. Everyone else gets the restriction
request form. `docs/permissions.md` covers the server-side refusal that backs
this up.

### Ordering inside `create`

`create` mints and titles the community first, then provisions the showcases. A
community that fails to get a title never leaves orphaned showcases behind.

## The scoped facet modal

Collection, Community and Set show pages embed Blacklight's facet sidebar over
their own contents. `ShowScopedSearch` gives all three the "more" modal and the
filter box inside it, counting the container's contents rather than the whole
index. Each includer supplies `facet_scope_filters`.

### Why the routes look the way they do

`Blacklight::FacetFieldPresenter#modal_path` calls `search_facet_path(id: key)`.
That merges `action: "facet"` onto the current controller and hands the facet
key over as `:id`. On a show page `:id` already names the container, so the key
overwrites it. No route matches, and `url_for` raises **inside the view**, so
the whole page 500s, not just the link. The scoped routes therefore carry the container in `:id` and
the facet key in `:facet_field`:

```
/collections/:id/facet/:facet_field
```

Overriding `search_facet_path` works because `helper_method` defines it on the
controller's own `_helpers` module, which shadows the one Blacklight includes
from `Blacklight::FacetsHelperBehavior`. On an index page there is no container,
so `ShowScopedSearch#search_facet_path` returns `nil` and renders no link.

Surfaces that embed the sidebar but own no facet route, such as
`PeopleController` and `GenresController`, include `WithoutFacetModal`
instead. Its `search_facet_path` always returns `nil`. That is the supported
off switch: `modal_path` passes it straight through, and the field component
renders no link.

### The suggest box needs a second route, and cannot share the first

The filter box builds its own fetch URL in JavaScript. Blacklight's
`facet_suggest.js` reads the box's search context, keeps **only the first path
segment**, and appends the facet key:

```js
const basePathComponent = url.pathname.split('/')[1];
const urlToFetch = `/${basePathComponent}/facet_suggest/${facetField}?${facetSearchParams}`;
```

Everything else in the path is discarded, so a container sitting in `:id` never
reaches the request. The query string, by contrast, is carried over intact.

So the box points at a route with **no `:id` segment**, and the container rides
the query string:

```
/collections/facet_suggest/:facet_field?id=<noid>
```

`facet_suggest_context` hands the box that same URL, which is why the JS can
rebuild it: it re-derives `/collections/facet_suggest/<key>` from the first segment and
re-attaches the query string, adding `query_fragment`. **Anything moved from the
query string into the path here is silently lost.**

Three consequences worth knowing before editing this:

1. **The container is unverified by the router.** On the modal route Rails
   guarantees `:id` is present; on the suggest route it does not. So
   `facet_suggest` raises a routing error (404) on a blank one itself. Without
   that the includers resolve a nil id and fail well below the controller.
2. **The suggest routes are declared ahead of the resource blocks** in
   `config/routes.rb`, so a facet key can never be read as a member action.
3. **Both actions load through `load_scoped_facet!`**, which runs
   `facet_scope_filters` — and that is where the container is fetched and
   authorized. A modal that refuses is worth little if the box inside it
   answers, so the gate has to sit on the shared path rather than on either
   action.

`scoped_facet_response` treats an empty `query_fragment` the same as an absent
one, and applies no `facet.contains`. The box is empty until someone types, and
that request must still count everything.

## My DRS

`MyDrsController` renders the depositor's two-space home.

- The **workspace** on the left holds the Collections under their personal
  root: drafts and working files, discoverable by their own visibility but
  never promoted.
- **Published** on the right holds the works they promoted into their
  community's genre showcases, grouped by category.

The split makes the curation boundary legible — workspace against the
professional tier — which is what the weighted deposit fork exists to express.

It inherits `CatalogController` for the gated `search_service`. The work panels
also narrow to this depositor with `depositor_ssi`. Both halves matter: drop
either one and a depositor sees rows that are not theirs.

The depositor context, meaning their Person record and workspace Collections,
comes from `DepositorContext`, which the deposit fork shares.

### The panels

| Panel | Query | Why it is here |
|---|---|---|
| Account switcher | `AtlasRb::User.accounts` | The staff and student logins under one NUID. The view renders it only when there is more than one. An Atlas fault degrades to an empty list, so a hiccup costs the panel rather than the page |
| Workspace collections | `DepositorContext#workspace_collections`, ungated | Non-showcase Collections under the Person's `personal_root_id`, newest first. Scoping to the personal root, not to every Collection this person deposited into, stops an admin who seeded the institutional tree from "owning" all of it |
| Published | Showcase lookup, then per-showcase membership | Grouped by category |
| Deposits to finish | `in_progress_bsi:true`, matching `depositor_ssi` or `proxy_uploader_ssi` | Deposits this person started and never confirmed, including ones a proxy uploader started for someone else. My DRS is the only place they can find one: an unfinished deposit is hidden from general discovery, and its depositor is the one person who can finish it |
| Incomplete works | `incomplete_bsi:true` and `-in_progress_bsi:true` | Finished works missing something a job failed to make. The depositor cannot repair one, so the panel exists to tell them rather than leave them assuming a missing thumbnail is how DRS looks. The second filter keeps the two panels disjoint |
| New collection | `personal_root_id` | Offered only to a depositor who has a personal root to create the collection under |

### Grouping the published works

`published_by_category` returns `[[label, [work_docs]], ...]` in the shared
genre vocabulary's order. It includes only categories holding at least one
published work, so an all-empty result is `[]`, which the view renders as the
column-level empty state.

It gets there in two steps. `showcase_docs` runs one gated query across the
subtrees of every community the person is affiliated with. It returns documents
rather than ids, because callers need both the noid for routing and the uuid for
membership. `works_published_into` then asks, per showcase, for
this depositor's works carrying the linked-member edge the publish branch wrote.
That query has to include linked members, or a published work never appears.

## Exporting a collection's contents

`CollectionContentsResolver` gives `MetadataExportPacker` a Collection's member
Works as gated Solr documents, page-batched. It is the collection counterpart of
the slice of `SetResolver` that bulk export needs. That is the same
`each_content_batch` and `contents_count` surface, and the same
`SetResolver::MAX_EXPORT_ROWS` runaway cap. See `docs/sets.md` for the Set side.

`CollectionExportsController` constructs it with three arguments:

- `valkyrie_id:`, the collection's uuid. That is the Solr uniqueKey form stored
  in the membership fields.
- `noid:`, the collection's noid, which the descendant walk keys on.
- `search_service:`, the controller's, which supplies the gated builder.

The resolver returns the Works of the collection and of every sub-collection
beneath it, structural plus the linked overlay. Librarians export a collection
to get everything in it, so this deliberately goes deeper than the Collection
show page's browse, which lists direct members only. Works hang off their
immediate parent, so the resolver first finds the descendant containers through
`ancestor_ids_ssim` (keyed by noid) and then takes members of all of them — the
two-step walk `SetResolver` does for a Set. Without the noid it falls back to
direct members. `SetResolver::DEFAULT_TYPE_FILTERS` excludes containers and
tombstones, so only live Works count as contents.

### The field list comes from the packer

`each_content_batch` sets `fl` from
`MetadataExportPacker::REQUIRED_DOC_FIELDS` rather than a list written in the
resolver, and the two must not drift.

A field the packer reads and the query does not fetch raises nothing anywhere.
The document simply has no value, and the manifest gets a blank cell. A missing
embargo field, for example, empties the Embargoed? and Embargo Date columns on a
collection export while a set export of the same Work fills them. A manifest row
carrying a PID *updates* that record, so re-loading that export clears an
embargo nobody touched.

## Google Scholar tags

`GoogleScholarMetadata` builds the Highwire Press `<meta>` tag set for a Work
show page.

It reads the Work's Solr document and nothing else, because nothing may parse
MODS XML on the render path. Atlas's `CitationIndexer` projects `creator_ssim`
and `pub_date_ssim` onto the Work document, beside `description_tsim` and
`genre_ssim`. Atlas's `MODSIndexer` projects `subject_ssim`, which feeds the
`keywords` tag. The title comes from the `AtlasRb::Work` itself. Public status
and embargo come from the resource permissions the show page has already
loaded.

`subject_ssim` is also the Topic facet's field. One indexer writes the concept
and both consumers read it, so a subject cannot be browsable and absent from the
citation tags at the same time.

`GoogleScholarMetadata.for` runs the lookup, and `CITATION_FL` keeps it to the
fields the tags need. A Solr failure (`RSolr::Error`) degrades to no tags rather
than breaking a show page that otherwise has no Solr dependency.

### What gets tags

Only a public Work whose `genre_ssim` includes one of `SCHOLAR_GENRES`:
Research Publications, Technical Reports, or Theses & Dissertations
(`#emit?`). DRS v1 restricted
the tags the same way. Emitting `citation_*` for a photo or an A/V clip would be
noise to Scholar.

`app/views/works/_scholar_metadata.html.haml` reads the value object and
renders into `<head>`. URL building, meaning `citation_pdf_url`, stays in the
view, where the request host is known.

### The PDF pointer

`pdf_blob_noid` returns the noid of the first PDF Blob with no external `uri`,
and only when the Work is public and not under embargo. Returning nil suppresses the tag,
which is how a private or embargoed file stays unadvertised. The view turns the
noid into an absolute download URL.

`WorksController#prepare_show_view` calls `GoogleScholarMetadata.for(work:,
permissions:, files:)`, which fetches the Solr document and passes it to the
constructor:

| Constructor argument | Meaning |
|---|---|
| `work:` | The show page's `AtlasRb::Work`, for the display title |
| `permissions:` | The resource permissions loaded by `authorize_show!`. `read` carries `public`; `embargo` carries a date string |
| `files:` | The Work's assets, from `AtlasRb::Work.assets`, in page order |
| `solr_doc:` | The Work's Solr document, or nil |

## Browsable values in the MODS block

`MODSBrowseLinks` turns values in a Work's metadata block into links to the
catalog facet that browses them. A reader clicking `Civil society` lands on
`/catalog?f[subject_ssim][]=Civil+society`.

Atlas renders that block. `WorksController#prepare_show_view` passes it through
`browsable_mods`, and `app/views/works/show.html.haml` injects it whole
(`@mods&.html_safe`). So Cerberus has no per-value handle on it and cannot
derive one. Two facts rule out reading the rendered text:

- **One `<dt>` spans several facet fields.** Atlas merges every subject axis
  under "Subjects and keywords". One record there carries `Salt marshes`
  (`subject_ssim`) beside `Belle Isle Marsh (Mass.)` (`subject_geo_ssim`).
- **The rendered string is not the indexed string.** Atlas's decorator
  normalises for a reader. For example, it capitalises `Type of resource` and
  steps out a hierarchical place. Matching on display text is unsound by
  construction, not merely fragile.

So Atlas marks each value instead:

```html
<span data-browse-axis="topic"
      data-browse-value="Civil society"
      data-browse-authority="lcsh">Civil society</span>
```

Atlas states what the value **is**. Cerberus decides whether and where it
links. No Solr field name crosses the wire, so renaming a facet needs no Atlas
release.

### Three predicates, kept separate

A value links only when all three hold:

| Predicate | Kind |
|---|---|
| Its axis is in `AXES` | policy — the field allowlist |
| That field is in `blacklight_config.facet_fields`, passed in as `facet_fields:` | **correctness** |
| It carries `data-browse-authority` | policy — the eligibility rule |

Keep them separate in the code. The middle one is the reason no link ever
reaches an empty result set, and it stays. The other two are librarian
decisions that will move, and collapsing all three into one condition turns the
next such conversation into code archaeology.

A marker with a blank `data-browse-value` also stays unlinked. Everything that
fails a predicate stays plain text, silently. There is no "not
browsable" affordance, because a reader who never had a link does not need to
be told one is missing.

### Why the allowlist omits axes Atlas marks

Atlas's `MODSBrowse` marks fourteen axes. `AXES` maps nine, and the omissions
are decisions:

- **`publisher` and `place_of_publication`.** Both have facets, and MODS 3.8
  permits an authority on `publisher` and on `placeTerm`, so the authority
  predicate alone would let them through. DRS controls neither in practice, so
  "Boston" and "Boston, Mass." would browse as unrelated values.
- **`photo_category`.** It would never qualify anyway. `Iptc::MODSBuilder`
  writes `<classification>` with no authority attribute, so no photo category
  passes the authority predicate.
- **`subject_title` and `occupation`.** Neither has a facet to link to. Atlas
  indexes a subject title as searchable text (`subject_title_tesim`), and
  marks an occupation with no Solr field at all.

`resource_type` is absent from both sides. Atlas marks no resource-type axis,
and Cerberus configures no `resource_type_ssim` facet, because the Content facet
answers the same question in a reader's own words.

### One link per value, and no collection-scoped second link

The UAT elaboration asked for a collection-level link beside the
repository-level one, and the reference implementation models the collection
axis as a facet value. Cerberus does not follow it. A Collection show page
carries its own facet sidebar, and `ShowScopedSearch` keeps its facet links on
the page, so `/collections/:noid?f[subject_ssim][]=Civil+society` already works
by clicking the facet where the reader is standing. Turning a collection into a
facet value duplicates a page that does the job better.

### The trap when a link comes back empty

Read Solr before reading this service. Atlas indexes a subdivided heading as
one composed value, `Emergency management -- Planning`, not its two topics. The
marker carries that same composed value. A Solr index built before Atlas
composed headings still holds the separate topics, so its links come back empty.
That is exactly the symptom a wrong `AXES` entry would produce.

## Search operators

The catalog search is Solr's edismax, so a reader can use its operators: `AND`
(or `&&`), `OR` (or `||`), `NOT` (or a leading `-`), `+` to require a word,
parentheses to group, and quotation marks for a phrase. Only the uppercase forms
are operators. Lowercase "and", "or" and "not" are ordinary words, so a title
typed as written searches as it reads, and Solr's `lowercaseOperators` stays off
on purpose.

### An explicit OR relaxes the minimum match

The search handler's `mm` (`2<-1 5<-2 6<90%` in `blacklight-core`'s
`solrconfig.xml`) requires both words of a two-word search, and most words of a
longer one. Solr 9 applies it to an explicit `OR` as well, so `coastal OR
disaster` required both words and found nothing. Neither `q.op=OR` nor
`mm.autoRelax` changes that.

`SearchBuilder#honour_explicit_or` sends `mm=1` when the search holds an
uppercase `OR` or `||` outside quotation marks, which is what Solr parses as an
operator. A plain search keeps the handler's `mm`, because relaxing it for
everything would loosen every search. One side effect follows from Solr, not from
this step: an uppercase `OR` in a typed title, such as "Portland, OR", is an
operator, and the search now matches either side of it rather than requiring
both. A group in parentheses is untouched either way, because `mm` applies only
to the top level.

## Why this result?

Admins and delegated admins get a `fa-magnifying-glass-chart` button on each
search result, in the list and gallery views (`shared/_explain_button`). It
opens one shared dialog per results page (`shared/_explain_modal`), which loads
`SearchExplanationsController#show` only when it opens. Regular users see
nothing new, on purpose: the detail is for staff, to understand a result for
themselves and to explain it to a user in plain words.

The action reruns the search the page ran, with the same `q`, through the
asker's own gated search builder, narrowed to the one result by `fq=id:"<uuid>"`,
and asks for `fl=score,[explain style=nl]`. A filter never changes a score, so
the explanation is of the score the page ranked by. The gated builder means a
delegated admin cannot explain a record they could not find. It needs
`search_service_context` with the user, or the search gates as anonymous.

`SearchExplanation` reads edismax's tree. Each query word has a "max plus 0.01
times others" node: the field it matched best counts in full, and each other
field adds a hundredth of its own score. The phrase boost (`pf`) adds a second
such node, whose weights carry a quoted phrase. A boost function multiplies the
whole: Person records score 0.9. The dialog leads with a sentence an admin can
copy and pass on, then a table with one row per matched field, strongest
first: the record's own text with the matched words in bold, and the points
each search word earned there. Then the adjustments and the score. It does not
show Solr's raw tree: the audience is staff explaining a result, not
developers. A row is a field, not a word, so a field that several words matched
shows its text once (`SearchExplanation#fields`).

Two cases have nothing to score. A browse with no search terms says its results
are in browse order. A sort other than relevance gets a note that the score did
not set the item's place. `SearchExplanation::Match::LABELS` names each `qf` field as
the page does; a field missing from it shows its Solr name. Add one there when
`qf` gains a field.

Several `qf` fields fold into one label: the title is searched as written, as
stem variations (so a plural matches), without its sub- and superscript markup,
and as its alternative titles. So one word can list "Title" more than once.
`SearchExplanation::Match::FORMS` gives each such field a note on its row, and the
dialog shows a legend for the notes in the table. A new derived field needs an
entry in both `FORMS` and `FORM_NOTES`, or its row reads as a plain duplicate.

### The record's matched words

`MatchedWords` finds the record's words for each matched field through Solr's
field analysis handler (`/analysis/field` in `blacklight-core`). It sends the
record's stored text and the search words, and the handler runs both through
that field's analyzer and flags each record token that matches. So a stemmed
field bolds "Libraries" for a search on "library", and the bold falls on the
word as the record writes it.

- **Which text.** A derived field stores nothing, so `MatchedWords::SOURCES`
  maps each searched field to the stored fields it is copied from, mirroring
  the copyFields in `schema.xml`. Change both together. The controller asks for
  those stored fields (`MatchedWords::STORED`) in the explained search.
- **Which source.** The keywords field gathers eleven stored fields (subjects,
  creator, contributor, genre, publisher, place, photo category), so its own
  label would call a creator match a keyword. Each excerpt keeps the stored
  field it came from, and the row takes that field's facet label from
  `CatalogController` ("Creator") when every matched value shares one source.
  With mixed sources the row keeps "Keywords and subjects" and each value names
  its own.
- **One request per field.** A field's values are joined by newlines and sent
  as one POST, never a GET: a long description overflows Solr's request line.
- **Offsets.** Solr counts UTF-16 code units, and Ruby counts characters. They
  differ after an emoji or any other character outside the BMP, so each offset
  is converted before it slices the text.
- **Markup.** Each value loses its sub- and superscript tags before analysis, by
  pattern (never by HTML parsing, see `docs/metadata-text.md`).
- **The words as typed.** Solr's score tree holds only the searched form, so a
  stemmed match reads "survey" for a search on "Surveys". The same analysis
  response lists the query at every stage, and each token keeps its position
  through them all, so `MatchedWords` maps each searched form back to the word
  as typed. `SearchExplanation#typed` uses that map in the summary and the
  points. A word that matched only a field with no text to analyse keeps Solr's
  form.
- **No text to show.** The creator-name variants are computed by Atlas and not
  stored, and the full text is too long to send. Each says so instead
  (`MatchedWords::NO_TEXT`). A Solr failure gives the same kind of note, not an
  error.
