# frozen_string_literal: true

require 'rdf'
module Cerberus
  module Vocab
    # @!parse
    #   # Vocabulary for <http://pcdm.org/use#>
    #   class PCDMUse < RDF::Vocabulary
    #   end
    class PCDMUse < RDF::Vocabulary('http://pcdm.org/use#')
      # Ontology definition
      ontology :'http://pcdm.org/use#',
               comment: %(Ontology for a PCDM extension to add subclasses of PCDM File for the
               different roles files have in relation to the Object they are attached to.),
               'dc:modified': %(2015-05-12),
               'dc:publisher': %(http://www.duraspace.org/),
               'dc:title': %(Portland Common Data Model: Use Extension),
               'owl:versionInfo': %(2015/05/12),
               'rdfs:seeAlso': [%(https://github.com/duraspace/pcdm/wiki), %(https://wiki.duraspace.org/display/hydra/File+Use+Vocabulary)]

      # Class definitions
      term :MetadataFile,
           comment: %(The file that represents metadata for a Work, Collection or Community. Typically MODS.),
           label: 'metadata file',
           'rdf:subClassOf': %(http://pcdm.org/resources#File),
           'rdfs:isDefinedBy': %(pcdmuse:),
           type: 'rdfs:Class'
    end
  end
end
