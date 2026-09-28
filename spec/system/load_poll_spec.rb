# frozen_string_literal: true

require 'rails_helper'

# The report frame that follows a running batch to its finish. The job chain
# behind it has its own request specs; what those cannot see is the frame — that
# it polls at all, that it swaps in place rather than navigating, and that it
# stops once the report is terminal. No background worker is needed to test any
# of that, only a status that changes while the page is open.
RSpec.describe 'Load report polling', :browser, type: :system do
  let!(:loader) do
    Loader.create!(slug: 'poll-spec', display_name: 'XML Metadata Loader',
                   group: 'northeastern:drs:repository:loaders:poll-spec',
                   root_collection: 'neu:root', kind: :xml)
  end

  let!(:report) do
    LoadReport.create!(loader: loader, source_filename: 'batch.zip',
                       status: :processing, started_at: Time.current)
  end

  let(:before_visit) { nil }

  before do
    before_visit
    sign_in_as(AtlasFixtures::ADMIN_NUID)
    visit loader_load_path(loader.slug, report)
  end

  it 'carries the poll flag as a real attribute while the load runs' do
    expect(page).to have_content('Processing')
    # HAML drops a data attribute whose value is boolean false, which takes the
    # flag off the element entirely and leaves the controller reading undefined
    # — that is, treating a running load as finished. The view stringifies the
    # value for that reason, and this is the assertion that holds it there.
    expect(poll_flag).to eq('false')
  end

  it 'replaces the frame in place when the status changes' do
    expect(page).to have_content('Processing')
    mark_page

    report.update!(status: :completed, finished_at: Time.current)

    # The poll interval is three seconds, which outruns the default wait.
    expect(page).to have_content('Completed', wait: 15)
    expect(page_marked?).to be(true)
    expect(poll_flag).to eq('true')
  end

  # Only a fresh frame's connect() schedules the next poll, and a failed reload
  # leaves the old frame in place, so without a retry one bad response ended
  # polling for good. The second call to show is the first poll; it fails.
  describe 'after a failed poll' do
    let(:before_visit) do
      calls = 0
      allow_any_instance_of(LoadsController).to receive(:show).and_wrap_original do |original, *args|
        calls += 1
        next original.call(*args) unless calls == 2

        original.receiver.render plain: 'upstream timeout', status: :internal_server_error
      end
    end

    it 'keeps polling and still reaches Completed, without blanking the report' do
      expect(page).to have_content('Processing')
      report.update!(status: :completed, finished_at: Time.current)

      expect(page).to have_content('Completed', wait: 20)
      expect(page).to have_no_content('Content missing')
    end
  end

  # --- helpers ---------------------------------------------------------------

  def poll_flag
    find("[data-controller='load-poll']", visible: :all)['data-load-poll-terminal-value']
  end

  # A value on window survives a frame swap and does not survive a navigation,
  # which is how the spec tells one from the other.
  def mark_page = page.execute_script('window.__loadPollMark = true')

  def page_marked? = page.evaluate_script('window.__loadPollMark === true')
end
