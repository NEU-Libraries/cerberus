# frozen_string_literal: true

# The presenter for Blacklight's own document show page, which /solr_documents/:id
# still reaches even though a Work, Collection or Community has a show page of
# its own.
class EnhancedShowPresenter < Blacklight::ShowPresenter
  include EnhancedHeading
end
