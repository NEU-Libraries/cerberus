# Membership queries

How Cerberus asks Solr "what is inside this container?", and why every fragment
it builds has to go in `:fq`.

Source files:

- `app/queries/membership_query.rb`

## Never put these fragments in `:q`

`MembershipQuery` builds Solr **filter query** (`fq`) fragments. Putting one in
`:q` does not raise — it silently returns wrong results.

The `/select` handler runs `q` through edismax, with a minimum-should-match of
`~2` and a title and text `qf`. Two things then go wrong:

- A multi-id membership OR placed in `q` parses to `+(clause clause clause)~2`,
  so a document has to match **two or more** of the ids to come back.
- A `{!terms}` query placed in `q` is swallowed as full text across the `qf`
  fields.

Filter queries are parsed by the lucene parser instead. No minimum-should-match,
no `qf`, so the fragments behave exactly as written.

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

**`identity_fq(uuids)`** matches documents by Solr's uniqueKey, the bare uuid. It
splices individually-named resources — a Set's directly-added Works — into a
membership `{!bool}`, or subtracts them via `excluding_fq`.

**`members_fq(container_uuids, include_linked:)`** matches documents that are
members of any of the containers. Structural membership only by default, ORing
in the linked overlay when asked.

**`member_clauses(...)`** exposes those membership clauses individually, so a
caller needing to OR them alongside *other* clauses — the subtree search's
container clause, for instance — can splice everything into one flat `{!bool}`.

**`term_list(uuids)`** maps bare uuids to the `id-<uuid>` term form Solr indexes,
comma-joined for the `{!terms}` parser. An empty list yields an empty term
string, which matches no documents. That is the correct answer for "members of
nothing".

## Two Solr parser constraints that shape the code

**A bare leading `-` cannot precede a localparams clause.** `{!terms}` has to
open the parameter in order to be its parser. So `excluding_fq` builds the
subtraction as a `{!bool}` with an explicit `must="*:*"` anchor — a `must_not`
needs a positive base to subtract from.

**A `{!bool}` cannot be nested inside another bool's quoted `should=`.** Solr's
parser rejects it. Build one flat `{!bool}` from all the clauses instead, which
is why `any_of` returns a single clause bare rather than wrapping it, and why
`member_clauses` exists at all.
