# Discovery surfaces

The pages that ask Solr "what is here, and what may this person see?" — the
community landing page, My DRS, the admin finders, the genre showcases the
deposit fork publishes into, and the Google Scholar tags on a Work.

Source files:

- `app/services/resource_search.rb`
- `app/services/showcase_finder.rb`
- `app/services/showcase_provisioner.rb`
- `app/services/collection_contents_resolver.rb`
- `app/services/google_scholar_metadata.rb`
- `app/controllers/communities_controller.rb`
- `app/controllers/my_drs_controller.rb`

Two neighbouring pages carry the machinery these files reuse. `docs/search.md`
holds `MembershipQuery` — the membership fields, and why every fragment goes in
`:fq`. `docs/permissions.md` holds the ACL vocabulary and `UNOWNED_NUID`.
`docs/sets.md` holds `SetResolver`, whose export surface
`CollectionContentsResolver` mirrors.

## Every query on this page is gated

Each of these files reaches Solr through the Blacklight `SearchBuilder` chain,
either `SearchBuilder.new(scope)` with the controller as scope, or the
controller's own `search_service.search_builder`. That chain applies gated
discovery for the acting user.

Gating is the reason these lookups can be written plainly. A showcase a
depositor may not discover never reaches the publish menu. A restricted Work
never reaches a collection export. An admin sees non-public resources in the
finders, which is what makes the finders useful.

The failure mode is silent. A hand-built `Blacklight.default_index.search` with
literal params returns the ungated set, and nothing raises. The inline comments
in these files mark the gating for that reason.

## Finding a resource to move or link

`ResourceSearch` answers "which resources of these types match what the admin
typed?". It is the finder behind two admin flows.

| Flow | Step | Types searched |
|---|---|---|
| Re-parent | Pick the node to move | Work, Collection, Community — anything can be moved |
| Re-parent | Pick the destination | Whatever `ALLOWED_PARENTS` permits for that node's class |
| Linked members | Pick the Work, then the Collection | Work, then Collection |
| Analytics tab | Look up an item in one container | Constrained by `within_fq` |

It runs the same `Blacklight.default_index.search(params: builder)` idiom as the
other Solr service objects. Unlike them it resolves no subtree; it matches a
keyword.

### Arguments

| Argument | Meaning |
|---|---|
| `scope:` | The controller. Supplies the Blacklight config, copied from `CatalogController`, and the `current_user` that gated discovery reads |
| `query:` | The admin's keyword query. Blank returns an empty response |
| `types:` | `internal_resource` types to match, such as `%w[Collection Community]` |
| `exclude_node_uuid:` | Solr `id` (uuid) of the node being moved, so a node cannot be its own parent |
| `exclude_subtree_noid:` | Noid of the node being moved. Excludes every container whose `ancestor_ids_ssim` contains it — that is, its descendants |
| `within_fq:` | An extra raw fq fragment ANDed onto the search, such as `ContainerDescendantsQuery#subtree_fq`, for a finder that must stay inside one container's subtree rather than search the whole repository |

A blank query returns an empty `Blacklight::Solr::Response` rather than
everything. The container tree runs to thousands of rows, and an empty search
box is not a request for all of them.

The two exclusion arguments pre-empt Atlas. Atlas rejects a move into the node
itself or into its own descendant with a `cycle` error. Filtering those
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

`CommunitiesController#create` provisions every new community, and the
development and staging reset seed provisions the ones it creates. Each showcase
is a featured Collection titled after its genre, written through the same
structure-safe MODS merge the descriptive forms use: parse the freshly minted
MODS, merge the title and abstract in, write the raw XML back. That is the path
`Transformable#save_descriptive!` takes.

A failed showcase create is logged and skipped, so one failure cannot abort the
rest. The community already exists by then, and an administrator can create a
missing showcase later. That tolerance is also why `CommunitiesController` still
tests for showcases rather than assuming them.

The acting principal comes from the ambient `Current.nuid`, set by the
controller or by the reset seed's `Current.set` block. The showcase itself
records `Permissions::UNOWNED_NUID` as depositor. See `docs/permissions.md` for
why the anonymous NUID is the safe choice for a container nobody personally
owns.

### Finding

`ShowcaseFinder` has two shapes, and the second argument chooses between them.

```ruby
ShowcaseFinder.call(scope:, community_noid:)
# => { "Presentations" => "<noid>", "Datasets" => "<noid>", ... }

ShowcaseFinder.call(scope:, community_noid:, genre_label: "Datasets")
# => "<noid>", or nil
```

