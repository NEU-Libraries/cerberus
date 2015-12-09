module OAI::Provider::Metadata

  # Simple implementation of the Mods metadata format.
  class Mods < Format

    def initialize
      @prefix = 'mods'
      @schema = 'http://www.loc.gov/standards/mods/v3/mods-3-5.xsd'
      @namespace = 'http://www.loc.gov/mods/v3/'
      @element_namespace = 'mods'
    end

  end
end
