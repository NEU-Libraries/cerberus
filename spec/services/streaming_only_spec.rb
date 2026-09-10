# frozen_string_literal: true

require 'rails_helper'

# Unit-level: the tier arithmetic and the read-merge-write, with Atlas stubbed.
# The browser-facing consequences (no download row, no link under the player,
# nothing in a zip) are specced where they are enforced.
RSpec.describe StreamingOnly do
  let(:admin_group) { Permissions::ADMIN_GROUP }

  describe '.audience_for' do
    it 'names the admin group on a public work' do
      expect(described_class.audience_for(['public'])).to eq([admin_group])
    end

    # Atlas refuses a tier more visible than its Work, so naming a group the Work
    # does not grant would be rejected outright rather than restricting anything.
    it 'collapses to a private tier on a work that does not grant the admin group' do
      expect(described_class.audience_for(['editors'])).to eq([])
    end

    it 'keeps the admin group when the work itself grants it' do
      expect(described_class.audience_for(['editors', admin_group])).to eq([admin_group])
    end

    it 'treats a work with no read audience as private' do
      expect(described_class.audience_for(nil)).to eq([])
    end
  end

  describe '.on?' do
    it 'is true for a video tier matching what this feature writes' do
      expect(described_class.on?({ 'video' => [admin_group] }, read: ['public'])).to be(true)
    end

    it 'is false when no video tier is stored' do
      expect(described_class.on?({ 'large' => ['public'] }, read: ['public'])).to be(false)
    end

    # A video tier set by something else — a collection's Sentinel default, say —
    # must read as "off", so that turning the toggle off can never quietly widen
    # a restriction this feature did not impose.
    it 'is false for a video tier restricted to some other audience' do
      expect(described_class.on?({ 'video' => ['northeastern:drs:repository:archives'] },
                                 read: ['public'])).to be(false)
    end
  end

  describe '.applicable?' do
    def asset(mime, uri: nil)
      AtlasRb::Mash.new('noid' => 'n1', 'mime_type' => mime, 'uri' => uri)
    end

    it 'is true for a work carrying a video blob' do
      expect(described_class.applicable?([asset('application/pdf'), asset('video/mp4')])).to be(true)
    end

    it 'is true for a deposited master that is not yet browser-playable' do
      expect(described_class.applicable?([asset('video/quicktime')])).to be(true)
    end

    it 'is false for audio, which the toggle does not cover' do
      expect(described_class.applicable?([asset('audio/mpeg')])).to be(false)
    end

    # Image tiers are Delegates and carry a uri; they are not the Work's content.
    it 'ignores uri-backed delegates' do
      expect(described_class.applicable?([asset('video/mp4', uri: 'https://iiif/x')])).to be(false)
    end
  end

  describe '.apply!' do
    before { allow(AtlasRb::Work).to receive(:set_derivative_permissions) }

    def stub_policy(policy)
      allow(AtlasRb::Work).to receive(:find).and_return(AtlasRb::Mash.new('derivative_permissions' => policy))
    end

    # The Atlas write is a whole-object replace, so anything not read back first
    # is destroyed. This is the example that fails if the read is ever dropped.
    it 'preserves the other tiers when switching on' do
      stub_policy('large' => ['public'], 'master' => ['northeastern:drs:repository:archives'])

      described_class.apply!('w1', enabled: true, read: ['public'])

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions).with(
        'w1', policy: { 'large' => ['public'], 'master' => ['northeastern:drs:repository:archives'],
                        'video' => [admin_group] }, nuid: nil
      )
    end

    # An absent independent tier rides the Work's own visibility, which is what
    # "not streaming only" means — so off REMOVES the key rather than publishing it.
    it 'removes the video tier when switching off' do
      stub_policy('video' => [admin_group], 'large' => ['public'])

      described_class.apply!('w1', enabled: false, read: ['public'])

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions).with(
        'w1', policy: { 'large' => ['public'] }, nuid: nil
      )
    end

    it 'does not write when the stored state already matches' do
      stub_policy('video' => [admin_group])

      described_class.apply!('w1', enabled: true, read: ['public'])

      expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
    end

    # Turning off a restriction this feature did not impose would widen it.
    it 'leaves a foreign video tier alone when switching off' do
      stub_policy('video' => ['northeastern:drs:repository:archives'])

      described_class.apply!('w1', enabled: false, read: ['public'])

      expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
    end

    it 'writes a private tier on a work that does not grant the admin group' do
      stub_policy({})

      described_class.apply!('w1', enabled: true, read: ['editors'])

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions).with(
        'w1', policy: { 'video' => [] }, nuid: nil
      )
    end
  end
end
