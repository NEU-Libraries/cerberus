# frozen_string_literal: true

class Classification < Enumerations::Base
  value :derivative,            name: 'Derivative'
  value :map,                   name: 'Map'
  value :dataset,               name: 'Dataset'
  value :image,                 name: 'Image'
  value :video,                 name: 'Video'
  value :presentation,          name: 'Presentation'
  value :audio,                 name: 'Audio'
  value :spreadsheet,           name: 'Spreadsheet'
  value :text,                  name: 'Text'
  value :archive,               name: 'Archive'
  value :musical_notation,      name: 'Musical Notation'
  value :descriptive_metadata,  name: 'Descriptive Metadata'
  value :generic,               name: 'File'
end
