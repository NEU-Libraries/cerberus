# frozen_string_literal: true

# Sets — the user-facing surface over Atlas Compilations ("Set" is the only
# word a user sees; "Compilation" is the wire/model name).
#
# Inherits CatalogController so the show page's contents are a real scoped
# Blacklight search — SetResolver supplies the recipe fq and the live search
# state (q / facets / sort / page) is threaded onto the same builder, exactly
# the way Collection/Community show pages embed their children. Atlas is the
# authorization boundary for the Set object itself (per-row read/edit);
# contents visibility rides the standard gated discovery on every query.
class SetsController < CatalogController
  include ShowScopedSearch

  before_action :authenticate_user!, except: [:show]
  before_action :require_curator,    except: [:show]
  before_action :load_set,           except: [:index, :new, :create, :picker, :recipients]

  # A private Set read (or any write) the caller may not perform: Atlas says
  # 403, the user sees the standard forbidden page. Unknown ids surface as
  # JSON::ParserError → Authorizable's 404 path.
  rescue_from AtlasRb::ForbiddenError do
    render template: 'errors/forbidden', status: :forbidden
  end

  # My Sets (owner-scoped, default) plus the two grant-scoped discovery tabs —
  # "Shared with me" (read + edit grants) and "Editable by me" (edit grants) —
  # backed by atlas_rb's `scope:` listing (owned Sets are excluded server-side
  # from the grant-scoped modes; group membership is resolved by Atlas).
  SCOPES = %w[shared editable].freeze

  def index
    @scope = params[:scope].presence_in(SCOPES)
    page = AtlasRb::Compilation.list(scope: @scope, page: params[:page].presence)
    # Unlike .find/.create, .list entries arrive wrapped: {"compilation" => {...}}.
    @sets = Array(page['compilations']).pluck('compilation')
    @pagination = page['pagination']
    # Grant-scoped tabs list other people's Sets, so name each owner.
    @owner_names = @scope ? NuidResolver.names_for(@sets.map { |set| set['depositor'] }) : {}
  end

  def show
    @resolver = SetResolver.new(compilation: @set, search_service: search_service)
    @response = contents_response
    @recipe_titles = recipe_titles
  end

  # One set's resolved work tally, fetched lazily by the index table's
  # per-row turbo-frame — full recipe resolution costs several Solr
  # round-trips, so the index never pays it inline.
  def works_count
    @count = SetResolver.new(compilation: @set, search_service: search_service).contents_count
    render layout: false
  end

  # The Add-to-set modal's rows, fetched lazily by a turbo-frame when the
  # modal on a Work/Collection show page first opens — host pages cost no
  # Atlas call until then. Owner-scoped and paginated; each row carries
  # this item's state in that set (addable / already included / set aside).
  def picker
    @kind = params[:collection_id].present? ? 'collection' : 'work'
    @noid = params[:collection_id].presence || params[:work_id]
    return head :bad_request if @noid.blank?

    @q = params[:q].to_s.strip
    @sets, @pagination = SetPicker.call(query: @q, page: params[:page])
    render layout: false
  end

  def new
    @set = AtlasRb::Mash.new
  end

  # Details tab is open to any editor; the Sharing tab is owner/admin-only
  # (gated in the view + on the sharing write path).
  def edit
    prepare_sharing_form if @owned
  end

  def create
    set = AtlasRb::Compilation.create(set_params[:title], description: set_params[:description].presence)
    redirect_to set_path(set['id']), notice: 'Set created.'
  rescue AtlasRb::CompilationError => e
    @set = AtlasRb::Mash.new(set_params)
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_content
  end

  # The Details and Sharing tabs are disjoint forms that both PATCH here,
  # routed on the hidden `set[form]` marker.
  def update
    return update_sharing if params.dig(:set, :form) == 'sharing'

    AtlasRb::Compilation.update(@set['id'], title: set_params[:title], description: set_params[:description])
    redirect_to set_path(@set['id']), notice: 'Set updated.'
  rescue AtlasRb::CompilationError => e
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_content
  end

  # Typeahead JSON for the edit_users picker on the Sharing tab — mirrors
  # MessagesController#recipients. Atlas's directory excludes
  # guest/anonymous/system roles server-side and caps results at 10.
  def recipients
    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    results = AtlasRb::User.search(query, nuid: current_user.nuid)
    render json: results.map { |user| { nuid: user['nuid'], name: NuidResolver.prettify(user['name']) } }
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error("SetsController#recipients: #{e.class} #{e.message}")
    render json: []
  end

  def destroy
    AtlasRb::Compilation.destroy(@set['id'])
    redirect_to sets_path, notice: 'Set deleted. The works and collections it referenced are untouched.'
  end

  # ---- recipe mutations ----------------------------------------------------
  # Adds come from show-page affordances elsewhere in the app, so they return
  # to where the user was; removals and the aside pair live on the Set page.

  def add_collection
    AtlasRb::Compilation.add_included_collection(@set['id'], params[:collection_id])
    redirect_back_or_to(
      set_path(@set['id']),
      notice: "Collection added to “#{@set['title']}”. The set stays current as the collection changes."
    )
  rescue AtlasRb::CompilationError => e
    redirect_back_or_to(set_path(@set['id']), alert: e.message)
  end

  def remove_collection
    AtlasRb::Compilation.remove_included_collection(@set['id'], params[:collection_id])
    redirect_to set_path(@set['id']),
                notice: 'Removed from this set. The collection itself is untouched.'
  end

  def add_work
    AtlasRb::Compilation.add_included_work(@set['id'], params[:work_id])
    redirect_back_or_to(set_path(@set['id']), notice: "Added to “#{@set['title']}”.")
  rescue AtlasRb::CompilationError => e
    redirect_back_or_to(set_path(@set['id']), alert: e.message)
  end

  def remove_work
    AtlasRb::Compilation.remove_included_work(@set['id'], params[:work_id])
    redirect_to set_path(@set['id']), notice: 'Removed from this set. The work itself is untouched.'
  end

  # The teaching moment lives in the redirect: the show render reads
  # flash[:aside] and raises the toast with fresh chip counts and an Undo.
  def set_aside
    AtlasRb::Compilation.add_exclusion(@set['id'], params[:work_id])
    flash[:aside] = { 'work_id' => params[:work_id],
                      'title'   => params[:title],
                      'chip'    => params[:chip].presence }
    redirect_to set_path(@set['id'])
  end

  def put_back
    AtlasRb::Compilation.remove_exclusion(@set['id'], params[:work_id])
    redirect_to set_path(@set['id']), notice: 'Put back into the set.'
  end

  private

    def load_set
      @set = AtlasRb::Compilation.find(params[:id])
      # @owned: owner/admin — gates ownership-only UI (Sharing tab, Delete).
      # @can_edit: owner OR a grantee — gates recipe-mutation affordances.
      # Atlas re-checks every write regardless; these only shape the UI.
      @owned = current_user.present? && (current_user.admin? || @set['depositor'] == current_user.nuid)
      @can_edit = @owned || editor?
    end

    # An edit grant (individual NUID or one of the caller's groups). Group
    # membership is the caller's session groups intersected with edit_groups —
    # the same UI-side check the permissions widget uses (Atlas is the boundary).
    def editor?
      return false unless current_user
      return true if Array(@set['edit_users']).include?(current_user.nuid)

      Array(current_user.groups).intersect?(Array(@set['edit_groups']))
    end

    def require_curator
      return if current_user&.curates_sets?

      render template: 'errors/forbidden', status: :forbidden
    end

    def set_params
      params.expect(set: [:title, :description])
    end

    # ---- sharing (owner/admin-only) -----------------------------------------

    # Pre-fill the Sharing tab from the Set's ACL. The `public` token lives
    # inside read_groups; the group widget shows the real groups (View/Manage),
    # and edit_users renders as resolved-name chips.
    def prepare_sharing_form
      read_groups = Array(@set['read_groups'])
      @public = read_groups.include?('public')
      @groups = Array(current_user&.groups).map { |raw| [raw, pretty_group(raw)] }
      @permissions =
        read_groups.reject { |group| group == 'public' }.map { |group| [group, pretty_group(group), 'View'] } +
        Array(@set['edit_groups']).map { |group| [group, pretty_group(group), 'Manage'] }
      @edit_user_grants = Array(@set['edit_users']).map { |nuid| { nuid: nuid, name: NuidResolver.name_for(nuid) } }
    end

    def update_sharing
      return head :forbidden unless @owned

      before = current_acl
      permissions = build_permissions
      AtlasRb::Compilation.update(@set['id'], permissions: permissions)
      notify_new_grants(before, permissions)
      redirect_to set_path(@set['id']), notice: 'Sharing updated.'
    rescue AtlasRb::CompilationError => e
      flash.now[:alert] = e.message
      prepare_sharing_form
      render :edit, status: :unprocessable_content
    end

    # The ACL replacement sent to Atlas: read/edit group lists (read carries the
    # `public` token when public) plus the individual edit_users NUIDs.
    def build_permissions
      groups = parse_group_permissions(params.dig(:set, :permissions))
      read = groups[:read]
      read << 'public' if params[:mass] == 'public'
      { read: read.uniq, edit: groups[:edit], edit_users: submitted_edit_users }
    end

    # Stacked-input rows (mirrors the object permissions widget): each row is
    # { group_id, ability }; blank rows are skipped.
    def parse_group_permissions(rows)
      acc = { read: [], edit: [] }
      return acc if rows.blank?

      rows.values.each do |row|
        next if row['group_id'].blank? || row['ability'].blank?

        (row['ability'] == 'edit' ? acc[:edit] : acc[:read]) << row['group_id']
      end
      acc.transform_values(&:uniq)
    end

    def submitted_edit_users
      Array(params.dig(:set, :edit_users)).map { |nuid| nuid.to_s.strip }.reject(&:blank?).uniq
    end

    def current_acl
      { read: Array(@set['read_groups']), edit: Array(@set['edit_groups']), edit_users: Array(@set['edit_users']) }
    end

    # An inbox nudge to each newly-added grantee (individuals + groups). Diffed
    # against the prior ACL so re-saving an unchanged share notifies no one.
    # `public` is not a grantee, so it never triggers a message.
    def notify_new_grants(before, after)
      (Array(after[:edit_users]) - Array(before[:edit_users])).each { |nuid| share_message(recipient_nuid: nuid) }
      added_groups = (Array(after[:read]) - Array(before[:read]) - ['public']) +
                     (Array(after[:edit]) - Array(before[:edit]))
      added_groups.uniq.each { |group| share_message(recipient_group: group) }
    end

    def share_message(recipient_nuid: nil, recipient_group: nil)
      sharer = current_user.try(:name).presence || current_user.nuid
      Message.create(
        sender_nuid: attributed_nuid,
        recipient_nuid: recipient_nuid,
        recipient_group: recipient_group,
        subject: 'A set was shared with you',
        body: "#{sharer} shared the set “#{@set['title']}” with you."
      )
    end

    # The recipe fq layered onto a state-seeded builder — find_children's
    # shape. A recipe with no positive clause renders empty (nil fq would
    # otherwise match the whole index).
    def contents_response
      fqs = @resolver.contents_fqs
      return Blacklight::Solr::Response.new({}, {}) if fqs.nil?

      builder = search_service.search_builder.with(search_state).with_filters(*fqs)
      Blacklight.default_index.search(builder)
    end

    # Display digests (title / klass) for every recipe noun, keyed by noid —
    # one batch round-trip. Unresolvable nouns are absent; views fall back to
    # the bare noid.
    def recipe_titles
      noids = Array(@set['included_collections']) +
              Array(@set['included_works']) +
              Array(@set['excluded_works'])
      return {} if noids.empty?

      AtlasRb::Resource.find_many(noids).index_by { |digest| digest['noid'] }
    end
end
