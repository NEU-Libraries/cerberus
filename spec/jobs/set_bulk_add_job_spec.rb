# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SetBulkAddJob do
  let(:actor) { '000000002' }

  before do
    allow(AtlasRb::Compilation).to receive(:find).with('set-1')
                                                 .and_return(AtlasRb::Mash.new('id' => 'set-1', 'title' => 'Field Notes'))
    allow(AtlasRb::Compilation).to receive(:add_included_work)
  end

  def run(work_ids)
    Current.set(nuid: actor) { described_class.perform_now(set_noid: 'set-1', work_ids: work_ids) }
  end

  def message
    Message.where(recipient_nuid: actor).order(:created_at).last
  end

  it 'adds each work to the set' do
    run(%w[w-1 w-2])
    expect(AtlasRb::Compilation).to have_received(:add_included_work).with('set-1', 'w-1')
    expect(AtlasRb::Compilation).to have_received(:add_included_work).with('set-1', 'w-2')
  end

  it 'tells whoever asked, with a link to the set' do
    run(%w[w-1 w-2])
    expect(message.subject).to eq('Added 2 works to “Field Notes”')
    expect(message.body).to include('2 works from a page of search results are now in “Field Notes”.', '/sets/set-1')
  end

  # One refused work must not stop the rest, and must be named.
  it 'carries on past a refused work and lists it' do
    allow(AtlasRb::Compilation).to receive(:add_included_work).with('set-1', 'w-2')
                                                              .and_raise(AtlasRb::CompilationError, 'not found')
    run(%w[w-1 w-2 w-3])
    expect(AtlasRb::Compilation).to have_received(:add_included_work).with('set-1', 'w-3')
    expect(message.subject).to eq('Added 2 of 3 works to “Field Notes”')
    expect(message.body).to include('These could not be added:', 'Work w-2: not found')
  end

  it 'does nothing when the set is gone' do
    allow(AtlasRb::Compilation).to receive(:find).with('set-1').and_return(nil)
    expect { run(%w[w-1]) }.not_to(change(Message, :count))
    expect(AtlasRb::Compilation).not_to have_received(:add_included_work)
  end
end
