# frozen_string_literal: true

# The resources a narrowing cascade must rewrite, in the order it must rewrite
# them: deepest descendants first, the container itself last. See
# docs/narrowing.md.
#
# That order is a correctness requirement rather than a preference. Top-down
# opens a window in which every descendant exceeds the container, and a crash
# leaves it that way; bottom-up leaves an interrupted subtree over-narrowed,
# never leaking.
class NarrowingTargets
  include Enumerable

  AFFECTED_TYPES = NarrowingImpact::AFFECTED_TYPES
  ANCESTOR_FIELD = MembershipQuery::ANCESTOR_FIELD
  MAX_ROWS       = ContainerDescendantsQuery::MAX_ROWS

  # Works sort ahead of every container. Giving them a finite depth would only
  # invite an off-by-one against the deepest collection.
  LEAF_DEPTH = Float::INFINITY

  Target = Struct.new(:noid, :klass, :depth, keyword_init: true) do
    def atlas_class = AtlasRb.const_get(klass)
  end

  def initialize(noid:, uuid:)
    @noid = noid.to_s.delete_prefix('id-')
    @uuid = uuid
  end

  # Yields Targets deepest-first. The container is the shallowest and so sorts
  # last, with no special case.
  def each(&)
    ordered.each(&)
  end

  private

    def ordered
      @ordered ||= documents.filter_map { |doc| target_for(doc) }
                            .sort_by { |target| -target.depth }
    end

    def target_for(doc)
      noid  = Array(doc['alternate_ids_ssim']).first&.delete_prefix('id-')
      klass = Array(doc['internal_resource_tesim']).first
      return if noid.blank? || klass.blank?

      Target.new(noid: noid, klass: klass, depth: depth_of(doc, klass))
    end

    def depth_of(doc, klass)
      return LEAF_DEPTH if klass == 'Work'

      Array(doc[ANCESTOR_FIELD]).length
    end

    # One query for the whole subtree. NarrowingPolicy refuses a cascade above
    # NarrowingImpact::CASCADE_LIMIT, well under MAX_ROWS, so this cap cannot
    # silently truncate the set that actually reaches a job.
    def documents
      Blacklight.default_index.search(
        q: '*:*', fq: [subtree_fq, AFFECTED_TYPES], rows: MAX_ROWS,
        fl: "id,alternate_ids_ssim,internal_resource_tesim,#{ANCESTOR_FIELD}"
      ).documents
    end

    def subtree_fq
      ContainerDescendantsQuery.new(noid: @noid, uuid: @uuid).subtree_fq
    end
end
