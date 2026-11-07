# frozen_string_literal: true

module Cerberus
  # Blacklight's applied-constraints row, plus one chip for an empty search on a
  # collection or community page ("Everything in this collection"). A blank q
  # is no constraint to Blacklight, so without the chip the page would list the
  # whole tree with nothing to say so and no way back to the one-level view.
  # Its remove link is the keyword chip's: the state without q.
  class ConstraintsComponent < Blacklight::ConstraintsComponent
    def initialize(whole_tree_label: nil, **)
      super(**)
      @whole_tree_label = whole_tree_label
    end

    def render?
      super || @whole_tree_label.present?
    end

    def query_constraints
      return super if @whole_tree_label.blank? || @search_state.query_param.present?

      render(
        @query_constraint_component.new(
          search_state: @search_state, value: @whole_tree_label, remove_path: remove_path,
          classes: 'query whole-tree', **@query_constraint_component_options
        )
      ) + super
    end
  end
end
