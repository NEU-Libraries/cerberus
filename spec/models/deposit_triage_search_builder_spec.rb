# frozen_string_literal: true

require 'rails_helper'

# The builder's whole job is to undo an inherited exclusion, so the fq it produces
# is the thing worth asserting: a clause left in place makes the list silently
# empty, which looks identical to "nothing needs triage".
RSpec.describe DepositTriageSearchBuilder do
  let(:scope) do
    double('scope', blacklight_config: CatalogController.blacklight_config,
                    current_user:      User.new(nuid: '000000004', role: 'admin'))
  end

  def fq_for(state, starting_with: [])
    params = { fq: starting_with.dup }
    described_class.new(scope).state(state).only_stuck_deposits(params)
    params[:fq]
  end

  it 'scopes to Works and to the unconfirmed state' do
    expect(fq_for(:unconfirmed)).to include('internal_resource_tesim:Work', 'in_progress_bsi:true')
  end

  # An unconfirmed deposit needs finishing before anybody looks at its renditions,
  # so it belongs on the other list only.
  it 'excludes unconfirmed deposits from the incomplete list' do
    expect(fq_for(:incomplete)).to include('incomplete_bsi:true', '-in_progress_bsi:true')
  end

  # SearchBuilder#exclude_unfinished_deposits adds this for anyone who is not staff
  # or an admin. Left in place it would contradict the inclusion and return nothing.
  it 'drops the inherited unfinished-deposit exclusion' do
    inherited = ['-in_progress_bsi:true', '-tombstoned_bsi:true']

    expect(fq_for(:unconfirmed, starting_with: inherited)).not_to include('-in_progress_bsi:true')
  end

  # A depositor-scoped variant of the same exclusion, which the OR form produces
  # for a signed-in reader. Also has to go, and a plain equality reject misses it.
  it 'drops the depositor-exempt form of that exclusion too' do
    inherited = ['((*:* -in_progress_bsi:true) OR depositor_ssi:000000015)']

    expect(fq_for(:unconfirmed, starting_with: inherited).grep(/OR depositor_ssi/)).to be_empty
  end

  it 'leaves the tombstone exclusion alone — a withdrawn deposit needs no triage' do
    expect(fq_for(:unconfirmed, starting_with: ['-tombstoned_bsi:true']))
      .to include('-tombstoned_bsi:true')
  end
end
