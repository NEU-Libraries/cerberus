# frozen_string_literal: true

require 'rails_helper'

# The ledger's two tabs. No Atlas here: both lists read Cerberus's own tables,
# which is the whole reason the surface can show what is outstanding at all.
RSpec.describe 'Admin ledger', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: '000000004', role: 'admin')
  end
  # :privileged + the admin group — the devolved-admin tier this surface admits.
  let(:delegate) do
    User.new(email: 'delegate@example.com', password: 'password', nuid: '000000002', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP, 'northeastern:drs:repository:admin'])
  end
  # :privileged WITHOUT the admin group — the negative control.
  let(:staff) do
    User.new(email: 'staff@example.com', password: 'password', nuid: '000000006', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP])
  end

  let!(:withdrawal) do
    AdminNotice.create!(kind: 'request_withdraw', subject: 'Request to withdraw “thesis.pdf”',
                        actor_nuid: '000000010', subject_noid: 'w1',
                        payload: { subject_type: 'Work', subject_title: 'thesis.pdf',
                                   note: 'No longer authoritative.' })
  end

  describe 'the authorization gate' do
    it 'admits an admin' do
      sign_in admin
      get admin_ledger_path
      expect(response).to have_http_status(:ok)
    end

    it 'admits the devolved-admin tier' do
      sign_in delegate
      get admin_ledger_path
      expect(response).to have_http_status(:ok)
    end

    it 'refuses repository staff without the admin group' do
      sign_in staff
      get admin_ledger_path
      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses the unauthenticated' do
      get admin_ledger_path
      expect(response).to have_http_status(:found).or have_http_status(:forbidden)
    end
  end

  describe 'the requests tab' do
    before { sign_in admin }

    it 'is the default tab, and lists the request with its note and remedy' do
      get admin_ledger_path

      expect(response.body).to include('thesis.pdf')
      expect(response.body).to include('No longer authoritative.')
      expect(response.body).to include('Open the work to withdraw it')
    end

    # Narrowing a community does not cascade, so whoever fulfils it has to be
    # told the route or the request is unanswerable.
    it 'carries the community remedy on a community restriction' do
      AdminNotice.create!(kind: 'request_restrict', subject: 'Request to restrict “Archives”',
                          actor_nuid: '000000010', subject_noid: 'm1',
                          payload: { subject_type: 'Community', subject_title: 'Archives' })

      get admin_ledger_path

      expect(response.body).to include('Restrict each collection within it first')
    end

    # Only :admin may run a visibility cascade. The delegate tier sees the row —
    # seeing the queue is the point — and is told who has to act.
    it 'offers the remedy to an admin and names the gate to a delegate' do
      AdminNotice.create!(kind: 'request_restrict', subject: 'Request to restrict “Reading Room”',
                          actor_nuid: '000000010', subject_noid: 'c1',
                          payload: { subject_type: 'Collection', subject_title: 'Reading Room' })

      get admin_ledger_path
      expect(response.body).to include('Open its permissions')

      sign_in delegate
      get admin_ledger_path
      expect(response.body).to include('An administrator has to do this one')
      expect(response.body).not_to include('Open its permissions')
    end

    # An unknown filter shows everything rather than an unexplained empty page.
    it 'falls through to every request on an unknown kind' do
      get admin_ledger_path(tab: 'requests', kind: 'nonsense')
      expect(response.body).to include('thesis.pdf')
    end

    # The two tabs are one table split by kind, so neither may leak the other.
    it 'keeps activity off the requests tab and requests off the activity tab' do
      AdminNotice.create!(kind: 'set_reindex', subject: 'Set reindex finished', subject_noid: 's1')

      get admin_ledger_path(tab: 'requests')
      expect(response.body).not_to include('Set reindex finished')

      get admin_ledger_path(tab: 'activity')
      expect(response.body).not_to include('thesis.pdf')
    end
  end

  describe 'the activity tab' do
    before { sign_in admin }

    let!(:promotion) do
      AdminNotice.create!(kind: 'showcase_promotion', subject: 'Published to the “Datasets” showcase',
                          actor_nuid: '000000010', subject_noid: 'w9',
                          payload: { outcome: 'promoted', genre: 'Datasets',
                                     community_name: 'Marine Science', work_title: 'reef-survey.csv' })
    end
    let!(:refusal) do
      AdminNotice.create!(kind: 'showcase_promotion', subject: 'Showcase publication refused',
                          actor_nuid: '000000010', subject_noid: 'w8',
                          payload: { outcome: 'refused', reason: 'no_showcase', genre: 'Theses',
                                     work_title: 'slides.pptx' })
    end

    it 'lists a promotion with its community, genre and uploaded filename' do
      get admin_ledger_path(tab: 'activity')

      expect(response.body).to include('reef-survey.csv')
      expect(response.body).to include('Marine Science')
      expect(response.body).to include('Datasets')
    end

    # The refusal is the row nothing else in the app can show.
    it 'lists a refusal and says why in plain words' do
      get admin_ledger_path(tab: 'activity')

      expect(response.body).to include('slides.pptx')
      expect(response.body).to include('Refused')
      expect(response.body).to include('has no showcase for the genre')
    end

    it 'filters by kind' do
      AdminNotice.create!(kind: 'set_reindex', subject: 'Set reindex finished', subject_noid: 's1')

      get admin_ledger_path(tab: 'activity', kind: 'set_reindex')
      expect(response.body).to include('Set reindex finished')
      expect(response.body).not_to include('reef-survey.csv')
    end

    it 'renders a digest as its own block, grouped by community and genre' do
      AdminNotice.create!(
        kind: 'daily_digest', subject: 'Daily digest', occurred_on: Time.zone.today,
        payload: { counts:    { 'requests_made' => 2, 'loads_run' => 1 },
                   showcases: { 'promoted' => 1, 'refused' => 0, 'truncated' => 0,
                                'entries' => [{ 'community' => 'Marine Science', 'genre' => 'Datasets',
                                                'title' => 'reef-survey.csv', 'nuid' => '000000010',
                                                'outcome' => 'promoted' }] } }
      )

      get admin_ledger_path(tab: 'activity')

      expect(response.body).to include('ledger-digest')
      expect(response.body).to include('Marine Science · Datasets')
      expect(response.body).to include('Published to showcases')
    end
  end
end
