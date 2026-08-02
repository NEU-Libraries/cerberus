# frozen_string_literal: true

# Finds resources that are more visible than the container they sit in.
#
# The write paths keep this invariant going forward — Atlas refuses a child that
# exceeds its parent, and narrowing a Collection cascades — but neither is
# retroactive, and narrowing a Community never cascades by design. So this is
# the only thing that surfaces violations that already exist, or that arrive by
# a route the guards don't cover.
#
# Reports rather than repairs. Whether a violation should be fixed by narrowing
# the child or widening the container is a curation decision that depends on
# what the material is, so automating it would be guessing.
#
# Checks each parent/child pair rather than walking full ancestry. The two are
# equivalent — if every pair holds, the chain holds — and pairwise costs two
# scans instead of a traversal per resource.
#
# Queries Solr directly, ungated: an audit has to see everything, including the
# resources the auditor could not otherwise discover.
class VisibilityAudit
  CONTAINER_TYPES = 'internal_resource_tesim:(Collection OR Community)'
  WORK_TYPE       = 'internal_resource_tesim:Work'
  BATCH           = 500
  CONTAINER_FIELDS = 'id,alternate_ids_ssim,title_tsim,internal_resource_tesim,' \
                     'read_access_group_ssim,a_member_of_ssi,personal_root_bsi'

  Violation = Struct.new(:noid, :klass, :read, :parent_noid, :parent_title, :parent_read,
                         keyword_init: true) do
    # Descendants of a private container are the disclosure the invariant exists
    # to prevent; a group mismatch is untidy but not open to the world.
    def public? = Array(read).include?('public')

    def to_s
      "#{klass} #{noid} [#{audience(read)}] in #{parent_noid} “#{parent_title}” [#{audience(parent_read)}]"
    end

    def audience(groups)
      Array(groups).presence&.join(', ') || 'private'
    end
  end

  # @return [Array<Violation>] worst first: public leaks, then the rest.
  def call
    (container_violations + work_violations).sort_by { |v| v.public? ? 0 : 1 }
  end

  private

    # uuid => the container's own noid, title and read audience. Small enough to
    # hold: containers are thousands, where Works are hundreds of thousands.
    def containers
      @containers ||= each_batch(CONTAINER_TYPES, CONTAINER_FIELDS).to_h do |doc|
        [doc.id, { noid: noid_of(doc), title: Array(doc['title_tsim']).first,
                   klass: Array(doc['internal_resource_tesim']).first, personal_root: doc['personal_root_bsi'],
                   read: Array(doc['read_access_group_ssim']), parent: doc['a_member_of_ssi'] }]
      end
    end

    # A root Community has no parent and is unconstrained.
    #
    # Personal roots are excluded, and not as a convenience. Atlas mints them
    # public on purpose: the People community they sit in has no public read, so
    # a root that merely inherited it would 403 its own owner out of their
    # workspace (see PersonalRootCreator). Every user therefore produces one
    # expected violation, and left in they would bury the real findings under
    # one line per account.
    def container_violations
      containers.filter_map do |_uuid, container|
        next if container[:personal_root]

        parent = containers[container[:parent].to_s.delete_prefix('id-')] if container[:parent]
        next if parent.nil?

        violation_for(container[:noid], container[:klass], container[:read], parent)
      end
    end

    def work_violations
      each_batch(WORK_TYPE, 'alternate_ids_ssim,read_access_group_ssim,a_member_of_ssi').filter_map do |doc|
        parent = containers[doc['a_member_of_ssi'].to_s.delete_prefix('id-')]
        next if parent.nil?

        violation_for(noid_of(doc), 'Work', Array(doc['read_access_group_ssim']), parent)
      end
    end

    def violation_for(noid, klass, read, parent)
      return if Permissions.audience_subset?(read, parent[:read])

      Violation.new(noid: noid, klass: klass, read: read,
                    parent_noid: parent[:noid], parent_title: parent[:title], parent_read: parent[:read])
    end

    def noid_of(doc)
      Array(doc['alternate_ids_ssim']).first&.delete_prefix('id-')
    end

    # Offset paging rather than one huge fetch: the Work scan is the whole
    # repository, and the existing 100k row caps elsewhere would silently
    # truncate an audit into a false all-clear.
    def each_batch(type_fq, fields, &block)
      return enum_for(:each_batch, type_fq, fields) unless block

      start = 0
      loop do
        docs = Blacklight.default_index.search(q: '*:*', fq: [type_fq], rows: BATCH, start: start, fl: fields)
                         .documents
        break if docs.empty?

        docs.each(&block)
        start += docs.size
      end
    end
end
