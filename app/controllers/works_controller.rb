# frozen_string_literal: true

class WorksController < ApplicationController
  def show
    # lookup Metadata::Mods object with noid
    x = Metadata::Mods.find(5)
  end
end
