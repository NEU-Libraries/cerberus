# frozen_string_literal: true

# The single "is this Work currently withheld by embargo" test — shared by the
# Downloads authorization gate, the show-page banner, the search-result
# "Embargoed" pill, and the Google Scholar citation_pdf_url suppression. A
# date that fails to parse (blank, malformed) reads as not embargoed rather
# than raising, since callers hold this as a plain permissions string from
# Atlas with no format guarantee.
module Embargo
  def self.active?(date)
    !!release_date(date)&.future?
  end

  def self.release_date(date)
    Date.parse(date.to_s)
  rescue Date::Error, TypeError
    nil
  end
end
