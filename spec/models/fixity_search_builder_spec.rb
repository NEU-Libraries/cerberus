# frozen_string_literal: true

require 'rails_helper'

# The suite cannot record a check (only Atlas's checker principal may post
# one), so the failed and overdue lists are asserted at the fq they produce.
RSpec.describe FixitySearchBuilder do
  let(:scope) do
    double('scope', blacklight_config: CatalogController.blacklight_config,
                    current_user:      User.new(nuid: '000000004', role: 'admin'))
  end

  def fq_for(state)
    params = { fq: [] }
    described_class.new(scope).state(state).only_fixity_state(params)
    params[:fq]
  end

  it 'scopes every list to Works, which alone carry the rollup' do
    described_class::STATES.each_key do |state|
      expect(fq_for(state)).to include('internal_resource_tesim:Work')
    end
  end

  it 'lists a recorded fail' do
    expect(fq_for(:failed)).to include('work_fixity_result_ssi:fail')
  end

  # Without the pass clause a failed Work would sit on two lists, and a never
  # checked one too, through the absent-date half.
  it 'keeps overdue to passed Works, so the three lists are disjoint' do
    expect(fq_for(:overdue)).to include('work_fixity_result_ssi:pass')
  end

  # Atlas leaves the date absent while any object is unchecked, so a range
  # query alone would miss a partly checked Work for ever.
  it 'counts a partly checked Work as overdue' do
    expect(fq_for(:overdue).last).to include('(*:* -work_fixity_checked_at_dtsi:[* TO *])',
                                             'work_fixity_checked_at_dtsi:[* TO NOW/DAY-12MONTHS]')
  end

  it 'finds a Work with nothing recorded by the absent result' do
    expect(fq_for(:never)).to include('-work_fixity_result_ssi:[* TO *]')
  end
end
