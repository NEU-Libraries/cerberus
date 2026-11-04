# frozen_string_literal: true

module Cerberus
  # Blacklight's dropdown toggle, carrying a popper config. Bootstrap reads the
  # config from the toggle, not the menu.
  class ResultsDropdownButtonComponent < Blacklight::System::DropdownButtonComponent
    def initialize(popper:, **)
      super(**)
      @popper = popper
    end

    def call
      button_tag class: @classes, aria: { expanded: false },
                 data: { toggle: 'dropdown', 'bs-toggle': 'dropdown', 'bs-popper-config': @popper.to_json } do
        safe_join([@label, content_tag(:span, '', class: 'caret')])
      end
    end
  end
end
