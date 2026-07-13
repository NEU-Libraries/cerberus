# frozen_string_literal: true

class CollectionsController < CatalogController
  include Thumbable
  include Transformable
  include ShowScopedSearch
  include DepositorContext
  include CollectionBreadcrumbs
  include RecordsImpressions

  authorize_resource_writes!(extra_edit: %i[sentinel])
  after_action :record_view_impression, only: :show

  # Scope the inherited Blacklight index to Collections only (see
  # CommunitiesController#search_service_context for the rationale and the
  # :index-only scoping). The :show page's find_children lists child Works, so
  # it must not be filtered to Collections.
  def search_service_context
    return super unless action_name == 'index'

    super.merge(resource_type_scope: 'Collection')
  end

  def show
    @collection = AtlasRb::Collection.find(params[:id])
    raise ResourceNotFound if @collection.nil?
    return render_gone(@collection) if @collection.tombstoned

    authorize_show!
    @response = find_children(@collection.valkyrie_id, params[:id])
    assign_show_abilities!(klass: 'Collection')
    collection_breadcrumbs(params[:id])
  end

  def tombstone
    perform_tombstone!(AtlasRb::Collection.tombstone(params[:id]), type: 'Collection')
  end

  def new
    @collection = OpenStruct.new
  end

  def edit
    @collection = AtlasRb::Collection.find(params[:id])
    form_preparation(@permissions)
    load_descriptive!('Collection')
    @sentinel = Sentinel.find_by(target_id: params[:id])
    collection_breadcrumbs(params[:id], editing: true)
  end

  def create
    permitted = params.expect(collection: [:title, :description]).to_h
    # Guard before minting: a blank title would otherwise produce an untitled
    # Collection (MODSMerge leaves a blank title untouched). Client-side
    # `required` is the first line; this is the backstop.
    return redirect_to(new_collection_path(parent_id: params[:parent_id])) if title_missing?(permitted)

    c = AtlasRb::Collection.create(params[:parent_id])
    save_descriptive!('Collection', c.id, title: permitted['title'], description: permitted['description'])
    redirect_to collection_path(c.id)
  end

  def update
    handle_metadata_update(klass: 'Collection', resource_key: :collection, keywords: false)
  end

  # Upsert this collection's derivative-access default (Sentinel). The container's
  # read groups (loaded by the :edit gate) are handed to the record so the model
  # can refuse a tier more visible than the collection; monotonicity is enforced
  # too. An incoherent policy is refused and the tab re-flashes.
  def sentinel
    record = Sentinel.find_or_initialize_by(target_id: params[:id])
    record.policy = sentinel_policy_from_params
    record.resource_read_groups = collection_read_groups
    back = edit_collection_path(params[:id], anchor: 'derivative-access')

    if record.save
      redirect_to back, notice: 'Derivative access default saved.'
    else
      redirect_to back, alert: record.errors.full_messages.to_sentence
    end
  end

  # The personal-root-aware breadcrumb trail (collection_breadcrumbs + helpers)
  # lives in CollectionBreadcrumbs, shared with XmlController's raw-XML editor.

  private

    # Build the per-tier policy from the tab's form. Restricted tiers carry their
    # checked read groups ([] when none). The default ("no added restriction")
    # mode maps by the collection's own visibility: on a public collection it is
    # an explicit public tier (['public']); on a private one the tier is omitted
    # so it inherits the Work's visibility at apply-time — a private collection
    # can't have a public tier, so claiming one would only be refused.
    def sentinel_policy_from_params
      tier_schema = Sentinel::TIERS.index_with { [:mode, { groups: [] }] }
      permitted = params.fetch(:sentinel, {}).permit(tier_schema)
      public_collection = collection_read_groups.include?('public')

      Sentinel::TIERS.each_with_object({}) do |tier, policy|
        entry = permitted[tier]
        next if entry.blank?

        if entry[:mode] == 'restrict'
          policy[tier] = Array(entry[:groups]).compact_blank
        elsif public_collection
          policy[tier] = ['public']
        end
      end
    end

    # The collection's own read groups (from the :edit gate's permissions load) —
    # the ceiling every derivative tier must stay within.
    def collection_read_groups
      Array(@permissions&.read)
    end
end
