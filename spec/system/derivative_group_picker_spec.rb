# frozen_string_literal: true

require 'rails_helper'

# A Sentinel tab's group picker. + adds a group only once one is
# chosen, and the choice lives in a hidden field that only the browser fills, so
# a request spec cannot see whether + added a row, refused, or did nothing.
RSpec.describe 'Sentinel group picker', :browser, type: :system do
  let(:staff) { 'northeastern:drs:repository:staff' }

  before(:all) do
    Current.nuid = admin_nuid
    @collection = create_collection(create_community(public: true).id, public: true)
  end

  before do
    Group.create!(raw: staff, cosmetic: 'DRS Staff')
    Group.create!(raw: 'northeastern:drs:library:archives', cosmetic: 'Archives')
    sign_in_as(admin_nuid)
    visit "#{edit_collection_path(@collection.id)}#sentinel"
    find('#small-restrict').choose
  end

  it 'adds a group typed out in full, without a pick' do
    type_group(staff)
    press_add

    expect(tier_rows).to have_css('.js-label', exact_text: 'DRS Staff')
    expect(tier_rows.find('.js-field', visible: :all).value).to eq(staff)
  end

  it 'saves a group typed out in full without pressing +' do
    type_group('drs staff')

    expect(tier.find('.js-group-id', visible: :all).value).to eq(staff)
  end

  it 'says to pick from the list when nothing matches' do
    type_group('northeastern:drs:repo')
    press_add

    expect(tier).to have_css('.js-group-error', text: 'Pick a group from the list.')
    expect(query_field[:class]).to include('is-invalid')
    expect(tier_rows).to have_no_css('.derivative-tier__row')
  end

  it 'says the tier already has a group added twice' do
    2.times do
      type_group(staff)
      press_add
    end

    expect(tier).to have_css('.js-group-error', text: 'This tier already has that group.')
    expect(tier_rows).to have_css('.derivative-tier__row', count: 1)
  end

  it 'clears the message once the curator types again' do
    type_group('nothing like a group')
    press_add
    expect(tier).to have_css('.js-group-error', text: 'Pick a group from the list.')

    type_group('Arch')

    expect(tier).to have_no_css('.js-group-error', text: /\S/)
    expect(tier).to have_no_css('.js-group-query.is-invalid')
  end

  # --- helpers ---------------------------------------------------------------

  # The entry field and + are labelled by aria-label alone, which Capybara's
  # field and button locators skip, so they are found within the tier.
  def tier = find('#small-restrict').ancestor('.derivative-tier')
  def tier_rows = tier.find('.derivative-tier__rows')
  def query_field = tier.find('.js-group-query')
  def type_group(text) = query_field.fill_in(with: text)
  def press_add = tier.find('.derivative-tier__entry .btn-success').click
end
