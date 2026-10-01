# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_tombstone_modal.html.haml', type: :view do
  let(:targets) do
    instance_double(TombstoneTargets, counts:      { 'Work' => 412, 'Collection' => 3, 'Community' => 0 },
                                      over_limit?: false)
  end

  # A controller helper_method the bare view context lacks, so verifying
  # partial doubles refuse a stub; define the real method instead.
  before { view.define_singleton_method(:chooses_removal_reason?) { true } }

  def render_modal(**locals)
    render partial: 'shared/tombstone_modal', locals: { id: 'c1', kind: 'collection', path: '/collections/c1/tombstone',
                                                         **locals }
  end

  it 'asks the plain question when nothing is cascaded' do
    render_modal

    expect(rendered).to include('Are you sure you want to delete this', '>Delete<')
    expect(rendered).not_to include('confirm_title')
  end

  context 'with a cascade' do
    it 'counts what it withdraws, warns there is no one-step restore, and asks for the title' do
      render_modal(cascade: targets, title: 'Working <sup>2</sup>  Papers')

      expect(rendered).to include('412 works and 3 collections', 'There is no one-step restore',
                                  'name="confirm_title"', 'name="cascade"',
                                  'Delete this collection and everything in it')
      # The title to type is plain text: nobody types the markup.
      expect(rendered).to include('data-confirm-title-expected-value="Working 2 Papers"')
      expect(rendered).not_to include('0 communities')
    end

    it 'offers nothing to confirm over the limit' do
      allow(targets).to receive(:over_limit?).and_return(true)

      render_modal(cascade: targets, title: 'Working Papers')

      expect(rendered).to include('Ask the development team to delete this collection')
      expect(rendered).not_to include('name="confirm_title"', 'type="submit"')
    end
  end
end
