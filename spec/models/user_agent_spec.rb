# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAgent do
  describe '.bot?' do
    it 'flags a UA containing a configured substring, case-insensitively' do
      expect(described_class.bot?('Googlebot/2.1')).to be(true)        # 'bot'
      expect(described_class.bot?('x LIGHTHOUSE y')).to be(true)       # 'lighthouse'
      expect(described_class.bot?('curl/8.4.0')).to be(true) # 'curl'
    end

    it 'treats an ordinary browser UA as human' do
      expect(described_class.bot?('Mozilla/5.0 (Macintosh) AppleWebKit Safari/605'))
        .to be(false)
    end

    it 'is false for a blank UA' do
      expect(described_class.bot?(nil)).to be(false)
      expect(described_class.bot?('')).to be(false)
    end
  end

  describe '.record' do
    it 'records a distinct UA once with its derived verdict' do
      expect { described_class.record('Googlebot/2.1') }
        .to change(described_class, :count).by(1)

      row = described_class.find('Googlebot/2.1')
      expect(row.is_bot).to be(true)
      expect(row.classified_at).to be_present
    end

    it 'classifies a human UA as not a bot' do
      described_class.record('Mozilla/5.0')
      expect(described_class.find('Mozilla/5.0').is_bot).to be(false)
    end

    it 'is idempotent on a second sighting' do
      described_class.record('Mozilla/5.0')
      expect { described_class.record('Mozilla/5.0') }
        .not_to change(described_class, :count)
    end

    it 'ignores a blank UA' do
      expect { described_class.record(nil) }.not_to change(described_class, :count)
    end
  end
end
