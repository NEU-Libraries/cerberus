module Cerberus::ModsExtensions::ETD
  extend ActiveSupport::Concern

  included do
    extend_terminology do |t|
      t.advisor_name_part(:path=>"roleTerm[.='Advisor']/../../mods:namePart", namespace_prefix: 'mods')
      t.advisor_given(:path=>"roleTerm[.='Advisor']/../../mods:namePart", namespace_prefix: 'mods', attributes: { type: 'given' })
      t.advisor_family(:path=>"roleTerm[.='Advisor']/../../mods:namePart", namespace_prefix: 'mods', attributes: { type: 'family' })

      t.committee_member_name_part(:path=>"roleTerm[.='Committee member']/../../mods:namePart", namespace_prefix: 'mods')
      t.committee_member_given(:path=>"roleTerm[.='Committee member']/../../mods:namePart", namespace_prefix: 'mods', attributes: { type: 'given' })
      t.committee_member_family(:path=>"roleTerm[.='Committee member']/../../mods:namePart", namespace_prefix: 'mods', attributes: { type: 'family' })

      t.date_awarded(path: 'originInfo', namespace_prefix: 'mods', attributes: { displayLabel: 'Date Awarded' }){
        t.date_issued(path: 'dateIssued', namespace_prefix: 'mods')
      }
    end
  end

end
