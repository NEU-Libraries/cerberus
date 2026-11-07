# frozen_string_literal: true

module Cerberus
  # The Sort and Per-page menus under the facets open to the right, over the
  # results. See docs/design.md.
  #
  # The template renders ResultsDropdownButtonComponent itself rather than the
  # inherited button slot: the slot is fixed to Blacklight's button, which
  # cannot carry the popper config.
  class ResultsDropdownComponent < Blacklight::System::DropdownComponent
    # Where the right has no room, as on a phone, the menu drops below instead
    # of flipping left off the screen. This config replaces Bootstrap's
    # modifiers wholesale, so the offset (the arrow's gap) has to live here too.
    POPPER = { modifiers: [{ name: 'preventOverflow', options: { boundary: 'clippingParents', padding: 16 } },
                           { name: 'offset', options: { offset: [0, 16] } },
                           { name: 'flip', options: { fallbackPlacements: ['bottom-start'] } }] }.freeze

    def initialize(**)
      super
      @classes.push('dropend')
    end
  end
end
