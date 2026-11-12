# frozen_string_literal: true

# Redirects an inbound DRS v1 `neu:` pid URL to the v2 object it became at
# migration. See docs/people-and-routing.md.
class LegacyController < ApplicationController
  # 302 while the migration's pids are unverified: browsers and intermediaries
  # cache a 301 hard, so a wrong pid would outlive the fix.
  REDIRECT_STATUS = :found

  def show
    # The system path, because the redirect must resolve for any visitor. The
    # destination page applies the visitor's own read gate.
    holder = AtlasRb::System.find_by_legacy_pid(params[:pid])
    destination = holder && destination_for(holder)
    return render_unknown_pid if destination.nil?

    redirect_to destination, status: REDIRECT_STATUS
  end

  private

    # Atlas can answer a type this app has no route for yet. Returning nil sends
    # it down the same 404 path as an unknown pid instead of raising on a nil
    # path helper.
    def destination_for(holder)
      case holder['type']
      when 'Community'  then community_path(holder['id'])
      when 'Collection' then collection_path(holder['id'])
      when 'Work'       then work_path(holder['id'])
      else
        Rails.logger.warn(
          "LegacyController: no v2 route for type #{holder['type'].inspect} " \
          "(pid #{params[:pid]}, noid #{holder['id']})"
        )
        nil
      end
    end

    # Rendered rather than raised through Authorizable's ResourceNotFound handler,
    # which would name the object from the controller ("the legacy you
    # requested"). What was not found here is a page.
    def render_unknown_pid
      render template: 'errors/not_found', status: :not_found, locals: { obj_type: 'page' }
    end
end
