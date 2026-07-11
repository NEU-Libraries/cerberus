# frozen_string_literal: true

require 'rails_helper'

# Self-service account switching: acting as another of your own accounts, and
# setting a preferred default. The atlas_rb account bindings are stubbed — these
# specs cover the membership guard, the redirect/flash, and whether the right
# Atlas call is made, not the Atlas round-trip.
RSpec.describe 'Accounts', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    User.new(email: 'staff@northeastern.edu', password: 'password', nuid: '000000005',
             role: 'standard', groups: ['northeastern:drs:library:dsg_students'])
  end

  let(:accounts) do
    AtlasRb::Mash.new(
      'nuid' => '000000005',
      'accounts' => [
        { 'email' => 'staff@northeastern.edu', 'affiliation' => 'staff', 'role' => 'standard',
          'groups' => ['northeastern:drs:library:dsg_students'], 'preferred' => true },
        { 'email' => 'student@husky.neu.edu', 'affiliation' => 'student', 'role' => 'standard',
          'groups' => ['northeastern:drs:all'], 'preferred' => false }
      ]
    )
  end

  it 'redirects an anonymous visitor away from a switch' do
    post '/accounts/switch', params: { email: 'student@husky.neu.edu' }
    expect(response).to redirect_to(root_path)
  end

  context 'signed in' do
    before do
      sign_in user
      allow(AtlasRb::User).to receive(:accounts).with('000000005', nuid: '000000005').and_return(accounts)
    end

    describe 'POST /accounts/switch' do
      it "switches to another of the caller's accounts" do
        switched = AtlasRb::Mash.new('email' => 'student@husky.neu.edu', 'nuid' => '000000005',
                                     'name' => 'User, Standard', 'role' => 'standard',
                                     'groups' => ['northeastern:drs:all'], 'affiliation' => 'student')
        expect(AtlasRb::Authentication).to receive(:login)
          .with('000000005', email: 'student@husky.neu.edu').and_return(switched)

        post '/accounts/switch', params: { email: 'student@husky.neu.edu' }

        expect(response).to redirect_to(my_drs_path)
        expect(flash[:notice]).to include('student@husky.neu.edu')
      end

      it 'refuses an account that is not the caller\'s (and makes no login call)' do
        expect(AtlasRb::Authentication).not_to receive(:login)

        post '/accounts/switch', params: { email: 'someone@else.edu' }

        expect(response).to redirect_to(my_drs_path)
        expect(flash[:alert]).to match(/not one of yours/)
      end
    end

    describe 'POST /accounts/prefer' do
      it 'sets the preferred account' do
        expect(AtlasRb::User).to receive(:set_preferred)
          .with('000000005', email: 'student@husky.neu.edu', nuid: '000000005')

        post '/accounts/prefer', params: { email: 'student@husky.neu.edu' }

        expect(response).to redirect_to(my_drs_path)
        expect(flash[:notice]).to match(/preferred account/)
      end

      it 'refuses a foreign account (and makes no set-preferred call)' do
        expect(AtlasRb::User).not_to receive(:set_preferred)

        post '/accounts/prefer', params: { email: 'someone@else.edu' }

        expect(flash[:alert]).to match(/not one of yours/)
      end
    end
  end
end
