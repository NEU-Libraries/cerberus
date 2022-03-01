# frozen_string_literal: true

module Metadata
  module Fields
    class Name
      include AttrJson::Model

      attr_json :name, :string
      attr_json :role, :string
    end
  end
end
