# frozen_string_literal: true

# Recipe-mutation actions for SetsController — adding/removing included
# collections and works, and the set-aside / put-back exclusion pair. Each is a
# thin POST/DELETE over the atlas_rb Compilation binding. Adds come from
# show-page affordances elsewhere in the app, so they return the user to where
# they were. Removals live on the Manage page's Set definition tab and return
# there; set-aside lives on the Set page, and put-back serves both.
module SetRecipe
  extend ActiveSupport::Concern

  def add_collection
    AtlasRb::Compilation.add_included_collection(@set['id'], params[:collection_id])
    redirect_back_or_to(
      set_path(@set['id']),
      notice: "Collection added to “#{@set['title']}”. " \
              "Any new works added to the collection will also be added to “#{@set['title']}”."
    )
  rescue AtlasRb::CompilationError => e
    redirect_back_or_to(set_path(@set['id']), alert: e.message)
  end

  def remove_collection
    AtlasRb::Compilation.remove_included_collection(@set['id'], params[:collection_id])
    redirect_to set_definition_path,
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
    redirect_to set_definition_path, notice: 'Removed from this set. The work itself is untouched.'
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

  # The show page's Hide toast offers Undo through here too, and must return
  # to the set rather than to Manage.
  def put_back
    AtlasRb::Compilation.remove_exclusion(@set['id'], params[:work_id])
    back = params[:return_to] == 'manage' ? set_definition_path : set_path(@set['id'])
    redirect_to back, notice: 'Put back into the set.'
  end

  private

    # The Manage page's Set definition tab. Every action that renders :edit
    # calls this, a refused save included, or the tab has nothing to draw.
    def prepare_set_definition
      @resolver = SetResolver.new(compilation: @set, search_service: search_service)
      @recipe_titles = recipe_titles
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

    # A query param, not a fragment: Turbo follows the redirect with fetch,
    # which drops the fragment, and the edit page opens the tab named by ?tab=.
    def set_definition_path
      edit_set_path(@set['id'], tab: 'definition')
    end
end
