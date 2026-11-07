# frozen_string_literal: true

# Adds a page of Works to a Set, one Atlas call each, and tells whoever asked
# how it went. A job because a full page is a hundred calls, which a request
# deadline would cut short. See docs/sets.md ("Adding a page of results").
class SetBulkAddJob < ApplicationJob
  queue_as :default

  def perform(set_noid:, work_ids:)
    compilation = AtlasRb::Compilation.find(set_noid)
    return if compilation.nil?

    failures = []
    work_ids.each do |noid|
      AtlasRb::Compilation.add_included_work(set_noid, noid)
    rescue AtlasRb::Error, Faraday::Error => e
      failures << "Work #{noid}: #{e.message}"
    end

    report(set_noid, compilation['title'], work_ids.size, failures)
  end

  private

    def report(set_noid, title, asked, failures)
      added = asked - failures.size
      works = ->(n) { "#{n} work#{'s' unless n == 1}" }
      counted = failures.empty? ? works.call(added) : "#{added} of #{works.call(asked)}"
      subject = "Added #{counted} to “#{title}”"
      lines = ["#{works.call(added)} from a page of search results #{added == 1 ? 'is' : 'are'} now in “#{title}”."]
      lines += ['', 'These could not be added:', *failures] if failures.any?
      # A path, not a _url: a job has no request to take a host from, and the
      # inbox renders these in-app anyway.
      lines += ['', Rails.application.routes.url_helpers.set_path(set_noid)]
      SystemMessage.deliver(subject: subject, body: lines.join("\n"), to_nuid: Current.nuid)
    end
end
