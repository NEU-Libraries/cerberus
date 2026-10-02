# frozen_string_literal: true

class SearchExplanation
  # One field's weight for one search word, or for the phrase, named as the
  # dialog names it. See docs/discovery.md ("Why this result?").
  Match = Struct.new(:field, :term, :points, :phrase, keyword_init: true)

  # A class body, not the Struct.new block: a constant assigned in a block
  # lands on SearchExplanation, so Match::LABELS would not exist.
  class Match
    # Solr field → what the page calls it. A field indexed more than one way
    # folds into the name a reader knows, so the table can list "Title" twice; a
    # FORMS note tells the rows apart, and the dialog's legend explains each note.
    LABELS = {
      'title_tsim'                 => 'title',
      'title_stem_tesim'           => 'title',
      'title_plain_tsim'           => 'title',
      'title_variant_tesim'        => 'title',
      'description_tsim'           => 'description',
      'description_stem_tesim'     => 'description',
      'descriptive_keywords_tesim' => 'keywords and subjects',
      'subject_title_tesim'        => 'subjects',
      'name_variant_teim'          => 'creator names',
      'full_text_tesimv'           => 'full text',
      'contents_tesim'             => 'contents',
      'alternate_ids_tsim'         => 'identifier',
      'identifier_tesim'           => 'identifier'
    }.freeze

    # The fields that match something other than the text as written.
    FORMS = {
      'title_stem_tesim'       => :stem_variation,
      'description_stem_tesim' => :stem_variation,
      'title_variant_tesim'    => :alternative_title,
      'title_plain_tsim'       => :plain_text
    }.freeze

    # Each form's note in the table, and its legend entry.
    FORM_NOTES = {
      stem_variation:    ['stem variation', 'Matched once words were cut to their stem, so a plural or another ' \
                                            'ending matches too, such as “whale” for “whales”. ' \
                                            'It counts for less than the word as written.'],
      alternative_title: ['alternative title', 'Matched an alternative, uniform, translated or abbreviated title, ' \
                                               'not the main one.'],
      plain_text:        ['without formatting', 'Matched the title with its subscript and superscript removed, ' \
                                                'so “Bi2Sr2CaCu2O8” finds a title that sets its numbers as subscripts.']
    }.freeze

    def label = LABELS.fetch(field, field)
    def form = FORMS[field]
    def form_note = FORM_NOTES.dig(form, 0)
    def stem_variation? = form == :stem_variation
    def display_term = term.sub(/~\d+\z/, '').delete('"')
  end
end
