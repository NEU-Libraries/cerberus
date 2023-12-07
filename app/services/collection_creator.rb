# frozen_string_literal: true

class CollectionCreator < ApplicationService
  def initialize(parent_id:, mods_xml: nil)
    @parent_id = parent_id
    @mods_xml = mods_xml.nil? ? mods_template : mods_xml
  end

  def call
    create_collection
  end

  private

    def create_collection
      # TODO: Atlas create
    end
end
