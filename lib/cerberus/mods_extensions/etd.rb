module Cerberus::ModsExtensions::ETD
  extend ActiveSupport::Concern

  included do
    extend_terminology do |t|
      t.advisor(path: "mods/mods:name[mods:role[mods:roleTerm[.='Advisor']]]", namespace_prefix: 'mods'){
        t.name_part(:path=>"namePart", namespace_prefix: 'mods')
        t.name_part_given(:path=>"namePart", namespace_prefix: 'mods', attributes: { type: 'given' })
        t.name_part_family(:path=>"namePart", namespace_prefix: 'mods', attributes: { type: 'family' })
      }

      t.committee_member(path: "mods/mods:name[mods:role[mods:roleTerm[.='Committee member']]]", namespace_prefix: 'mods'){
        t.name_part(:path=>"namePart", namespace_prefix: 'mods')
        t.name_part_given(:path=>"namePart", namespace_prefix: 'mods', attributes: { type: 'given' })
        t.name_part_family(:path=>"namePart", namespace_prefix: 'mods', attributes: { type: 'family' })
      }

      t.date_awarded(path: 'originInfo', namespace_prefix: 'mods', attributes: { displayLabel: 'Date Awarded' }){
        t.date_issued(path: 'dateIssued', namespace_prefix: 'mods')
      }
    end
  end

end
