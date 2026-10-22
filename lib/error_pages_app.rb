# frozen_string_literal: true

# The exceptions app. Error pages route through ErrorsController so they share
# the application layout, and that layout reads the database session and Atlas.
# An outage of either can therefore fail the error page as well. When it does,
# this serves a static page instead of Rails' plain-text failsafe.
# See docs/outages.md.
class ErrorPagesApp
  # Not public/: Rails serves that directory ahead of the routes, so a page there
  # would shadow the routed page at the same path.
  ROOT = Pathname.new(__dir__).join('error_pages')

  # Any status without a page of its own lands here: if the routed page failed,
  # something it depends on is down, which is what this page says.
  FALLBACK_STATUS = 503

  def self.page(status)
    path = ROOT.join("#{status}.html")
    path.exist? ? path : ROOT.join("#{FALLBACK_STATUS}.html")
  end

  def initialize(routed)
    @routed = routed
  end

  def call(env)
    @routed.call(env)
  rescue StandardError => e
    Rails.logger.error("[error pages] the routed page failed, serving the static one: #{e.class}: #{e.message}")
    static_page(env)
  end

  private

    def static_page(env)
      status = env['PATH_INFO'].to_s.delete_prefix('/').to_i
      status = 500 unless status.between?(400, 599)
      [status, { 'content-type' => 'text/html; charset=utf-8' }, [self.class.page(status).read]]
    end
end
