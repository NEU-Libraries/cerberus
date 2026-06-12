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
  before_action :load_set,           except: [:index, :new, :create, :picker]

  # A private Set read (or any write) the caller may not perform: Atlas says
  # 403, the user sees the standard forbidden page. Unknown ids surface as
  # JSON::ParserError → Authorizable's 404 path.
  rescue_from AtlasRb::ForbiddenError do
    render template: 'errors/forbidden', status: :forbidden
  end

  def index
    page = AtlasRb::Compilation.list(page: params[:page].presence)
    # Unlike .find/.create, .list entries arrive wrapped: {"compilation" => {...}}.
    @sets = Array(page['compilations']).pluck('compilation')
    @pagination = page['pagination']
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

  def edit; end

  def create
    set = AtlasRb::Compilation.create(set_params[:title], description: set_params[:description].presence)
    redirect_to set_path(set['id']), notice: 'Set created.'
  rescue AtlasRb::CompilationError => e
    @set = AtlasRb::Mash.new(set_params)
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_content
  end

  def update
    AtlasRb::Compilation.update(@set['id'], title: set_params[:title], description: set_params[:description])
    redirect_to set_path(@set['id']), notice: 'Set updated.'
  rescue AtlasRb::CompilationError => e
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_content
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
      # Manage affordances are owner/admin UI; Atlas re-checks every write.
      @owned = current_user.present? && (current_user.admin? || @set['depositor'] == current_user.nuid)
    end

    def require_curator
      return if current_user&.curates_sets?

      render template: 'errors/forbidden', status: :forbidden
    end

    def set_params
      params.expect(set: [:title, :description])
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
