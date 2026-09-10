# frozen_string_literal: true

# Builds Solr filter-query (`fq`) fragments for tree + DAG membership.
#
# EVERY fragment here belongs in `:fq`, NEVER in `:q`. In `:q` edismax applies
# minimum-should-match, so a multi-id OR silently requires 2+ matches, and a
# {!terms} query is swallowed as full text. Match the untokenized `_ssi`/`_ssim`
# projections, never the tokenized `_tesim`. See docs/search.md.
class MembershipQuery
  # Scalar single-parent edge (the structural tree). Value shape: `id-<uuid>`.
  STRUCTURAL_FIELD = 'a_member_of_ssi'
  # Leaves-only DAG overlay (Works linked into additional collections). `id-<uuid>`.
  LINKED_FIELD = 'a_linked_member_of_ssim'
  # Transitive ancestor chain. BARE noids -- no `id-` prefix, unlike the two above.
  ANCESTOR_FIELD = 'ancestor_ids_ssim'

  class << self
    # Descendants of the anchor(s), anchors excluded. Takes BARE noids.
    def descendants_fq(anchor_noids)
      "{!terms f=#{ANCESTOR_FIELD}}#{Array(anchor_noids).map { |n| normalize_noid(n) }.join(',')}"
    end

    def identity_fq(uuids)
      "{!terms f=id}#{Array(uuids).join(',')}"
    end

    # Everything EXCEPT what +clause+ matches. A bare leading `-` cannot precede a
    # localparams clause, so this is a {!bool} with an explicit must="*:*" anchor:
    # a must_not needs a positive base to subtract from.
    def excluding_fq(clause)
      %({!bool must="*:*" must_not="#{clause}"})
    end

    # Members of any of +container_uuids+ (bare uuids).
    def members_fq(container_uuids, include_linked: false)
      any_of(member_clauses(container_uuids, include_linked: include_linked))
    end

    # Exposed so a caller can splice these into ONE flat {!bool} alongside other
    # clauses -- Solr rejects a bool nested in another bool's quoted `should=`.
    def member_clauses(container_uuids, include_linked: false)
      terms = term_list(container_uuids)
      clauses = ["{!terms f=#{STRUCTURAL_FIELD}}#{terms}"]
      clauses << "{!terms f=#{LINKED_FIELD}}#{terms}" if include_linked
      clauses
    end

    # OR clauses into one flat {!bool}; a single clause is returned bare. Never
    # nest the result inside another bool's quoted `should=`.
    def any_of(clauses)
      clauses = Array(clauses).compact
      return clauses.first if clauses.one?

      %({!bool #{clauses.map { |clause| %(should="#{clause}") }.join(' ')}})
    end

    private

      # An empty list yields an empty term string, matching no documents -- the
      # correct answer for "members of nothing".
      def term_list(uuids)
        Array(uuids).map { |uuid| "id-#{uuid}" }.join(',')
      end

      def normalize_noid(noid)
        noid.to_s.delete_prefix('id-')
      end
  end
end
