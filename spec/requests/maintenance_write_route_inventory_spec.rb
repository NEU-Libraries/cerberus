# frozen_string_literal: true

require 'rails_helper'

# The rule this file exists to keep: **while the repository is in a read-only
# maintenance window, a request either writes nothing or is refused.**
#
# MaintenanceGate keys on the HTTP method, so the refusal needs no maintenance
# per route — a new controller inherits it. The allowlist is the part that rots.
# Every entry on it is a claim that the action writes nothing but the Cerberus
# session row, and that claim can quietly stop being true: an action grows an
# Atlas call, or a new non-GET route arrives that looks session-shaped and is
# not.
#
# This spec is the tripwire. It asserts the inventory of non-GET routes is
# exactly what we have classified. Add one and this fails until you come here
# and say which kind it is.
#
# Atlas is the boundary and refuses the write whatever this gate does, so a
# wrong entry here is a bad error page rather than lost data. A wrong entry in
# the other direction — refusing a read — is a broken repository during a
# window, which is why catalog#index sits on the list.
RSpec.describe 'Maintenance write-route inventory', type: :request do
  # Reach no Atlas write and no Cerberus table. These stay open while the
  # window is: reads keep working, so the session bookkeeping behind them must
  # keep working too.
  SESSION_ONLY = {
    'devise/sessions#create'       => 'sign-in reads Atlas (GET /user) and writes a session row',
    'devise/sessions#destroy'      => 'sign-out clears the session',
    'accounts#switch'              => 'records which account is acting, in the session',
    'download_queue#create'        => 'the download queue lives in the session',
    'download_queue#destroy'       => 'as above',
    'download_queue#destroy_all'   => 'as above',
    'admin/impersonations#destroy' => 'the session is torn down before the end event is ' \
                                      'emitted, so leaving must always work',
    'catalog#index'                => 'Blacklight routes search at POST as well as GET',
    'catalog#track'                => 'stores the result counter in the session',
    'atlas#process_login'          => 'the NUID sign-in shim; reads Atlas like devise does'
  }.freeze

  # The window's own off-switch. Exempt in its own controller rather than on the
  # list above, because a gated close route plus a fail-closed cache read means
  # an open window nobody can shut from the browser.
  OFF_SWITCH = {
    'admin/maintenance#open_window'  => 'opens the window; the operator door',
    'admin/maintenance#close_window' => 'closes it — must stay reachable WHILE the window is open'
  }.freeze

  # Everything else. Each of these reaches an Atlas write, a Cerberus table, or
  # a background job that will do one, so each is refused. Listed by controller
  # rather than by action: the rule is about the surface, not the verb.
  # admin/impersonations appears here AND in SESSION_ONLY: exiting is session-only,
  # while STARTING a session (view_as or act_as) records an AuditEvent in Atlas
  # and is refused. The exact-action list is consulted first, so both hold.
  REFUSED_CONTROLLERS = %w[
    accounts admin/associations admin/files admin/groups admin/impersonations
    admin/linked_members
    admin/loaders admin/people admin/reindex admin/reparent admin/tombstones
    atlas atlas_tokens collections communities loads messages sets works xml
  ].freeze

  def callback_filters(controller)
    controller._process_action_callbacks.map(&:filter)
  end

  def non_get_actions
    Rails.application.routes.routes.filter_map do |route|
      verb = route.verb.to_s
      next if verb.blank? || verb.match?(/\A(GET|HEAD)\z/)

      controller = route.defaults[:controller]
      next if controller.blank?

      "#{controller}##{route.defaults[:action]}"
    end.uniq
  end

  it 'has classified every non-GET route' do
    unclassified = non_get_actions.reject do |action|
      SESSION_ONLY.key?(action) || OFF_SWITCH.key?(action) ||
        REFUSED_CONTROLLERS.include?(action.split('#').first)
    end

    expect(unclassified).to be_empty,
                            "Unclassified non-GET route(s): #{unclassified.join(', ')}.\n" \
                            'Decide whether each writes nothing but the session (add it to ' \
                            'SESSION_ONLY and to MaintenanceGate::SESSION_ONLY_WRITES) or ' \
                            'should be refused during a window (add its controller to ' \
                            'REFUSED_CONTROLLERS).'
  end

  it 'exempts exactly the actions this inventory says are session-only' do
    expect(MaintenanceGate::SESSION_ONLY_WRITES).to match_array(SESSION_ONLY.keys)
  end

  # The off-switch's exemption is structural, not a list entry. If a refactor
  # ever removes that skip, an open window becomes unclosable from the browser,
  # so assert the shape directly rather than trusting the allowlist.
  it 'exempts the maintenance surface in its own controller, not on the allowlist' do
    expect(MaintenanceGate::SESSION_ONLY_WRITES).not_to include(*OFF_SWITCH.keys)

    expect(callback_filters(ApplicationController)).to include(:block_writes_in_maintenance!)
    expect(callback_filters(Admin::MaintenanceController)).not_to include(:block_writes_in_maintenance!)
  end

  it 'refuses every action it has not classified as session-only' do
    refused = non_get_actions.select do |action|
      REFUSED_CONTROLLERS.include?(action.split('#').first) && !SESSION_ONLY.key?(action)
    end

    expect(refused).not_to be_empty
    expect(refused & MaintenanceGate::SESSION_ONLY_WRITES).to be_empty
  end
end
