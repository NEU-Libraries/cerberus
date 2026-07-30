# frozen_string_literal: true

module Admin
  # Re-parent / Move surface. A self-contained finder for moving a Work,
  # Collection, or Community to a new structural parent, reachable by :admin
  # and by the devolved-admin tier (User#admin_delegate?):
  #
  #   index         → search for the node to move
  #   choose_parent → search for its new parent (valid types only; self +
  #                   descendants excluded so a cycle can't be picked)
  #   confirm       → preview "move X from A → B"
  #   move          → perform via atlas_rb, then redirect to the node's page
  #
  # The DRS tree has no floating top level, so every step requires a real
  # destination parent — there is no "move to top / no parent" option for any
  # node class (the top of the tree is fixed, not a place things get moved to).
  #
  # The Atlas re-parent endpoints + atlas_rb bindings already exist; this is
  # purely the Cerberus consumer. The acting user's NUID flows to Atlas
  # ambiently (config/initializers/atlas_rb.rb wires Current.nuid), which both
  # passes Atlas's authz (Atlas's own Ability grants :reparent to :admin and,
  # separately, to the same :privileged + admin-group pair — see
  # apply_admin_delegate_abilities) and stamps the re-parent audit event.
  class ReparentController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    # Borrow CatalogController's Solr config (search fields / qf) so the finder's
    # ContainerSearch keyword query behaves like the catalog's. Configurable
    # supplies copy_blacklight_config_from (same pattern Blacklight's own
    # Bookmarks / SearchHistory controllers use); ApplicationController's
    # Blacklight::Controller doesn't pull it in on its own.
    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    # node class => container classes it may be re-parented under. Works nest
    # only under Collections (Atlas rejects anything else as an invalid parent
    # type); Collections and Communities nest under containers as before.
    ALLOWED_PARENTS = {
      'Work'       => %w[Collection],
      'Collection' => %w[Community Collection],
      'Community'  => %w[Community]
    }.freeze

    # Step 1 — find the node to move.
    breadcrumb_for 'Re-parent / Move', :admin_reparent_path

    def index
      @results = search_containers if params[:q].present?
    end

    # Step 2 — choose the destination parent for the chosen node.
    def choose_parent
      breadcrumb 'Choose parent', admin_reparent_choose_parent_path
      @node = load_node(params[:node_id])
      @allowed_parent_label = allowed_parent_label(@node.klass)
      return if params[:q].blank?

      @results = ResourceSearch.call(
        scope:                self,
        query:                params[:q],
        types:                ALLOWED_PARENTS.fetch(@node.klass, []),
        exclude_node_uuid:    params[:node_uuid].presence,
        exclude_subtree_noid: @node.resource.id
      )
    end

    # Step 3 — preview the move and confirm. A destination is mandatory —
    # redirect back to choose_parent rather than preview a "no parent" move.
    def confirm
      return redirect_to_choose_parent if params[:parent_id].blank?

      breadcrumb 'Confirm', admin_reparent_confirm_path
      set_confirm_ivars
    end

    # Perform the move. Same mandatory-destination guard as confirm.
    def move
      node = load_node(params[:node_id])
      parent_id = params[:parent_id].presence
      return redirect_to_choose_parent(node) if parent_id.nil?

      if reparent(node, parent_id)
        redirect_to node_path(node),
                    notice: "Moved “#{node.resource.title}” to its new home."
      else
        set_confirm_ivars
        flash.now[:alert] = 'Move could not be completed — the destination may be ' \
                            'invalid or have changed since you chose it. Please re-check and try again.'
        render :confirm, status: :unprocessable_content
      end
    end

    private

      # Atlas resolves the node by id and tells us its type; a bad id raises
      # JSON::ParserError → Authorizable's rescue renders the 404 page.
      def load_node(id)
        AtlasRb::Resource.find(id)
      end

      def search_containers
        ResourceSearch.call(scope: self, query: params[:q], types: ALLOWED_PARENTS.keys)
      end

      def reparent(node, parent_id)
        case node.klass
        when 'Work'       then AtlasRb::Work.reparent(node.resource.id, parent_id)
        when 'Collection' then AtlasRb::Collection.reparent(node.resource.id, parent_id)
        when 'Community'  then AtlasRb::Community.reparent(node.resource.id, parent_id)
        end
      end

      def set_confirm_ivars
        @node = load_node(params[:node_id])
        @current_parent = immediate_parent(@node)
        @destination = load_node(params[:parent_id])
      end

      # Human-readable list of the container types a node of this class may be
      # moved under, e.g. "Community or Collection" / "Collection".
      def allowed_parent_label(klass)
        ALLOWED_PARENTS.fetch(klass, []).to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')
      end

      def redirect_to_choose_parent(node = nil)
        node ||= load_node(params[:node_id])
        redirect_to admin_reparent_choose_parent_path(node_id: node.resource.id),
                    alert: 'Choose a destination — every node in the DRS tree must have a parent.'
      end

      # The node's current immediate parent, as a lightweight display object
      # (title + noid + klass), or nil when the node is already top-level.
      # `ancestors` is ordered root→…→parent, so the last entry is the parent.
      def immediate_parent(node)
        ancestors = Array(node.resource.ancestors)
        return nil if ancestors.empty?

        parent_id, parent_klass = ancestors.last
        found = AtlasRb.const_get(parent_klass).find(parent_id)
        OpenStruct.new(title: found.title, noid: parent_id, klass: parent_klass)
      end

      def node_path(node)
        public_send("#{node.klass.downcase}_path", node.resource.id)
      end
      helper_method :node_path
  end
end
