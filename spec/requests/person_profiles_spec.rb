# frozen_string_literal: true

require 'rails_helper'

# A person editing their own Person. Who may edit comes from the Person's NUID,
# server-side. The real Atlas grant is exercised in person_profiles_live_spec.
RSpec.describe 'Editing your own profile', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:person) do
    AtlasRb::Mash.new('id' => 'pp11aa22', 'nuid' => '000000006', 'display_name' => 'Susan Williams',
                      'bio' => 'Archivist.', 'orcid' => '0000-0002-1825-0097')
  end
  let(:owner) do
    User.new(email: 'owner@example.com', password: 'password', nuid: '000000006', name: 'Williams, Susan', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end
  let(:other) do
    User.new(email: 'other@example.com', password: 'password', nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  def unprocessable(code)
    response = instance_double(Faraday::Response, status: 422, body: { error: code }.to_json)
    AtlasRb::ResourceError.new('PATCH /people/pp11aa22 → 422', response: response)
  end

  before do
    allow(AtlasRb::Person).to receive(:find).with('pp11aa22', anything).and_return(person)
    allow(AtlasRb::Person).to receive(:resolve).and_return([person])
    allow(AtlasRb::User).to receive(:resolve).and_return([])
  end

  describe 'the profile page' do
    it 'offers Edit details to the person whose profile it is' do
      sign_in owner

      get person_path('pp11aa22')

      expect(response.body).to include(edit_person_path('pp11aa22'), 'Edit details')
    end

    it 'offers it to no one else' do
      sign_in other
      get person_path('pp11aa22')
      expect(response.body).not_to include(edit_person_path('pp11aa22'))

      sign_out other
      get person_path('pp11aa22')
      expect(response.body).not_to include(edit_person_path('pp11aa22'))
    end
  end

  describe 'GET edit' do
    it 'renders the form with the current details' do
      sign_in owner

      get edit_person_path('pp11aa22')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Susan Williams', 'Archivist.', '0000-0002-1825-0097')
    end

    it "refuses someone else's profile" do
      sign_in other

      get edit_person_path('pp11aa22')

      expect(response).to have_http_status(:forbidden)
    end

    it 'sends a visitor to sign in' do
      get edit_person_path('pp11aa22')

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'PATCH update' do
    let(:fields) { { display_name: 'Sue Williams', bio: 'Archivist and historian.', orcid: '' } }

    it 'saves the three fields and returns to the profile' do
      sign_in owner
      expect(AtlasRb::Person).to receive(:update).with('pp11aa22', **fields, nuid: '000000006').and_return(person)
      expect(NuidResolver).to receive(:forget).with('000000006')

      patch person_path('pp11aa22'), params: { person: fields }

      expect(response).to redirect_to(person_path('pp11aa22'))
    end

    it 'shows the new name in the header without a fresh sign-in' do
      sign_in owner
      allow(AtlasRb::Person).to receive(:update).and_return(person)

      patch person_path('pp11aa22'), params: { person: fields.merge(display_name: ' Sue Williams ') }
      get root_path

      expect(response.parsed_body.at_css(%(a[href="#{person_path('pp11aa22')}"])).text.strip).to eq('Sue Williams')
    end

    it "leaves an admin's own header name alone when they save while acting as the person" do
      admin = User.new(email: 'admin@example.com', password: 'password', nuid: '000000004', name: 'Admin, Ada',
                       role: 'admin', groups: [])
      allow(AtlasRb::AuditEvent).to receive(:emit)
      allow(AtlasRb::Authentication).to receive(:login).with('000000006').and_return(
        AtlasRb::Mash.new('nuid' => '000000006', 'name' => 'Williams, Susan', 'email' => owner.email,
                          'role' => owner.role, 'groups' => owner.groups)
      )
      allow(User).to receive(:curated_name_for).and_return(nil)
      allow(AtlasRb::Person).to receive(:update).and_return(person)
      sign_in admin
      post admin_act_as_path, params: { nuid: '000000006' }

      patch person_path('pp11aa22'), params: { person: fields }
      delete admin_impersonation_path
      get root_path

      expect(response.body).to include('Ada Admin')
      expect(response.body).not_to include('Sue Williams')
    end

    it "refuses someone else's profile without writing" do
      sign_in other
      expect(AtlasRb::Person).not_to receive(:update)

      patch person_path('pp11aa22'), params: { person: fields }

      expect(response).to have_http_status(:forbidden)
    end

    it "explains Atlas's refusal and keeps what was typed" do
      sign_in owner
      allow(AtlasRb::Person).to receive(:update).and_raise(unprocessable('invalid_orcid'))

      patch person_path('pp11aa22'), params: { person: fields.merge(orcid: '1234') }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(PersonProfileRefusals::MESSAGES['invalid_orcid'], 'Archivist and historian.')
    end
  end

  describe 'the header name' do
    it "links to the person's own profile" do
      sign_in owner

      get root_path

      expect(response.parsed_body.at_css(%(a[href="#{person_path('pp11aa22')}"])).text).to eq(owner.to_s)
    end

    it 'is plain text, looked up once per session, for someone with no Person' do
      allow(AtlasRb::Person).to receive(:resolve).and_return([])
      sign_in other

      get root_path
      get root_path

      expect(AtlasRb::Person).to have_received(:resolve).once
      expect(response.parsed_body.at_css('span.user-menu-name').text).to eq(other.to_s)
    end
  end
end