The map form is what `WorksController#new` offers as publish categories. The
single-noid form is the linked-member edge target `WorksController#create`
writes on publish.

The lookup matches featured Collections inside the community's subtree
(`MembershipQuery.descendants_fq`) whose title is one of the shared genre
labels from `FeaturedContent`. A community holds one showcase per genre, so the
map stays small, and a duplicate title — which provisioning does not produce —
resolves last-writer-wins.

## The community landing page

`CommunitiesController` inherits `CatalogController`, so browse, faceting and
pagination are Blacklight's.

### Scoping the index

`search_service_context` scopes the index action to Communities, and only the
index action. Two things depend on that split:

- Without the scope, `/communities` inherits the unscoped browse and lists every
  resource type — Collections, Works and People included. `SearchBuilder#scope_to_resource_type`
  applies it.
- The show page must not be scoped. Its `find_children` surfaces the child
  Collections inside a community, which a Community-only filter would remove.

### Hiding empty showcases

The browse lists only featured Collections that have content, as v1 did.
Provisioning seeds every community with the full genre set, so without this the
browse fills with empty showcase rows.

The controller computes the empty showcases first and passes them to
`find_children` as an exclusion at query time. It is deliberately not a Ruby
post-filter over the returned documents: Solr's facet counts are computed
server-side, so a post-filter leaves the Type facet counting rows the reader
cannot see.

Only `featured?` showcases are hidden. An ordinary empty Collection stays
listed, because showing someone the empty collection they just made is the point.
The rule pairs with the Faculty and Staff node: both curated affordances appear
only when populated.

`populated_showcase_ids` asks one gated, `rows: 0` facet query over the two
membership fields, restricted to those showcases. It reads the raw
`facet_counts` rather than a Blacklight facet, so the answer does not depend on
the facet configuration in `CatalogController`. Solr returns each field as a
flat `[value, hits, value, hits, ...]` array, and the values carry the `id-`
prefix that `docs/search.md` describes.

### Whether Delete is offered

The listing is not the whole test. Atlas refuses to tombstone a container while
any live member remains, and a showcase Collection is a live member even when it
is empty and therefore hidden from the listing.

Testing the listing alone offered Delete on a community reading "This community
is empty", then failed the delete and told the reader to withdraw contents they
could not see. `deletable?` therefore tests the showcases as well.

In practice that makes Delete unavailable for any community that provisioned
normally. It stays a real test rather than a flat "never", because
`ShowcaseProvisioner` tolerates a failed create and a community can legitimately
have no showcases.

### The Faculty and Staff row

A community with affiliated People gets a synthetic "Faculty and Staff" row at
the top of its browse. It is rendered through the normal Blacklight pipeline, so
it matches the list and gallery rows exactly.

