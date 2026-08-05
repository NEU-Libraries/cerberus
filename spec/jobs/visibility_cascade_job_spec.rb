# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VisibilityCascadeJob do
  let(:actor) { '000000010' }

  def target(noid, klass = 'Work')
    NarrowingTargets::Target.new(noid: noid, klass: klass, depth: 1)
  end

  def stub_targets(*list)
    allow(NarrowingTargets).to receive(:new).and_return(list)
  end

  # The envelope the permissions endpoint returns — read/edit/edit_users/embargo
  # plus the provenance slots.
  def envelope(read:, edit: ['northeastern:drs:repository:staff'], edit_users: [], embargo: nil)
    AtlasRb::Mash.new('read' => read, 'edit' => edit, 'edit_users' => edit_users,
                      'embargo' => embargo, 'depositor' => '000000010')
  end

  def run(read_groups: ['northeastern:drs:library:archives'])
    Current.set(nuid: actor) do
      described_class.perform_now(noid: 'top', uuid: 'uuid-top',
                                  permissions: { 'read' => read_groups })
    end
  end

  describe 'clamping' do
    it 'narrows a public descendant to the container’s audience' do
      stub_targets(target('w1'))
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))
      allow(AtlasRb::Work).to receive(:metadata)

      run

      expect(AtlasRb::Work).to have_received(:metadata).with(
        'w1', hash_including('permissions' => hash_including('read' => ['northeastern:drs:library:archives']))
      )
    end

    it 'leaves a descendant that is already more restricted alone' do
      stub_targets(target('w1'))
      allow(AtlasRb::Resource).to receive(:permissions).with('w1')
                                                       .and_return(envelope(read: ['northeastern:drs:nupd:media']))
      allow(AtlasRb::Work).to receive(:metadata)

      run(read_groups: %w[northeastern:drs:nupd:media northeastern:drs:library:archives])

      # Its audience is already a subset, so the intersection changes nothing
      # and cascading the container's wider list wholesale would WIDEN it.
      expect(AtlasRb::Work).not_to have_received(:metadata)
    end

    it 'makes a child private when the two audiences share nobody' do
      stub_targets(target('w1'))
      allow(AtlasRb::Resource).to receive(:permissions).with('w1')
                                                       .and_return(envelope(read: ['northeastern:drs:nupd:media']))
      allow(AtlasRb::Work).to receive(:metadata)

      run(read_groups: ['northeastern:drs:library:archives'])

      expect(AtlasRb::Work).to have_received(:metadata).with(
        'w1', hash_including('permissions' => hash_including('read' => []))
      )
    end
  end

  # Atlas's setter assigns these unconditionally, so a payload carrying only
  # `read` would collapse edit_groups to the staff prepend and blank the embargo.
  describe 'the envelope it sends' do
    it 'round-trips edit, edit_users and embargo untouched' do
      stub_targets(target('w1'))
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(
        envelope(read: ['public'], edit: %w[groupA groupB], edit_users: ['000000077'],
                 embargo: '2030-01-15T00:00:00+00:00')
      )
      allow(AtlasRb::Work).to receive(:metadata)

      run

      expect(AtlasRb::Work).to have_received(:metadata).with(
        'w1', { 'permissions' => { 'embargo'    => '2030-01-15T00:00:00+00:00',
                                   'read'       => ['northeastern:drs:library:archives'],
                                   'edit'       => %w[groupA groupB],
                                   'edit_users' => ['000000077'] } }
      )
    end

    it 'omits the write-once provenance slots so the setter leaves them alone' do
      stub_targets(target('w1'))
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))
      allow(AtlasRb::Work).to receive(:metadata)

      run

      sent = nil
      expect(AtlasRb::Work).to have_received(:metadata) { |_noid, payload| sent = payload }
      expect(sent['permissions'].keys).to contain_exactly('embargo', 'read', 'edit', 'edit_users')
    end
  end

  # The container is written from what was submitted, not from what is stored,
  # so an edit-group or embargo change made in the same submit survives. A
  # round-trip would silently discard it.
  describe 'the container itself' do
    it 'takes the submitted envelope verbatim, without re-reading the stored one' do
      stub_targets(target('top', 'Collection'))
      allow(AtlasRb::Resource).to receive(:permissions)
      allow(AtlasRb::Collection).to receive(:metadata)

      submitted = { 'read' => ['northeastern:drs:library:archives'], 'edit' => ['newgroup'], 'embargo' => '' }
      Current.set(nuid: actor) do
        described_class.perform_now(noid: 'top', uuid: 'uuid-top', permissions: submitted)
      end

      expect(AtlasRb::Collection).to have_received(:metadata).with('top', { 'permissions' => submitted })
      expect(AtlasRb::Resource).not_to have_received(:permissions)
    end

    # The report speaks to what ELSE changed, so the container is tallied
    # separately — otherwise the completion message claims one more item than
    # the confirmation promised.
    it 'is not counted among the items it reports narrowing' do
      stub_targets(target('w1'), target('top', 'Collection'))
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))
      allow(AtlasRb::Work).to receive(:metadata)
      allow(AtlasRb::Collection).to receive(:metadata)

      run

      expect(Message.last.body).to include('1 item narrowed')
    end
  end

  describe 'ordering and dispatch' do
    it 'writes each target through its own atlas_rb class, in the order given' do
      stub_targets(target('w1'), target('child', 'Collection'), target('top', 'Collection'))
      allow(AtlasRb::Resource).to receive(:permissions).and_return(envelope(read: ['public']))

      calls = []
      allow(AtlasRb::Work).to receive(:metadata) { |noid, _| calls << ['Work', noid] }
      allow(AtlasRb::Collection).to receive(:metadata) { |noid, _| calls << ['Collection', noid] }

      run

      # The container is written last, after everything beneath it.
      expect(calls).to eq([%w[Work w1], %w[Collection child], %w[Collection top]])
    end
  end

  describe 'reporting' do
    it 'tells the actor what changed' do
      stub_targets(target('w1'), target('w2'))
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))
      allow(AtlasRb::Resource).to receive(:permissions).with('w2')
                                                       .and_return(envelope(read: ['northeastern:drs:library:archives']))
      allow(AtlasRb::Work).to receive(:metadata)

      expect { run }.to change(Message, :count).by(1)

      message = Message.last
      expect(message.recipient_nuid).to eq(actor)
      expect(message.subject).to eq('Visibility change finished')
      expect(message.body).to include('1 item narrowed', 'already at least that restricted')
    end

    # Anything that failed to narrow is still exposed, so it is named rather
    # than folded into a count.
    it 'names what it could not change' do
      stub_targets(target('w1'))
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))
      allow(AtlasRb::Work).to receive(:metadata).and_raise(AtlasRb::ForbiddenError.new('no rights'))

      run

      message = Message.last
      expect(message.subject).to eq('Visibility change finished with problems')
      expect(message.body).to include('may still be visible', 'Work w1')
    end

    it 'skips a resource the permissions lookup cannot resolve' do
      stub_targets(target('gone'))
      allow(AtlasRb::Resource).to receive(:permissions).with('gone').and_return(nil)
      allow(AtlasRb::Work).to receive(:metadata)

      run

      expect(AtlasRb::Work).not_to have_received(:metadata)
      expect(Message.last.subject).to eq('Visibility change finished')
    end
  end

  # A lock conflict is transient and the cascade is idempotent, so it has to
  # escape the per-target rescue and reach retry_on. Asserted by its absence
  # from the report rather than by a raise: retry_on intercepts the exception,
  # so perform_now never propagates it.
  it 'does not record a stale-resource conflict as a permanent failure' do
    stub_targets(target('w1'))
    allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))
    allow(AtlasRb::Work).to receive(:metadata).and_raise(AtlasRb::StaleResourceError.new('conflict'))

    expect { run }.not_to change(Message, :count)
  end

  # A derivative-access default lives in Cerberus, not in the ACL Atlas holds, so
  # narrowing a container used to leave its default naming an audience the
  # container no longer had — and Atlas then refused every new deposit into it,
  # because a tier may not be more visible than its Work.
  describe 'the derivative default it leaves behind' do
    let(:archives) { 'northeastern:drs:library:archives' }
    let(:law) { 'northeastern:drs:school_of_law:law_library:staff' }

    before do
      allow(AtlasRb::Collection).to receive(:metadata)
      allow(AtlasRb::Resource).to receive(:permissions).with('top').and_return(envelope(read: ['public']))
    end

    it 'clamps the narrowed container’s own default to what it can still offer' do
      sentinel = Sentinel.create!(target_id: 'top', policy: { 'master' => ['public'] })
      stub_targets(target('top', 'Collection'))

      run(read_groups: [archives])

      expect(sentinel.reload.policy['master']).to eq([archives])
    end

    it 'drops a tier whose audience the container no longer includes, leaving it to inherit' do
      sentinel = Sentinel.create!(target_id: 'top', policy: { 'master' => [law] })
      stub_targets(target('top', 'Collection'))

      run(read_groups: [archives])

      expect(sentinel.reload.policy['master']).to eq([])
    end

    it 'clamps a descendant collection’s default too, not only the container’s' do
      sentinel = Sentinel.create!(target_id: 'c1', policy: { 'master' => ['public'] })
      stub_targets(target('c1', 'Collection'))
      allow(AtlasRb::Resource).to receive(:permissions).with('c1').and_return(envelope(read: ['public']))

      run(read_groups: [archives])

      expect(sentinel.reload.policy['master']).to eq([archives])
    end

    it 'leaves a default that is already within the new audience alone' do
      sentinel = Sentinel.create!(target_id: 'top', policy: { 'master' => [archives] })
      stub_targets(target('top', 'Collection'))

      expect { run(read_groups: [archives]) }.not_to(change { sentinel.reload.updated_at })
    end
  end
end
