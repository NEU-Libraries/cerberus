# Membership queries

How Cerberus asks Solr "what is inside this container?", and why every fragment
it builds has to go in `:fq`.

Source files:

- `app/queries/membership_query.rb`

## Never put these fragments in `:q`

`MembershipQuery` builds Solr **filter query** (`fq`) fragments. A fragment put
in `:q` does not raise. Solr silently returns the wrong documents.

Solr dispatches Blacklight's `/select` request to the core's default `search`
handler. That handler runs `q` through edismax, with a minimum-should-match of
`2<-1 5<-2 6<90%` and a `qf` spanning title, description, identifier and
full-text fields. The core's `solrconfig.xml` lives in the `blacklight-solr`
repository, not here. Two things then go wrong:

- A multi-id membership OR placed in `q` must match most of its clauses. Three
  ids parse to `+(clause clause clause)~2`, so a document has to match **two**
  of them to come back.
- A `{!terms}` query placed in `q` is swallowed as full text across the `qf`
  fields.

Solr parses filter queries with the lucene parser instead. It applies no
minimum-should-match and no `qf`, so the fragments behave exactly as written.

Match the untokenized string projections (`_ssi` and `_ssim`) with `{!terms}`,
never the tokenized `_tesim`.

## The three membership fields

| Constant | Field | Shape of the value |
|---|---|---|
| `STRUCTURAL_FIELD` | `a_member_of_ssi` | `id-<uuid>`. The scalar single-parent edge — the structural tree |
| `LINKED_FIELD` | `a_linked_member_of_ssim` | `id-<uuid>`. A leaves-only DAG overlay, for Works linked into additional collections |
| `ANCESTOR_FIELD` | `ancestor_ids_ssim` | **bare noids**, no `id-` prefix. The transitive ancestor chain, denormalized onto Collections and Communities only, and excluding the document itself |

The prefix difference is the one to watch. Two of the three carry `id-`, and the
ancestor chain does not.

## What each builder returns

**`descendants_fq(anchor_noids)`** matches every Collection or Community whose
ancestor chain includes any of the anchors. The anchors themselves are excluded,
because a node is not its own ancestor. It takes bare noids, and tolerates and
strips a leading `id-` for callers passing values from `alternate_ids_ssim`.

**`identity_fq(uuids)`** matches documents by Solr's uniqueKey, the bare uuid.
Callers use it to splice individually-named resources, such as a Set's
directly-added Works, into a membership `{!bool}`. They also pass it to
`excluding_fq` to subtract those resources.

**`members_fq(container_uuids, include_linked:)`** matches documents that are
members of any of the containers. Structural membership only by default, ORing
in the linked overlay when asked.

**`member_clauses(container_uuids, include_linked:)`** returns those membership
clauses as an array. A caller can then OR them alongside *other* clauses in one
flat `{!bool}`. `CatalogController#subtree_membership_fq` does this with the
`descendants_fq` clause.

**`any_of(clauses)`** ORs clauses into one flat `{!bool}` of `should=` clauses.
It returns a single clause bare.

**`excluding_fq(clause)`** matches everything the clause does not.

The private helper **`term_list(uuids)`** maps bare uuids to the `id-<uuid>` term form Solr
indexes, comma-joined for the `{!terms}` parser. An empty list yields an empty
term string, which matches no documents. That is the correct answer for "members
of nothing".

## Two Solr parser constraints that shape the code

**A bare leading `-` cannot precede a localparams clause.** `{!terms}` has to
open the parameter to be its parser. So `excluding_fq` builds the subtraction as
a `{!bool}` with an explicit `must="*:*"` anchor — a `must_not` needs a positive
base to subtract from.

**A `{!bool}` cannot be nested inside another bool's quoted `should=`.** Solr's
parser rejects it. Build one flat `{!bool}` from all the clauses instead. That
is why `any_of` returns a single clause bare rather than wrapping it, and why
`member_clauses` exists at all.