It appears only on the unfiltered first page, mirroring v1's `current_page == 1
&& no constraints`, and drops out as soon as the visitor searches within the
community or applies a facet.

The row is a `SolrDocument` built in Ruby; no such document exists in Solr.
Three fields shape it:

| Field | Effect |
|---|---|
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
the count filters on that field.

### Narrowing a community

The edit form offers Private to administrators only, and `@narrowing_allowed`
carries that decision to the view.

A community narrows its own object alone. No cascade reaches the collections
inside it, which stay exactly as visible and as searchable as they were. That
shallowness is the feature — it holds a community's landing page back without
touching its contents — but it is sharp enough to be administrator-only, and the
form has to say what it does and does not do. Everyone else gets the restriction
request form. `docs/permissions.md` covers the server-side refusal that backs
this up.

### Ordering inside `create`

`create` mints and titles the community first, then provisions the showcases. A
community that fails to get a title never leaves orphaned showcases behind.

## My DRS

`MyDrsController` renders the depositor's two-space home.

- The **workspace** on the left holds the Collections they own: drafts and
  working files, discoverable by their own visibility but never promoted.
- **Published** on the right holds the works they promoted into their
  community's genre showcases, grouped by category.

The split makes the curation boundary legible — workspace against the
professional tier — which is what the weighted deposit fork exists to express.

It inherits `CatalogController` for the gated `search_service`. The depositor
context, meaning their Person record and owned Collections, comes from
`DepositorContext`, which the deposit fork shares.

### The panels

| Panel | Query | Why it is here |
|---|---|---|
| Account switcher | `AtlasRb::User.accounts` | The staff and student logins under one NUID. The view renders it only when there is more than one. An Atlas fault degrades to an empty list, so a hiccup costs the panel rather than the page |
| Workspace collections | `DepositorContext` | The Collections this person owns |
| Published | Showcase lookup, then per-showcase membership | Grouped by category |
| Deposits to finish | `in_progress_bsi:true` | Deposits this person started and never confirmed. My DRS is the only place they can find one: an unfinished deposit is hidden from general discovery, and its depositor is the one person who can finish it |
| Incomplete works | `incomplete_bsi:true` | Finished works missing something a job failed to make. The depositor cannot repair one, so the panel exists to tell them rather than leave them assuming a missing thumbnail is how DRS looks |
| New collection | `personal_root_id` | Offered only to a depositor who has a personal root to create the collection under |

### Grouping the published works

`published_by_category` returns `[[label, [work_docs]], ...]` in the shared
genre vocabulary's order. It includes only categories holding at least one
published work, so an all-empty result is `[]`, which the view renders as the
column-level empty state.

It gets there in two steps. `showcase_docs` runs one gated query across the
subtrees of every community the person is affiliated with, and returns
documents rather than ids, because callers need both the noid for routing and
the uuid for membership. `works_published_into` then asks, per showcase, for
this depositor's works carrying the linked-member edge the publish branch wrote.

## Exporting a collection's contents

`CollectionContentsResolver` gives `MetadataExportPacker` a Collection's member
Works as gated Solr documents, page-batched. It is the collection counterpart of
the slice of `SetResolver` that bulk export needs: the same
`each_content_batch` and `contents_count` surface, and the same
`SetResolver::MAX_EXPORT_ROWS` runaway cap. See `docs/sets.md` for the Set side.

It takes the collection's uuid — the Solr uniqueKey form stored in the
membership fields, typically `collection.valkyrie_id` — and the controller's
`search_service`, which supplies the gated builder and the index.

The resolver returns direct members only, structural plus the linked overlay.
That matches the Collection show page's browse semantics,
`CatalogController#find_children` with no query. Works in sub-collections are not
pulled, and containers are excluded: only leaf Works count as contents.

### The field list comes from the packer

`each_content_batch` sets `fl` from
`MetadataExportPacker::REQUIRED_DOC_FIELDS` rather than a list written in the
resolver, and the two must not drift.

A field the packer reads and the query does not fetch raises nothing anywhere.
The document simply has no value, and the manifest gets a blank cell. That
emptied the Embargoed? and Embargo Date columns on a collection export while a
set export of the same Work filled them. Because a manifest row carrying a PID
*updates* that record, re-loading the export then cleared an embargo nobody had
touched.

## Google Scholar tags

`GoogleScholarMetadata` builds the Highwire Press `<meta>` tag set for a Work
show page.

It reads the Work's Solr document and nothing else. Parsing MODS XML on the
render path is a hard design constraint, so Atlas's `CitationIndexer` projects
the pieces Scholar needs — `creator_ssim`, `keyword_ssim`, `pub_date_ssim` —
onto the Work document, where title, abstract and genre already lived. Public
status and embargo come from the resource permissions the show page has already
loaded.

`CITATION_FL` keeps the lookup to the fields the tags need. A Solr failure
degrades to no tags rather than breaking a show page that otherwise has no Solr
dependency.

### What gets tags

Only a public Work whose MODS genre is one of `SCHOLAR_GENRES`: Research
Publications, Technical Reports, or Theses and Dissertations. v1 restricted the
tags the same way. Emitting `citation_*` for a photo or an A/V clip would be
noise to Scholar.

The view reads the value object and renders into `<head>`. URL building, meaning
`citation_pdf_url`, stays in the view, where the request host is known.

### The PDF pointer

`pdf_blob_noid` returns the noid of the first downloadable PDF Blob, and only
when the Work is public and not under embargo. Returning nil suppresses the tag,
which is how a private or embargoed file stays unadvertised. The view turns the
noid into an absolute download URL.

| Constructor argument | Meaning |
|---|---|
| `work:` | The show page's `AtlasRb::Work`, for the display title |
| `permissions:` | The resource permissions loaded by `authorize_show!`. `read` carries `public`; `embargo` carries a date string |
| `files:` | The Work's assets, from `AtlasRb::Work.assets` |
| `solr_doc:` | The Work's Solr document, or nil |
