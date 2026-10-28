# frozen_string_literal: true

# Finds the Works in one fixity state, for the admin fixity report. Reads the
# per-Work rollup Atlas indexes over the objects each Work owns, because the
# catalog hides FileSet and Blob documents. See docs/fixity.md.
#
# The three states are disjoint, so a Work appears on one list only. The
# rollup fields are absent, not empty, when nothing is recorded, so "never"
# and the unchecked half of "overdue" are negated existence queries.
class FixitySearchBuilder < SearchBuilder
  # Day-rounded so the filter caches for the day rather than per request.
  OVERDUE_BEFORE = 'NOW/DAY-12MONTHS'

  STATES = {
    failed:  ['work_fixity_result_ssi:fail'],
    overdue: ['work_fixity_result_ssi:pass',
              "(work_fixity_checked_at_dtsi:[* TO #{OVERDUE_BEFORE}] OR (*:* -work_fixity_checked_at_dtsi:[* TO *]))"],
    never:   ['-work_fixity_result_ssi:[* TO *]']
  }.freeze

  self.default_processor_chain += [:only_fixity_state]

  def state(name)
    @state = name.to_sym
    params_will_change!
    self
  end

  def only_fixity_state(solr_parameters)
    solr_parameters[:fq] = Array(solr_parameters[:fq])
    solr_parameters[:fq] << 'internal_resource_tesim:Work'
    solr_parameters[:fq].concat(STATES.fetch(@state))
  end
end
