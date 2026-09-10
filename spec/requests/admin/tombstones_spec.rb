# frozen_string_literal: true

require 'rails_helper'

# The tombstone registry. Lists tombstoned resources and offers the two ways
# out of a withdrawal — reverse it, or finish it permanently — via atlas_rb's
# operator-only Admin namespace. TombstonedItems and atlas_rb are stubbed so
# these exercise the Cerberus controller/view wiring + the type dispatch, not
# Atlas or the live Solr inverse query (covered in tombstoned_items_spec).
#
# The two verbs are gated differently, so the gate block covers both: the
# devolved-admin tier reaches restore but not destroy, matching Atlas's
# Ability, which grants the delegate tier :restore and withholds :destroy.
RSpec.describe 'Admin::Tombstones', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  # :privileged, but not in the admin group.
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000006', name: 'Williams, Susan', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP])
  end
  # :privileged + the admin group jointly — the devolved-admin tier (stock
  # pilot user 000000002). Restore-a-tombstone is one of the devolved
  # surfaces: restoring is an operator-level lifecycle action, granted to the
  # delegate tier alongside :reparent rather than to edit rights.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP, Permissions::ADMIN_GROUP])
  end

  def tombstoned_doc(noid:, title:, klass: 'Work')
    SolrDocument.new('id'                      => "uuid-#{noid}",
                     'alternate_ids_tesim'     => ["id-#{noid}"],
                     'internal_resource_tesim' => klass,
                     'title_tsim'              => [title],
                     'tombstoned_bsi'          => true)
  end

  def fake_results(*docs)
    instance_double(Blacklight::Solr::Response, documents: docs, total_pages: 1)
  end

  describe 'admin gate' do
    it 'forbids :privileged staff' do
      sign_in staff_user
      get '/admin/tombstones'
      expect(response).to have_http_status(:forbidden)
    end

    # The delegate tier gets restore because Atlas grants it :restore
    # (apply_admin_delegate_abilities); gating Cerberus tighter would make that
    # grant unreachable. :privileged alone still does not — the admin group is
    # the other half of the pair.
    it 'admits a devolved-admin delegate' do
      sign_in delegate_user
      allow(TombstonedItems).to receive(:call).and_return(fake_results)
      get '/admin/tombstones'
      expect(response).to have_http_status(:ok)
    end

    it 'redirects the unauthenticated to sign in' do
      get '/admin/tombstones'
      expect(response).to redirect_to(new_user_session_path)
    end

    # Atlas's apply_admin_delegate_abilities grants :reparent, :restore,
    # :create AuditEvent and :read_versions, and deliberately omits :destroy.
    # Gating destroy any wider here would only earn a 403 from the far end.
    it 'forbids a devolved-admin delegate the permanent delete' do
      sign_in delegate_user
      expect(AtlasRb::Admin::Work).not_to receive(:destroy)

      delete '/admin/tombstones/abc', params: { type: 'Work' }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'as admin' do
    before { sign_in admin_user }

    describe 'GET index' do
      it 'lists each withdrawn item with its title, PID and a restore action' do
        allow(TombstonedItems).to receive(:call)
          .and_return(fake_results(tombstoned_doc(noid: 'abc', title: 'Withdrawn Thesis'),
                                   tombstoned_doc(noid: 'xyz', title: 'Old Community', klass: 'Community')))

        get '/admin/tombstones'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Withdrawn Thesis', 'abc', 'Old Community', 'Restore')
      end

      it 'shows the empty state when nothing is tombstoned' do
        allow(TombstonedItems).to receive(:call).and_return(fake_results)
        get '/admin/tombstones'
        expect(response.body).to include('Nothing is tombstoned')
      end

      # The caveat is row-typed because it is only true of a container: Atlas
      # refuses a Collection or Community that still holds a member and counts
      # tombstoned ones, while a Work purge cascades into its own FileSets.
      it 'offers the permanent delete on a Work row, with no container caveat' do
        allow(TombstonedItems).to receive(:call)
          .and_return(fake_results(tombstoned_doc(noid: 'abc', title: 'Withdrawn Thesis')))

        get '/admin/tombstones'

        expect(response.body).to include('Delete permanently')
        expect(response.body).not_to include('still holds a member')
      end

      it 'warns about members on a container row' do
        allow(TombstonedItems).to receive(:call)
          .and_return(fake_results(tombstoned_doc(noid: 'xyz', title: 'Old Collection', klass: 'Collection')))

        get '/admin/tombstones'

        expect(response.body).to include('still holds a member')
      end
    end

    describe 'POST restore' do
      it 'dispatches to the Work restorer and redirects with a notice' do
        expect(AtlasRb::Admin::Work).to receive(:restore).with('abc').and_return(instance_double(Faraday::Response, success?: true))

        post '/admin/tombstones/abc/restore', params: { type: 'Work' }

        expect(response).to redirect_to(admin_tombstones_path)
        expect(flash[:notice]).to include('live again')
      end

      it 'dispatches to the Community restorer for a Community' do
        expect(AtlasRb::Admin::Community).to receive(:restore).with('xyz').and_return(instance_double(Faraday::Response, success?: true))
        post '/admin/tombstones/xyz/restore', params: { type: 'Community' }
        expect(response).to redirect_to(admin_tombstones_path)
      end

      it 'rejects an unknown resource type without calling atlas_rb' do
        expect(AtlasRb::Admin::Work).not_to receive(:restore)
        post '/admin/tombstones/abc/restore', params: { type: 'Pizza' }
        expect(flash[:alert]).to include('Unknown resource type')
      end

      it 'reports a failure when Atlas refuses (e.g. a withdrawn parent)' do
        allow(AtlasRb::Admin::Collection).to receive(:restore).and_return(instance_double(Faraday::Response, success?: false))
        post '/admin/tombstones/abc/restore', params: { type: 'Collection' }
        expect(flash[:alert]).to include('tombstoned parent')
      end
    end

    describe 'DELETE destroy' do
      # The confirm marker is atlas_rb's friction gate on the one irreversible
      # verb, so assert it on the wire rather than trusting the binding's default
      # — there isn't one, and omitting it raises ArgumentError.
      it 'purges through the Work admin with the confirm marker and redirects with a notice' do
        expect(AtlasRb::Admin::Work).to receive(:destroy)
          .with('abc', confirm: :i_understand)
          .and_return(instance_double(Faraday::Response, success?: true))

        delete '/admin/tombstones/abc', params: { type: 'Work' }

        expect(response).to redirect_to(admin_tombstones_path)
        expect(flash[:notice]).to include('Permanently deleted')
      end

      it 'dispatches to the Community admin for a Community' do
        expect(AtlasRb::Admin::Community).to receive(:destroy)
          .with('xyz', confirm: :i_understand)
          .and_return(instance_double(Faraday::Response, success?: true))

        delete '/admin/tombstones/xyz', params: { type: 'Community' }

        expect(response).to redirect_to(admin_tombstones_path)
      end

      it 'rejects an unknown resource type without calling atlas_rb' do
        expect(AtlasRb::Admin::Work).not_to receive(:destroy)
        delete '/admin/tombstones/abc', params: { type: 'Pizza' }
        expect(flash[:alert]).to include('Unknown resource type')
      end

      # Atlas answers a non-empty container with 422 + code "has_children", on a
      # path outside atlas_rb's typed-error middleware — so it arrives as a plain
      # response and the code has to be read off the body. Note the envelope puts
      # the message on `error` and the token on `code`, the opposite way round
      # from the re-parent and linked-member envelopes.
      it 'names the members when Atlas refuses a non-empty container' do
        refusal = '{"error":"cannot destroy a collection that still has members","code":"has_children"}'
        allow(AtlasRb::Admin::Collection).to receive(:destroy)
          .and_return(instance_double(Faraday::Response, success?: false, body: refusal))

        delete '/admin/tombstones/abc', params: { type: 'Collection' }

        expect(flash[:alert]).to include('still has members', 'tombstoned members count')
      end

      it 'falls back to the generic alert on a refusal it cannot read' do
        allow(AtlasRb::Admin::Work).to receive(:destroy)
          .and_return(instance_double(Faraday::Response, success?: false, body: 'Not Found'))

        delete '/admin/tombstones/abc', params: { type: 'Work' }

        expect(flash[:alert]).to eq(Admin::TombstonesController::PURGE_FAILED)
      end

      it 'reports a transport failure instead of raising' do
        allow(AtlasRb::Admin::Work).to receive(:destroy).and_raise(Faraday::ConnectionFailed, 'down')

        delete '/admin/tombstones/abc', params: { type: 'Work' }

        expect(response).to redirect_to(admin_tombstones_path)
        expect(flash[:alert]).to eq(Admin::TombstonesController::PURGE_FAILED)
      end
    end
  end

  # The delegate tier shares the registry with :admin but not the purge, so the
  # control has to be absent from the page as well as refused at the route —
  # otherwise the surface offers an action the far end will only reject.
  describe 'as a devolved-admin delegate' do
    before { sign_in delegate_user }

    it 'offers Restore but not the permanent delete' do
      allow(TombstonedItems).to receive(:call)
        .and_return(fake_results(tombstoned_doc(noid: 'abc', title: 'Withdrawn Thesis')))

      get '/admin/tombstones'

      expect(response.body).to include('Restore')
      expect(response.body).not_to include('Delete permanently')
    end
  end
end
