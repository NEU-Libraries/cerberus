# frozen_string_literal: true

module Admin
  # Re-parent / Move surface. A self-contained, admin-only finder for moving a
  # Collection or Community to a new structural parent:
  #
  #   index         → search for the node to move
  #   choose_parent → search for its new parent (valid types only; self +
  #                   descendants excluded so a cycle can't be picked)
  #   confirm       → preview "move X from A → B"
  #   move          → perform via atlas_rb, then redirect to the node's page
  #
  # The Atlas re-parent endpoints + atlas_rb bindings (v1.2.0) already exist;
  # this is purely the Cerberus consumer. The acting admin's NUID flows to Atlas
  # ambiently (config/initializers/atlas_rb.rb wires Current.nuid), which both
  # passes Atlas's authz and stamps the re-parent audit event.
  class ReparentController < BaseController
    # Borrow CatalogController's Solr config (search fields / qf) so the finder's
    # ContainerSearch keyword query behaves like the catalog's. Configurable
    # supplies copy_blacklight_config_from (same pattern Blacklight's own
    # Bookmarks / SearchHistory controllers use); ApplicationController's
    # Blacklight::Controller doesn't pull it in on its own.
    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    # node class => container classes it may be re-parented under. Works are not
    # offered here (this surface is containers-only); Communities may also go to
    # the top of the tree (handled as a blank parent_id, not a candidate row).
    ALLOWED_PARENTS = {
      'Collection' => %w[Community Collection],
      'Community'  => %w[Community]
    }.freeze

    # Step 1 — find the node to move.
    def index
      @results = search_containers if params[:q].present?
    end

    # Step 2 — choose the destination parent for the chosen node.
    def choose_parent
      @node = load_node(params[:node_id])
      @allows_top_level = @node.klass == 'Community'
      return if params[:q].blank?

      @results = ContainerSearch.call(
        scope:                self,
        query:                params[:q],
        types:                ALLOWED_PARENTS.fetch(@node.klass, []),
        exclude_node_uuid:    params[:node_uuid].presence,
        exclude_subtree_noid: @node.resource.id
      )
    end

    # Step 3 — preview the move and confirm.
    def confirm
      set_confirm_ivars
    end

    # Perform the move.
    def move
      node = load_node(params[:node_id])
      parent_id = params[:parent_id].presence

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
        ContainerSearch.call(scope: self, query: params[:q])
      end

      def reparent(node, parent_id)
        case node.klass
        when 'Collection' then AtlasRb::Collection.reparent(node.resource.id, parent_id)
        when 'Community'  then AtlasRb::Community.reparent(node.resource.id, parent_id)
        end
      end

      def set_confirm_ivars
        @node = load_node(params[:node_id])
        @current_parent = immediate_parent(@node)
        @destination = params[:parent_id].present? ? load_node(params[:parent_id]) : nil
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
