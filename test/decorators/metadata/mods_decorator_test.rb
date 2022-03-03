# frozen_string_literal: true

require 'test_helper'

module Metadata
  class ModsDecoratorTest < ActiveSupport::TestCase
    def setup
      @mods = Metadata::Mods.new.extend Metadata::ModsDecorator
    end

    # test "the truth" do
    #   assert true
    # end
  end
end
