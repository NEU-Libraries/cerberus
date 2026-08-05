# frozen_string_literal: true

require 'rails_helper'

# Two places a signed-out visitor can get stranded, and one piece of advice that
# named a control the screen does not offer.
RSpec.describe 'sign-in and zero-result affordances', type: :request do
  describe 'the session form' do
    # Anything gated bounces a signed-out visitor here, but the accounts people
    # test with in dev and staging have no password — they sign in by NUID. Without
    # a pointer, arriving from a gated page is a dead end: the form in front of you
    # cannot authenticate any fixture user and nothing says where to go.
    it 'points at the NUID shim while that exists' do
      get new_user_session_path

      expect(response.body).to include(atlas_login_path)
      expect(response.body).to match(/sign in by NUID/i)
    end
  end

  describe 'a search that matches nothing' do
    # Blacklight's own advice ends "refine your search using the links on the
    # left". The facet panel still renders on a zero-result search — heading and
    # all — but every facet is empty, because a term that matched nothing has
    # nothing to narrow. So the advice sent the reader to a panel with no links in
    # it, which reads as the page being broken rather than as guidance.
    it 'does not send the reader to facet links that are not there' do
      get search_catalog_path, params: { q: 'zzzqqqxyzzy', search_field: 'all_fields' }

      expect(response.body).to include('No results found')
      expect(response.body).not_to include('using the links on the left')
      expect(response.body).to match(/fewer or more general keywords/i)
    end
  end
end
