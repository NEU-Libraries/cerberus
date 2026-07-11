# frozen_string_literal: true

require 'rails_helper'

# The Atlas SSO shim's sign-in flow. A person whose NUID holds more than one
# account lands with a nudge toward My DRS; single-account users get the plain
# confirmation. The atlas_rb bindings are stubbed.
RSpec.describe 'Atlas sign-in', type: :request do
  before do
    allow(AtlasRb::Authentication).to receive(:login).with('000000005').and_return(
      AtlasRb::Mash.new('email' => 'staff@northeastern.edu', 'nuid' => '000000005',
                        'name' => 'User, Standard', 'role' => 'standard',
                        'groups' => ['northeastern:drs:library:dsg_students'], 'affiliation' => 'staff')
    )
  end

  it 'nudges a multi-account person toward My DRS' do
    allow(AtlasRb::User).to receive(:accounts).with('000000005', nuid: '000000005').and_return(
      AtlasRb::Mash.new('nuid' => '000000005', 'accounts' => [{ 'email' => 'a' }, { 'email' => 'b' }])
    )

    post '/atlas/process_login', params: { user: { nuid: '000000005' } }

    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to match(/more than one account/)
  end

  it 'gives a single-account person the plain confirmation' do
    allow(AtlasRb::User).to receive(:accounts).with('000000005', nuid: '000000005').and_return(
      AtlasRb::Mash.new('nuid' => '000000005', 'accounts' => [{ 'email' => 'a' }])
    )

    post '/atlas/process_login', params: { user: { nuid: '000000005' } }

    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to eq('You have successfully signed in.')
  end
end
