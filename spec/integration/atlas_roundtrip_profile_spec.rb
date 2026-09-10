# frozen_string_literal: true

require 'rails_helper'

# A measurement harness, not an assertion suite.
#
# atlas_rb brackets every outbound Atlas request in an ActiveSupport::Notifications
# event named `request.atlas_rb`, carrying the Faraday env as its payload and
# folding an internally-redirecting call's hop into one event. That lets a host
# count and time Atlas round-trips per surface without reaching into the gem — an
# N+1-over-HTTP detector. Atlas exercises the properties of the event itself in
# its own spec/integration/instrumentation_atlas_rb_spec.rb; this drives real
# Cerberus pages with a subscriber attached and prints what each one costs.
#
# Tagged :profile and excluded from a default run (see rails_helper) because it
# reports rather than asserts. Run it deliberately:
#
#   docker exec -e SMOKE=1 -w <worktree> cerberus-web-1 \
#     bundle exec rspec spec/integration/atlas_roundtrip_profile_spec.rb --tag profile
#
# These are local-stack numbers: Atlas, Solr and Postgres all in Docker on one
# host, no network latency, no production data volume. Read the call *counts* as
# the durable signal and the milliseconds as indicative only. Solr time is a
# blind spot — neither rsolr nor Blacklight emits notifications, so it lands in
# WALL ms without being attributable.
RSpec.describe 'Atlas round-trip profile', :profile, type: :request do
  include Devise::Test::IntegrationHelpers

  ATLAS_EVENT = 'request.atlas_rb'
  # Accumulated across the examples in this file and drained in after(:all), so
  # it cannot be frozen.
  RESULTS = [] # rubocop:disable Style/MutableConstant

  let(:admin_nuid) { '000000004' }
  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: admin_nuid, role: 'admin')
  end

  # One community → collection → work chain with a real Blob attached. Built once
  # for the file: the harness measures the GETs, not the setup.
  before(:all) do
    # The ambient acting principal atlas_rb signs with (config.default_nuid reads
    # Current.nuid). Setup calls taking no explicit nuid: need it — notably
    # Person.create, whose actor is the ambient one by design.
    Current.nuid = '000000004'
    @community  = AtlasRb::Community.create(nil, fixture_path('community-mods.xml'), nuid: '000000004')
    @collection = AtlasRb::Collection.create(@community.id, fixture_path('collection-mods.xml'), nuid: '000000004')
    @work = build_work
    @person = any_person
  end

  after(:all) do
    report(RESULTS)
    RESULTS.clear
  end

  def self.fixture_path(name) = Rails.root.join('spec/fixtures/files', name).to_s
  delegate :fixture_path, to: :class

  def build_work
    created = AtlasRb::Work.create(@collection.id, fixture_path('work-mods.xml'), nuid: '000000004')
    AtlasRb::Blob.create(created.id, fixture_path('image.png'), 'image.png', nuid: '000000004')
    AtlasRb::Work.complete(created.id, nuid: '000000004')
    AtlasRb::Work.find(created.id, nuid: '000000004')
  end

  # Any Person will do — the harness only needs a real id to open the edit page
  # on. Person.list rows carry it; Person.resolve digests do not.
  def any_person
    AtlasRb::Person.list(per_page: 1, nuid: '000000004').first ||
      AtlasRb::Person.create(nuid: '000000099', display_name: 'Profile Harness Person')
  end

  # Person rows key the id as `id`, not `noid`.
  def person_id = @person['noid'].presence || @person['id']

  # A first request in the process pays connection setup and Rails lazy-loading,
  # which would otherwise land entirely on whichever surface was measured first.
  before do
    sign_in admin
    get root_path
  end

  it 'profiles the public read surfaces' do
    profile('GET / (home)')             { get root_path }
    profile('GET /catalog?q= (search)') { get search_catalog_path(q: 'a') }
    profile('GET /works/:id (show)')    { get work_path(@work.id) }
    profile('GET /collections/:id')     { get collection_path(@collection.id) }
    profile('GET /communities/:id')     { get community_path(@community.id) }
    profile('GET /people')              { get people_path }
  end

  it 'profiles the authenticated and admin surfaces' do
    profile('GET /works/:id/edit')        { get edit_work_path(@work.id) }
    profile('GET /works/:id/downloads')   { get downloads_work_path(@work.id) }
    profile('GET /my_drs')                { get my_drs_path }
    profile('GET /inbox')                 { get messages_path }
    profile('GET /admin/files/manage')    { get admin_files_manage_path(work_id: @work.id) }
    profile('GET /admin/people/:id/edit') { get edit_admin_person_path(person_id) }
    profile('GET /admin/ledger')          { get admin_ledger_path }
    profile('GET /admin/deposit_triage')  { get admin_deposit_triage_path }
  end

  # The loader index is the one surface whose cost is ActiveRecord rather than
  # Atlas: it renders a progress summary per row off LoadReport's status tally.
  it 'profiles a DB-bound surface at a realistic row count' do
    loader = seeded_loader(rows: 10)

    profile('GET /loaders/:slug/loads (10 rows)') { get loader_loads_path(loader) }
  end

  def seeded_loader(rows:)
    loader = Loader.create!(slug: 'profile-iptc', display_name: 'Profile Loader',
                            group: 'northeastern:drs:repository:loaders:profile',
                            root_collection: @collection.id, kind: :iptc)
    rows.times do |i|
      report = LoadReport.create!(loader: loader, source_filename: "batch-#{i}.zip",
                                  parent_collection_id: @collection.id, status: :completed)
      create_list(:iptc_ingest, 4, load_report: report, status: :completed)
      create(:iptc_ingest, load_report: report, status: :failed)
    end
    loader
  end

  # Does the Work show page's concurrency pay off on this stack? Times the same
  # four reads serially and through parallel_atlas_reads. A single-process Atlas
  # serving four concurrent requests may contend enough to erase the win, which
  # is a property of the environment rather than of the code.
  it 'compares serial and concurrent reads of the same four calls' do
    tasks = four_show_reads(@work.id)
    tasks.each_value(&:call) # warm

    serial_ms = timed { tasks.each_value(&:call) }
    parallel_ms = timed { concurrency_probe.send(:parallel_atlas_reads, tasks) }

    puts format("\nFOUR-READ COMPARISON (the Work show page's concurrent block)" \
                "\n    serial   %8.1f ms\n    parallel %8.1f ms\n    speed-up %8.2fx\n",
                serial_ms, parallel_ms, serial_ms / parallel_ms)
  end

  def four_show_reads(id)
    { mods:         -> { AtlasRb::Work.mods(id, 'html', nuid: admin_nuid) },
      files:        -> { AtlasRb::Work.assets(id, nuid: admin_nuid) },
      file_sets:    -> { AtlasRb::Work.file_sets(id, nuid: admin_nuid) },
      associations: -> { AtlasRb::Work.associations(id, nuid: admin_nuid) } }
  end

  def timed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  end

  # parallel_atlas_reads is a private controller-concern method; borrow it rather
  # than reimplementing the thread handling here.
  def concurrency_probe
    @concurrency_probe ||= Class.new { include ParallelAtlasReads }.new
  end

  # Count and time everything the block sends to Atlas, plus its ActiveRecord
  # queries and its wall time. Subscriptions are torn down in ensure so they
  # cannot leak into a later measurement.
  def profile(label, &block)
    calls = []
    queries = []
    subs = [subscribe_atlas(calls), subscribe_sql(queries)]

    wall_ms = timed(&block)

    RESULTS << { label: label, status: response.status, wall_ms: wall_ms,
                 calls: calls, queries: queries.size }
  ensure
    subs.each { |sub| ActiveSupport::Notifications.unsubscribe(sub) }
  end

  def subscribe_atlas(sink)
    ActiveSupport::Notifications.subscribe(ATLAS_EVENT) do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      sink << { method: event.payload.method.to_s.upcase, path: event.payload.url.path, ms: event.duration }
    end
  end

  def subscribe_sql(sink)
    ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      sink << event unless %w[SCHEMA TRANSACTION].include?(event.payload[:name])
    end
  end

  # rubocop:disable Style/FormatStringToken
  # The report is a column-aligned table. Annotated tokens (%<name>s) would make
  # each format string unreadable against the header row it has to line up with.
  def report(rows)
    return if rows.empty?

    puts "\n#{'=' * 100}"
    puts "ATLAS ROUND-TRIP PROFILE — Cerberus #{Rails.root.join('.version').read.strip}"
    puts '=' * 100
    print_summary(rows)
    print_detail(rows)
    puts "\n#{'=' * 100}\n"
  end

  # Ranked by round-trips, since that is the number that survives a change of
  # hardware.
  def print_summary(rows)
    puts 'SURFACE                                  HTTP   CALLS  ATLAS ms   WALL ms      DB'
    puts '-' * 100
    rows.sort_by { |row| [-row[:calls].size, -row[:wall_ms]] }.each do |row|
      puts format('%-38s %6d %7d %9.1f %9.1f %7d', row[:label], row[:status], row[:calls].size,
                  row[:calls].sum { |call| call[:ms] }, row[:wall_ms], row[:queries])
    end
  end

  # Only surfaces making more than one call, since that is where an HTTP N+1 or a
  # duplicate fetch shows itself.
  def print_detail(rows)
    puts "\n#{'-' * 100}\nCALL DETAIL (surfaces making more than one Atlas request)\n#{'-' * 100}"
    rows.select { |row| row[:calls].size > 1 }.each do |row|
      puts "\n#{row[:label]}"
      row[:calls].each { |call| puts format('    %-6s %-58s %8.1f ms', call[:method], call[:path], call[:ms]) }
      print_repeats(row[:calls])
    end
  end

  def print_repeats(calls)
    calls.group_by { |call| [call[:method], call[:path]] }
         .select { |_, group| group.size > 1 }
         .each { |(method, path), group| puts format('    ** %s %s repeated %d times', method, path, group.size) }
  end
  # rubocop:enable Style/FormatStringToken
end
