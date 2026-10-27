# frozen_string_literal: true

# Turns a backing service that stopped answering into a 503 that names what the
# reader lost, rather than the generic 500 page. See docs/outages.md.
module InfrastructureOutages
  extend ActiveSupport::Concern

  included do
    # rescue_from matches with ===, and SystemCallError's === matches on errno
    # alone, so a refusal from any socket lands here. Outage.for does not
    # claim it, and it goes on to the error page as before.
    rescue_from(*Outage.handled_errors) do |error|
      outage = Outage.for(error)
      raise error if outage.nil?

      render_outage(outage, error)
    end
  end

  private

    def render_outage(outage, error = nil)
      Rails.logger.error("[outage] #{outage.key}: #{error.class}: #{error.message}") if error
      response.headers['Retry-After'] = Outage::RETRY_AFTER.to_s

      # The layout signs the reader in from the database session, so rendering
      # it during a database outage would raise again inside this handler.
      if outage.key == :repository
        return render file: ErrorPagesApp.page(503), layout: false, status: :service_unavailable,
                      content_type: 'text/html'
      end

      render template: 'errors/outage', formats: [:html], status: :service_unavailable,
             layout: 'application', locals: { outage: outage }
    end
end
