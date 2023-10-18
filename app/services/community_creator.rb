# frozen_string_literal: true

class CommunityCreator < ApplicationService
  def initialize(parent_id: nil, mods_xml: nil)
    @parent_id = parent_id
    @mods_xml = mods_xml.nil? ? mods_template : mods_xml
  end

  def call
    create_community
  end

  private

    def create_community
      # TODO: Atlas create
    end
end
