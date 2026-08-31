# frozen_string_literal: true

# Shepherds inbound DRS v1 URLs to the v2 object they became at migration.
#
# v1 ran on Fedora, so every object carried a `neu:` pid; v2 mints fresh NOIDs
# and does not carry the pid forward. Ten years of `neu:`-pid URLs live in
# published papers, syllabi, finding aids, catalogue records and the search
# index, and without this they all land on a 404. A hit redirects; a pid that
# never existed 404s. There is no `410 Gone` branch, because every v1 object
# migrates — including the hand-rolled integer pids, one of which (`neu:1`) is
# the root Northeastern University Community.
#
# The inbound path prefix is only how the URL gets caught. `object_type` on the
# mapping row decides the destination, because the prefixes do not correspond:
# a v1 CoreFile at `/files/:pid` is a v2 Work at `/works/:noid`. That also means
# a request need not ask Atlas what kind of thing a NOID names, which matters
# when the caller is a crawler working through a decade of links.
class LegacyController < ApplicationController
  # 302 while the mapping table is unverified. 301 is the intended end state —
  # it is what transfers search-index equity to the new URLs — but browsers and
  # intermediaries cache it hard, so a wrong row would outlive the fix. Flip
  # this to `:moved_permanently` once the migration's mappings are confirmed.
  REDIRECT_STATUS = :found

  def show
    mapping = LegacyIdentifier.for_pid(params[:pid])
    destination = mapping && destination_for(mapping)
    return render_unknown_pid if destination.nil?

    redirect_to destination, status: REDIRECT_STATUS
  end

  private

    # The v2 path for a migrated object. Returns nil for a type this app has no
    # route for, which is a defended case rather than a theoretical one: the
    # rows come from migration tooling outside this app, so a value the model's
    # validation never saw can reach here. Returning nil sends it down the same
    # 404 path as an unknown pid instead of raising on a nil path helper.
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

    # Rendered rather than raised through Authorizable's `ResourceNotFound`
    # handler, which names the object from the controller ("the legacy you
    # requested"). What was not found here is a page, and the template's own
    # default says exactly that.
    def render_unknown_pid
      render template: 'errors/not_found', status: :not_found, locals: { obj_type: 'page' }
    end
end
