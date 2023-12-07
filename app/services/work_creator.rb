# frozen_string_literal: true

class WorkCreator < ApplicationService
  def initialize(parent_id:, mods_xml: nil)
    @parent_id = parent_id
    @mods_xml = mods_xml.nil? ? mods_template : mods_xml
  end

  def call
    create_work
  end

  private

    def create_work
      # TODO: Atlas create
    end
end
