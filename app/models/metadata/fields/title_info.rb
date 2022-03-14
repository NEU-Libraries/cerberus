# frozen_string_literal: true

module Metadata
  module Fields
    class TitleInfo
      include AttrJson::Model

      attr_json :title, :string
      attr_json :subtitle, :string
      attr_json :part_number, :string
      attr_json :part_name, :string
      attr_json :non_sort, :string
    end
  end
end
