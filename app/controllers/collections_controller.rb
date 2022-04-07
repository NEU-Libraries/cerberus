# frozen_string_literal: true

class CollectionsController < ApplicationController
  def show
    @collection = Collection.find(params[:id])
  end
end
