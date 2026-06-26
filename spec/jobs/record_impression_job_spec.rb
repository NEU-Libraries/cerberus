# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RecordImpressionJob do
  let(:request_meta) do
    { session_id: 's1', ip_address: '10.0.0.1', referrer: 'direct',
      user_agent: 'Mozilla/5.0' }
  end

  it 'records a view impression for a direct noid and upserts the UA' do
    expect { described_class.perform_now(action: 'view', noid: 'w1', request_meta:) }
      .to change { Impression.where(noid: 'w1', action: 'view').count }.by(1)
      .and change { UserAgent.where(ua_string: 'Mozilla/5.0').count }.by(1)
  end

  it 'resolves the containing work from a blob for a download' do
    allow(AtlasRb::Blob).to receive(:work).with('b1').and_return('w-parent')

    expect { described_class.perform_now(action: 'download', blob_id: 'b1', request_meta:) }
      .to change { Impression.where(noid: 'w-parent', action: 'download').count }.by(1)
  end

  it 'records nothing when the blob has no resolvable work' do
    allow(AtlasRb::Blob).to receive(:work).with('orphan').and_return(nil)

    expect { described_class.perform_now(action: 'download', blob_id: 'orphan', request_meta:) }
      .not_to change(Impression, :count)
  end

  it 'is a benign no-op when the throttle rejects a duplicate' do
    described_class.perform_now(action: 'view', noid: 'w1', request_meta:)

    expect { described_class.perform_now(action: 'view', noid: 'w1', request_meta:) }
      .not_to change(Impression, :count)
  end
end
