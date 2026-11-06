# frozen_string_literal: true

require 'rails_helper'

# Atlas grants :update_profile to a non-admin for the Person carrying their own
# NUID, and validates the three fields. Real Atlas, so this proves the grant.
RSpec.describe 'Editing your own profile against Atlas', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:staff) do
    User.new(email: 'staff@example.com', password: 'password', nuid: '000000006', name: 'Williams, Susan', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  before(:all) do
    Current.nuid = '000000004'
    @person = Array(AtlasRb::Person.resolve(['000000006'], nuid: '000000004')).first ||
              AtlasRb::Person.create(nuid: '000000006', display_name: 'Susan Williams')
    @original = @person.to_h.slice('display_name', 'bio', 'orcid')
  end

  after(:all) do
    AtlasRb::Person.update(@person['id'], **@original.symbolize_keys.transform_values(&:to_s), nuid: '000000004')
  end

  before { sign_in staff }

  it 'links the header to the profile and saves a new bio' do
    get root_path
    expect(response.body).to include(%(href="#{person_path(@person['id'])}"))

    patch person_path(@person['id']), params: { person: { display_name: @original['display_name'],
                                                          bio: 'Edited by its owner.', orcid: '' } }

    expect(response).to redirect_to(person_path(@person['id']))
    expect(AtlasRb::Person.find(@person['id'], nuid: '000000004')['bio']).to eq('Edited by its owner.')
  end

  it 'answers a malformed ORCID iD with the form and its message' do
    patch person_path(@person['id']), params: { person: { display_name: @original['display_name'], orcid: '1234' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(PersonProfileRefusals::MESSAGES['invalid_orcid'])
  end
end
