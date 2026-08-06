# frozen_string_literal: true

# Finds the Works in one of the two states a deposit can get stuck in, for the
# admin triage registry. Same shape as TombstonedSearchBuilder: a final processor
# step that undoes an inherited exclusion so the surface can list exactly what
# ordinary discovery hides.
#
# The exclusion it has to undo is SearchBuilder#exclude_unfinished_deposits. That
# step exempts admins and repository staff, so in practice this builder is driven
# by somebody it never applied to — but relying on that would make the builder
# correct by luck. Dropping the clause outright keeps it correct whoever drives it.
#
# `-tombstoned_bsi:true` is deliberately left in place: a withdrawn deposit needs
# no triage, and the tombstone registry is where it belongs.
class DepositTriageSearchBuilder < SearchBuilder
  # in_progress: nobody has confirmed the deposit — it is waiting on a person.
  # incomplete: it finished, but an enrichment job gave up — it is waiting on
  # repair. The two are mutually exclusive here so a Work appears on one list
  # only, and on the one whose action is the next thing that has to happen.
  STATES = {
    unconfirmed: ['in_progress_bsi:true'],
    incomplete:  ['incomplete_bsi:true', '-in_progress_bsi:true']
  }.freeze

  self.default_processor_chain += [:only_stuck_deposits]

  def state(name)
    @state = name.to_sym
    params_will_change!
    self
  end

  def only_stuck_deposits(solr_parameters)
    solr_parameters[:fq] = Array(solr_parameters[:fq]).reject { |f| f.include?('in_progress_bsi') }
    solr_parameters[:fq] << 'internal_resource_tesim:Work'
    solr_parameters[:fq].concat(STATES.fetch(@state))
  end
end
