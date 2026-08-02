# frozen_string_literal: true

# The resources a narrowing cascade must rewrite, in the order it must rewrite
# them: deepest descendants first, the container itself last.
#
# That order is a correctness requirement rather than a preference. Narrowing a
# descendant is always legal — a narrower child is trivially within its still-
# broad parent's audience — so Atlas's containment rule never fires mid-cascade
# and the invariant holds at every intermediate step. An interrupted run leaves
# a subtree that is over-narrowed and incomplete, never one that is leaking.
# Top-down would invert that: narrowing the container first opens a window in
# which every descendant exceeds it, and a crash leaves it that way.
#
# Depth comes free from the index — ancestor_ids_ssim carries the full chain, so
# its length is how deep a container sits. Works carry no ancestry at all (the
# field is denormalized onto containers only, deliberately: Works are the bulk
# of the graph and have no descendants), which is also the reason they can be
# treated as the deepest rank without computing anything.
class NarrowingTargets
  include Enumerable

  # Same restriction as NarrowingImpact, for the same reason: only resources
  # that carry a read ACL of their own. A Work's FileSets follow the Work.
  AFFECTED_TYPES = NarrowingImpact::AFFECTED_TYPES
  ANCESTOR_FIELD = MembershipQuery::ANCESTOR_FIELD
  MAX_ROWS       = ContainerDescendantsQuery::MAX_ROWS

  # Works sort ahead of every container. They are leaves, so no container can
  # sit below one, and giving them a finite depth would only invite an
  # off-by-one against the deepest collection.
  LEAF_DEPTH = Float::INFINITY

  Target = Struct.new(:noid, :klass, :depth, keyword_init: true) do
    # The atlas_rb resource class that owns this noid's metadata endpoint.
    def atlas_class = AtlasRb.const_get(klass)
  end

  def initialize(noid:, uuid:)
    @noid = noid.to_s.delete_prefix('id-')
    @uuid = uuid
  end

  # Yields Targets deepest-first. The container itself is included and sorts
  # last: it is the ancestor of everything else in the set, so it necessarily
  # has the shallowest depth and needs no special case.
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

    # One query for the whole subtree. Bounded by the caller: NarrowingPolicy
    # refuses a cascade above NarrowingImpact::CASCADE_LIMIT, which sits well
    # under this row ceiling, so the cap cannot silently truncate the set that
    # actually reaches a job.
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
