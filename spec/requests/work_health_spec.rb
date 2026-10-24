# frozen_string_literal: true

require 'rails_helper'

# The Health tab's frame action and the admin lookup by NOID. atlas_rb is
# stubbed throughout: these exercise Cerberus's rendering of each answer, not
# Atlas's grading.
RSpec.describe 'Work health', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
  end
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000006', name: 'Williams, Susan', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  def report(grade, findings = [])
    AtlasRb::Mash.new('noid' => 'w1', 'grade' => grade, 'fixity_checked' => false, 'findings' => findings)
  end

  def finding(severity, code, subject: 'w1', message: "#{code} message")
    { 'severity' => severity, 'code' => code, 'subject' => subject, 'message' => message }
  end

  def stub_check(answer = nil, &)
    if block_given?
      allow(AtlasRb::Work).to receive(:health_check, &)
    else
      allow(AtlasRb::Work).to receive(:health_check).and_return(answer)
    end
  end

  def resource_error(status)
    AtlasRb::ResourceError.new("GET /works/w1/health_check → #{status}",
                               response: instance_double(Faraday::Response, status: status, body: ''))
  end

  describe 'GET /works/:id/health' do
    context 'as an admin' do
      before { sign_in admin_user }

      it 'renders a green grade, in words, inside the frame' do
        stub_check(report('green'))

        get '/works/w1/health'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('turbo-frame id="work-health"', 'Green: viable')
        expect(response.body).not_to include('audit-history__title')
      end

      it 'keeps the findings card for advisory notes on a Work with no problems' do
        stub_check(report('green', [finding('advisory', 'private')]))

        get '/works/w1/health'

        expect(response.body).to include('Nothing is missing or broken', '1 advisory note')
      end

      it 'always says the bytes were not re-hashed, so a green does not read as verified' do
        stub_check(report('green'))

        get '/works/w1/health'

        expect(response.body).to include('Fixity', 'Not checked. Bytes are re-hashed only by the offline check.')
      end

      it 'renders a yellow grade with its findings and their repairs' do
        stub_check(report('yellow', [finding('repairable', 'untitled'), finding('repairable', 'not_indexed')]))

        get '/works/w1/health'

        expect(response.body).to include('Yellow: repairable, nothing lost', 'untitled message',
                                         'Open the Metadata tab', admin_reindex_work_path('w1'))
      end

      # The note names who repairs a problem this page has no control for.
      it 'says an Atlas operator repairs a problem with no repair link, and only then' do
        stub_check(report('yellow', [finding('repairable', 'envelope_stale')]))
        get '/works/w1/health'
        expect(response.body).to include('An Atlas operator repairs any problem with nothing in the Repair column')

        stub_check(report('yellow', [finding('repairable', 'untitled')]))
        get '/works/w1/health'
        expect(response.body).not_to include('An Atlas operator repairs')
      end

      it 'renders a red grade with the fatal finding before the repairable one' do
        stub_check(report('red', [finding('repairable', 'untitled', message: 'Second'),
                                  finding('fatal', 'binary_missing', subject: 'b9', message: 'First')]))

        get '/works/w1/health'

        expect(response.body).to include('Red: content lost; restore or re-deposit', 'b9')
        expect(response.body.index('First')).to be < response.body.index('Second')
      end

      it 'puts advisory findings in a collapsed group, apart from the problems' do
        stub_check(report('green', [finding('advisory', 'no_handle')]))

        get '/works/w1/health'

        expect(response.body).to include('<details', '1 advisory note', 'no_handle message')
      end

      it 'calls Atlas as the operator' do
        stub_check(report('green'))

        get '/works/w1/health'

        expect(AtlasRb::Work).to have_received(:health_check).with('w1', nuid: '000000004')
      end

      it 'says the Work is gone when Atlas answers 404' do
        stub_check(nil)

        get '/works/w1/health'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('turbo-frame id="work-health"', 'No Work found for w1')
      end

      it 'says the check is not available when Atlas refuses it' do
        stub_check { raise resource_error(403) }

        get '/works/w1/health'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('The health check is not available to you')
      end

      it 'names the outage and offers a retry when Atlas is unreachable' do
        stub_check { raise Faraday::ConnectionFailed, 'refused' }

        get '/works/w1/health'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Records are temporarily unavailable', 'Try again')
      end

      it 'renders a failed check inline rather than an error page' do
        stub_check { raise resource_error(500) }

        get '/works/w1/health'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('turbo-frame id="work-health"', 'The health check could not run')
      end
    end

    it 'admits a delegated admin' do
      sign_in delegate_user
      stub_check(report('green'))

      get '/works/w1/health'

      expect(response).to have_http_status(:ok)
    end

    it 'refuses staff without the admin group before reaching Atlas' do
      sign_in staff_user
      stub_check(report('green'))

      get '/works/w1/health'

      expect(response).to have_http_status(:forbidden)
      expect(AtlasRb::Work).not_to have_received(:health_check)
    end
  end

  describe 'GET /admin/work_health' do
    before { sign_in delegate_user }

    it 'offers the NOID form and runs no check until a NOID is given' do
      stub_check(report('green'))

      get '/admin/work_health'

      expect(response.body).to include('Work NOID')
      expect(AtlasRb::Work).not_to have_received(:health_check)
    end

    # No tabs sit beside this page, so a repair opens the edit page's tab, and a
    # reindex comes back here.
    it 'points each repair at the edit page and returns a reindex here' do
      stub_check(report('yellow', [finding('repairable', 'staff_edit_missing'), finding('repairable', 'not_indexed')]))

      get '/admin/work_health', params: { noid: ' w1 ' }

      expect(AtlasRb::Work).to have_received(:health_check).with('w1', nuid: '000000002')
      expect(response.body).to include(CGI.escapeHTML(edit_work_path('w1', tab: 'permissions')),
                                       CGI.escapeHTML(admin_work_health_path(noid: 'w1')))
    end

    it 'says so when the NOID is no Work' do
      stub_check(nil)

      get '/admin/work_health', params: { noid: 'nope' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No Work found for nope')
    end
  end
end
