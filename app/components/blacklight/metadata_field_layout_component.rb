# frozen_string_literal: true

module Blacklight
  class MetadataFieldLayoutComponent < ViewComponent::Base
    with_collection_parameter :field
    renders_one :label
    # `index` is the value's position within the field, which Blacklight sends
    # so a layout can indent every value after the first. This layout does not
    # indent — the template gives each value its own full-width row — so the
    # argument is accepted and dropped. It must stay in the signature: the
    # caller always sends it, and an unknown keyword raises.
    renders_many :values, (lambda do |value: nil, index: nil, &block| # rubocop:disable Lint/UnusedBlockArgument
      if @value_tag.nil?
        block&.call || value
      elsif block
        content_tag @value_tag, class: "#{@value_class} blacklight-#{@key}", &block
      else
        content_tag @value_tag, value, class: "#{@value_class} blacklight-#{@key}"
      end
    end)

    # @param field [Blacklight::FieldPresenter]
    def initialize(field:, value_tag: nil, label_class: 'col text-start', value_class: 'col-md-10')
      @field = field
      @key = @field.key.parameterize
      @label_class = label_class
      @value_tag = value_tag
      @value_class = value_class
    end
  end
end
