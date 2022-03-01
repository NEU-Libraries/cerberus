# frozen_string_literal: true

module Metadata
  module Fields
    class TitleInfo
      include AttrJson::Model

      attr_json :title, :string
      attr_json :subtitle, :string
      attr_json :partNumber, :string
      attr_json :partName, :string
      attr_json :nonSort, :string
    end
  end
end
