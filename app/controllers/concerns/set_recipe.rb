# frozen_string_literal: true

# Recipe-mutation actions for SetsController — adding/removing included
# collections and works, and the set-aside / put-back exclusion pair. Each is a
# thin POST/DELETE over the atlas_rb Compilation binding. Adds come from
# show-page affordances elsewhere in the app, so they return the user to where
# they were; removals and the aside pair live on the Set page.
module SetRecipe
  extend ActiveSupport::Concern

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
end
