# frozen_string_literal: true

require 'rails_helper'

# The rule this file exists to keep: **an embargo withholds content, and every
# route that serves content must apply it.**
#
# It was not kept. `/downloads/:id` and the derivative redirect applied the
# gate; `/media/:id`, the set ZIP and the queue ZIP did not, and an anonymous
# request could retrieve an embargoed work's bytes by all three. The cause was
# not any one oversight — it was that the rule lived as a call each controller
# remembered to make, so the routes written most recently were the ones that
# forgot.
#
# `authorize_show!` cannot stand in for it. An embargoed Work is deliberately
# READABLE — its metadata stays public and only its content is withheld — so a
# route whose only check is the read gate passes every time.
#
# This spec is the tripwire. It asserts the inventory of byte-serving
# controllers is exactly what we have classified. Add a streaming controller
# and this fails until you come here and say which kind it is.
RSpec.describe 'Content-route inventory', type: :request do
  # Serve a Work's CONTENT. Each must refuse a caller who cannot bypass an
  # active embargo. Behaviour is specced where each one lives; this list is
  # about completeness, not repetition.
  CONTENT_ROUTES = {
    'DownloadsController'      => 'deny_if_embargoed! in authorize_derivative_read!',
    'MediaController'          => 'deny_if_embargoed! in deny_if_work_embargoed!',
    'SetDownloadsController'   => 'SetZipPacker skips embargoed members',
    'QueueDownloadsController' => 'QueueZipPacker skips embargoed works'
  }.freeze

  # Stream, but are NOT content, or are gated above the embargo entirely.
  NON_CONTENT_STREAMERS = {
    'CollectionExportsController'   => 'metadata only (MODS + manifest); embargo withholds content, not description',
    'SetExportsController'          => 'metadata only, as above',
    'Admin::FileVersionsController' => 'admin-gated, and admins bypass embargo by definition'
  }.freeze

  it 'knows every controller that streams bytes' do
    root = Rails.root.join('app/controllers')
    streaming = Dir[root.join('**/*.rb')].filter_map do |path|
      next if path.end_with?('concerns/proxy_unbuffered.rb')
      next unless File.read(path).include?('ProxyUnbuffered')

      # Derived from the path rather than parsed out of the source: a namespaced
      # controller sits indented inside `module Admin`, which a `^class` match
      # silently skips — and silently skipping is the failure mode this whole
      # spec exists to prevent.
      Pathname.new(path).relative_path_from(root).to_s.delete_suffix('.rb').camelize
    end

    expect(streaming.sort).to eq((CONTENT_ROUTES.keys + NON_CONTENT_STREAMERS.keys).sort),
                              'A controller now streams bytes without being classified. Decide ' \
                              'whether it serves CONTENT (it must refuse an active embargo — see ' \
                              'CONTENT_ROUTES) or not, then add it to the right list here.'
  end

  # The derivative tier redirects rather than streams, so it carries no
  # ProxyUnbuffered and the sweep above cannot see it. Named explicitly so it
  # is not forgotten on the strength of that.
  it 'keeps the embargo gate on the derivative redirect, which does not stream' do
    source = Rails.root.join('app/controllers/derivative_downloads_controller.rb').read
    expect(source).to include('deny_if_embargoed!')
  end

  # The two packers take the CALLER's right, not the set owner's or the queue
  # owner's. Getting this backwards is what made the set ZIP identical for an
  # anonymous requester and the owner.
  # The caller is `effective_user`: during a View-as session that is the identity
  # being stood in for, which is how every single-file route resolves too, so the
  # file and the archive give an admin one answer rather than two.
  it 'derives each packer\'s bypass right from the caller' do
    aggregate_failures do
      %w[set_downloads_controller queue_downloads_controller].each do |name|
        source = Rails.root.join("app/controllers/#{name}.rb").read
        expect(source).to include('bypass_embargo: bypass_embargo?'),
                          "#{name} must pass a bypass right to its packer"
        expect(source).to match(/def bypass_embargo\?.*effective_user/m),
                          "#{name}'s bypass right must come from the caller (effective_user), not the owner"
      end
    end
  end
end
