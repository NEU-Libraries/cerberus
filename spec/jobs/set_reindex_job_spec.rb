# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SetReindexJob do
  let(:actor) { '000000004' }

  def compilation(collections: [], works: [], title: 'Reading list')
    AtlasRb::Mash.new('id' => 'set123', 'title' => title,
                      'included_collections' => collections, 'included_works' => works)
  end

  def ok_response
    instance_double(Faraday::Response, status: 204)
  end

  def run(set_noid: 'set123')
    Current.set(nuid: actor) { described_class.perform_now(set_noid) }
  end

  describe 'walking the recipe' do
    it 'drives a subtree call per included collection and a single call per added work' do
      allow(AtlasRb::Compilation).to receive(:find).and_return(compilation(collections: %w[c1 c2], works: %w[w1]))
      allow(AtlasRb::System).to receive(:reindex_subtree).and_return(10, 5)
      allow(AtlasRb::System).to receive(:reindex).and_return(ok_response)

      run

      expect(AtlasRb::System).to have_received(:reindex_subtree).with('c1')
      expect(AtlasRb::System).to have_received(:reindex_subtree).with('c2')
      expect(AtlasRb::System).to have_received(:reindex).with('w1')
      expect(Message.last.body).to include('16 resources reindexed')
    end

    it 're-reads the recipe at run time rather than trusting the enqueue' do
      allow(AtlasRb::Compilation).to receive(:find).with('set123').and_return(compilation)

      run

      expect(AtlasRb::Compilation).to have_received(:find).with('set123')
    end

    it 'does nothing for a set that has gone away' do
      allow(AtlasRb::Compilation).to receive(:find).and_return(nil)

      expect { run }.not_to change(Message, :count)
    end
  end

  describe 'partial failure' do
    # One unreachable branch must not abandon the rest of the recipe, and a
    # branch that failed is still stale — so it is named, not counted.
    it 'carries on past a failed collection and names it' do
      allow(AtlasRb::Compilation).to receive(:find).and_return(compilation(collections: %w[c1 c2]))
      allow(AtlasRb::System).to receive(:reindex_subtree).with('c1').and_raise(Faraday::ConnectionFailed, 'refused')
      allow(AtlasRb::System).to receive(:reindex_subtree).with('c2').and_return(4)

      run

      expect(AtlasRb::System).to have_received(:reindex_subtree).with('c2')
      expect(Message.last.subject).to eq('Set reindex finished with problems')
      expect(Message.last.body).to include('Collection c1')
    end

    # atlas_rb does not translate a 404 on the subtree path; the empty body
    # arrives as a parse error, which must not read as a crash.
    it 'reads an unparseable subtree response as a missing resource' do
      allow(AtlasRb::Compilation).to receive(:find).and_return(compilation(collections: %w[gone]))
      allow(AtlasRb::System).to receive(:reindex_subtree).and_raise(JSON::ParserError)

      run

      expect(Message.last.body).to include('no resource found')
    end

    it 'names a work Atlas refused' do
      allow(AtlasRb::Compilation).to receive(:find).and_return(compilation(works: %w[w1]))
      allow(AtlasRb::System).to receive(:reindex).and_return(instance_double(Faraday::Response, status: 404))

      run

      expect(Message.last.body).to include('Work w1')
    end

    # A timeout is transient and the walk is idempotent, so it must escape the
    # per-item rescue to retry_on rather than be recorded as a permanent
    # failure. The tell is that the run re-enqueues and reports nothing —
    # telling someone a branch failed when it is about to be retried would
    # send them chasing a problem that fixes itself.
    it 'retries a timeout instead of reporting it as a failure' do
      allow(AtlasRb::Compilation).to receive(:find).and_return(compilation(collections: %w[c1]))
      allow(AtlasRb::System).to receive(:reindex_subtree).and_raise(Faraday::TimeoutError)

      expect { run }.to have_enqueued_job(described_class)
      expect(Message.count).to eq(0)
    end
  end

  describe 'the report' do
    it 'sends the actor exactly one message, naming the set and linking to it' do
      allow(AtlasRb::Compilation).to receive(:find).and_return(compilation(collections: %w[c1]))
      allow(AtlasRb::System).to receive(:reindex_subtree).and_return(1)

      expect { run }.to change(Message, :count).by(1)

      message = Message.last
      expect(message.recipient_nuid).to eq(actor)
      expect(message.subject).to eq('Set reindex finished')
      expect(message.body).to include('Reading list', '1 resource reindexed',
                                      Rails.application.routes.url_helpers.set_path('set123'))
    end

    it 'stays silent when there is no actor to tell' do
      allow(AtlasRb::Compilation).to receive(:find).and_return(compilation)

      expect { Current.set(nuid: nil) { described_class.perform_now('set123') } }
        .not_to change(Message, :count)
    end
  end
end
