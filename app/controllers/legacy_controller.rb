# frozen_string_literal: true

# Redirects an inbound DRS v1 `neu:` pid URL to the v2 object it became at
# migration. See docs/people-and-routing.md.
class LegacyController < ApplicationController
  # 302 while the mapping table is unverified: browsers and intermediaries cache
  # a 301 hard, so a wrong row would outlive the fix.
  REDIRECT_STATUS = :found

  def show
    mapping = LegacyIdentifier.for_pid(params[:pid])
    destination = mapping && destination_for(mapping)
    return render_unknown_pid if destination.nil?

    redirect_to destination, status: REDIRECT_STATUS
  end

  private

    # Rows come from migration tooling outside this app, so an object_type the
    # model's validation never saw can reach here. Returning nil sends it down
    # the same 404 path as an unknown pid instead of raising on a nil path helper.
    def destination_for(mapping)
      case mapping.object_type
      when 'community'  then community_path(mapping.noid)
      when 'collection' then collection_path(mapping.noid)
      when 'work'       then work_path(mapping.noid)
      when 'download'   then download_path(mapping.noid)
      when 'set'        then set_path(mapping.noid)
      else
        Rails.logger.warn(
          "LegacyController: no v2 route for object_type #{mapping.object_type.inspect} " \
          "(pid #{mapping.pid}, noid #{mapping.noid})"
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
