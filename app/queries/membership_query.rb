# frozen_string_literal: true

# Builds Solr *filter-query* (`fq`) fragments for tree + DAG membership resolution.
#
# ⚠️ EVERY fragment here belongs in `:fq`, NEVER in `:q`.
#
# The `/select` handler runs `q` through edismax with a minimum-should-match (~2) and
# a title/text `qf`. A multi-id membership OR placed in `q` parses to
# `+(clause clause clause)~2` and silently returns WRONG results (a doc must match
# 2+ of the ids), while a `{!terms}` query in `q` is swallowed as full-text across the
# `qf` fields. Filter queries are parsed by the lucene parser — no mm, no qf — so the
# fragments below behave exactly as written. Always match the untokenized string
# projections (`_ssi`/`_ssim`) with `{!terms}`, never the tokenized `_tesim`.
#
# Verified against live Solr (2026-06-01). See CatalogController#find_children for the
# canonical fq-position usage.
class MembershipQuery
  # Scalar single-parent edge (the structural tree). Value shape: `id-<uuid>`.
  STRUCTURAL_FIELD = 'a_member_of_ssi'
  # Leaves-only DAG overlay (Works linked into additional collections). `id-<uuid>`.
  LINKED_FIELD = 'a_linked_member_of_ssim'
  # Transitive ancestor chain, denormalized onto Collections/Communities only.
  # Value shape: BARE noids (no `id-` prefix); excludes the doc itself.
  ANCESTOR_FIELD = 'ancestor_ids_ssim'

  class << self
    # fq matching every Collection/Community whose ancestor chain includes
    # +anchor_noid+ — i.e. all descendants of the anchor (the anchor itself excluded,
    # since a node is not its own ancestor).
    #
    # @param anchor_noid [String] the anchor's bare noid as stored in
    #   {ANCESTOR_FIELD}. A leading `id-` (as carried by `alternate_ids_ssim`) is
    #   tolerated and stripped.
    # @return [String] an fq fragment (for `:fq`, never `:q`).
    def descendants_fq(anchor_noid)
      "{!terms f=#{ANCESTOR_FIELD}}#{normalize_noid(anchor_noid)}"
    end

    # fq matching docs that are members of any of +container_uuids+. Structural
    # membership only by default; OR-s in the linked-member overlay when
    # +include_linked+ is true.
    #
    # @param container_uuids [Array<String>] bare uuids (no `id-` prefix) of the
    #   containers whose members to match.
    # @param include_linked [Boolean] also match Works linked into the containers
    #   via {LINKED_FIELD}.
    # @return [String] an fq fragment (for `:fq`, never `:q`).
    def members_fq(container_uuids, include_linked: false)
      any_of(member_clauses(container_uuids, include_linked: include_linked))
    end

    # The individual membership should-clauses (structural, plus the linked
    # overlay when +include_linked+). Exposed so a caller that needs to OR these
    # alongside *other* clauses — e.g. the subtree search's container clause —
    # can splice them into a single flat {!bool} rather than nesting one bool
    # inside another's quoted `should=`, which Solr's parser rejects.
    #
    # @return [Array<String>] one or two {!terms} fragments.
    def member_clauses(container_uuids, include_linked: false)
      terms = term_list(container_uuids)
      clauses = ["{!terms f=#{STRUCTURAL_FIELD}}#{terms}"]
      clauses << "{!terms f=#{LINKED_FIELD}}#{terms}" if include_linked
      clauses
    end

    # OR a set of fq clauses into one flat {!bool}. A single clause is returned
    # bare (no redundant wrapper); never nest the result inside another bool's
    # quoted `should=` — build one flat {!bool} from all clauses instead.
    #
    # @param clauses [Array<String>] fq fragments.
    # @return [String] a single fq fragment.
    def any_of(clauses)
      clauses = Array(clauses).compact
      return clauses.first if clauses.one?

      %({!bool #{clauses.map { |clause| %(should="#{clause}") }.join(' ')}})
    end

    private

      # Map bare uuids to the `id-<uuid>` term form Solr indexes, comma-joined for the
      # {!terms} parser. An empty list yields an empty term string, which matches no
      # documents (the correct answer for "members of nothing").
      def term_list(uuids)
        Array(uuids).map { |uuid| "id-#{uuid}" }.join(',')
      end

      def normalize_noid(noid)
        noid.to_s.delete_prefix('id-')
      end
  end
end
