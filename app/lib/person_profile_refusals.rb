# frozen_string_literal: true

# Atlas's 422 codes on a Person profile write, in the editor's terms. Shared by
# the self-edit form and the admin form, which save the same three fields.
module PersonProfileRefusals
  MESSAGES = {
    'blank_display_name' => 'Enter a display name.',
    'invalid_bio'        => 'Shorten the bio to 4,000 characters or fewer.',
    'invalid_orcid'      => 'Enter the ORCID iD as four groups of four, such as 0000-0002-1825-0097.'
  }.freeze

  GENERIC = 'Atlas refused those details, so nothing was saved.'

  def self.message(error)
    MESSAGES.fetch(code(error), GENERIC)
  end

  def self.code(error)
    JSON.parse(error.body.to_s)['error']
  rescue JSON::ParserError, TypeError
    nil
  end
end
