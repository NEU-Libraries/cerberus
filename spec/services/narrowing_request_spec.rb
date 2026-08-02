# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NarrowingRequest do
  let(:actor) { User.new(email: 'a@example.com', nuid: '000000010', role: 'standard', groups: []) }
  let(:container) { AtlasRb::Mash.new('id' => 'top', 'valkyrie_id' => 'uuid-top') }

  def stub_impact(count: 3, over_cap: false, owned_by: nil)
    impact = instance_double(NarrowingImpact, count: count, over_cap?: over_cap)
    allow(impact).to receive(:wholly_owned_by?) { |nuid| nuid.present? && nuid == owned_by }
    allow(NarrowingImpact).to receive(:new).and_return(impact)
    allow(AtlasRb::Collection).to receive(:find).with('top').and_return(container)
  end

  def call(current:, submitted:, actor: self.actor)
    described_class.call(noid: 'top', current_read: current,
                         permissions: { read: submitted, edit: ['g'] }, actor: actor)
  end

  describe 'when the change does not take audience away' do
    it 'falls through for a widening' do
      expect(call(current: [], submitted: ['public'])).not_to be_handled
    end

    it 'falls through when the audience is unchanged' do
      expect(call(current: ['groupA'], submitted: ['groupA'])).not_to be_handled
    end

    it 'falls through when a group is added' do
      expect(call(current: ['groupA'], submitted: %w[groupA groupB])).not_to be_handled
    end

    it 'does not enqueue anything' do
      expect { call(current: [], submitted: ['public']) }.not_to have_enqueued_job(VisibilityCascadeJob)
    end
  end

  describe 'when audience is taken away' do
    before { stub_impact(owned_by: '000000010') }

    it 'treats public to private as a narrowing and dispatches' do
      outcome = call(current: ['public'], submitted: [])

      expect(outcome).to be_dispatched
      expect(outcome.message).to include('3 items inside it')
    end

    # A same-size swap still removes the outgoing group's access, so descendants
    # reachable only through it have to be reconsidered.
    it 'treats swapping one group for another as a narrowing' do
      expect(call(current: ['groupA'], submitted: ['groupB'])).to be_dispatched
    end

    it 'hands the container and the submitted envelope to the job' do
      expect { call(current: ['public'], submitted: ['groupA']) }
        .to have_enqueued_job(VisibilityCascadeJob)
        .with(noid: 'top', uuid: 'uuid-top',
              permissions: { 'read' => ['groupA'], 'edit' => ['g'] })
    end

    it 'says so plainly when the collection is empty' do
      stub_impact(count: 0, owned_by: '000000010')

      expect(call(current: ['public'], submitted: []).message).to include('Nothing was inside it')
    end
  end

  # A refusal must not fall through to the ordinary write, or the container
  # would narrow while its descendants stayed where they were.
  describe 'when the policy refuses' do
    it 'reports the other-depositors case and enqueues nothing' do
      stub_impact(owned_by: '000000011')

      outcome = nil
      expect { outcome = call(current: ['public'], submitted: []) }
        .not_to have_enqueued_job(VisibilityCascadeJob)
      expect(outcome).to be_handled
      expect(outcome).not_to be_dispatched
      expect(outcome.message).to include('deposited by other people', 'Nothing has been changed')
    end

    it 'reports the too-large case' do
      stub_impact(count: 50_000, over_cap: true, owned_by: '000000010')

      expect(call(current: ['public'], submitted: []).message).to include('too large')
    end
  end
end
