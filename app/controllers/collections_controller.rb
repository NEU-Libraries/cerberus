# frozen_string_literal: true

class CollectionsController < CatalogController
  include Thumbable
  include Transformable
  include ShowScopedSearch
  include DepositorContext
  include CollectionBreadcrumbs
  include RecordsImpressions
  include ContainerAnalytics
  include ContainerRestrictionRequest

  authorize_resource_writes!(extra_edit: %i[sentinel request_restriction])
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
    @create_path = child_create_path('collections')
    new_form_permissions!(@destination_id)
  end

  def edit
    load_edit_state!
  end

  def create
    c = mint_titled!('Collection', :collection)
    return redirect_to(new_child_path('collection')) if c.nil?

    apply_new_permissions('Collection', c.id, :collection)
    redirect_to collection_path(c.id)
  end

  def update
    handle_metadata_update(klass: 'Collection', resource_key: :collection, keywords: false)
  end

  # Upsert this collection's derivative-access default (Sentinel). The container's
  # read groups (loaded by the :edit gate) are handed to the record so the model
  # can refuse a tier more visible than the collection; monotonicity is enforced
  # too. An incoherent policy is refused and the tab re-renders holding it.
  def sentinel
    record = Sentinel.find_or_initialize_by(target_id: params[:id])
    record.policy = sentinel_policy_from_params
    record.resource_read_groups = collection_read_groups

    return render_rejected_sentinel(record) unless record.save

    redirect_to edit_collection_path(params[:id], anchor: 'derivative-access'),
                notice: 'Derivative access default saved.'
  end

  # The personal-root-aware breadcrumb trail (collection_breadcrumbs + helpers)
  # lives in CollectionBreadcrumbs, shared with XmlController's raw-XML editor.

  private

    # Everything the edit page renders. Shared with the rejected-save path,
    # which re-renders the same page rather than redirecting to it.
    def load_edit_state!
      @collection = AtlasRb::Collection.find(params[:id])
      # How much a narrowing here would touch, for the form's confirmation. The
      # count is a property of the subtree rather than of the audience being
      # chosen, so it resolves once on load instead of on every change.
      impact = NarrowingImpact.new(noid: @collection.id, uuid: @collection.valkyrie_id)
      @narrowing_affected = impact.count
      # Whether this user could run the cascade themselves. Decided here so the
      # form offers the "ask an administrator" route instead of letting them
      # choose Private and bounce off a refusal.
      @narrowing_allowed = NarrowingPolicy.call(impact: impact, actor: current_user).allowed?
      form_preparation(@permissions, resource: @collection)
      load_descriptive!('Collection')
      @sentinel = Sentinel.find_by(target_id: params[:id])
      load_container_analytics(@collection, 'Collection')
      collection_breadcrumbs(params[:id], editing: true)
    end

    # Re-render the tab holding the policy that was SUBMITTED, not the stored
    # one. A refusal that redirects discards every selection the curator made,
    # so a ladder they got subtly wrong has to be rebuilt from memory — and the
    # ladder rules are precisely where seeing your own choices is the point.
    #
    # Render rather than redirect for the tab, too: the Location header does
    # carry the fragment, but Turbo follows a redirect with fetch, and the Fetch
    # spec strips the fragment from the resolved URL. The reader lands on the
    # first tab instead. Naming the pane server-side is the only way it holds.
    def render_rejected_sentinel(record)
      load_edit_state!
      @sentinel = record
      @open_tab = 'derivative-access'
      flash.now[:alert] = record.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end

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
