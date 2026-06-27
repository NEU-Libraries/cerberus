# frozen_string_literal: true

# The Atlas test backend is eventually consistent: a write (create / metadata)
# commits to Postgres, then reindexes Solr asynchronously. A read issued inside
# that race window can momentarily return nil.
#
# The controller `show` specs create a real object and then immediately
# `GET :show`, whose action does `AtlasRb::X.find(params[:id])`. If that read
# lands mid-reindex it returns nil and the action 500s on `nil.tombstoned`.
# Locally the index settles inside the window so the specs pass; CI is slower
# and loses the race — surfacing as a recurring, order-sensitive flake (the
# `…/show … Edit affordance is hidden from a signed-in user who cannot edit`
# examples, which fire the request with no intervening Atlas round-trip to
# absorb the lag).
#
# `wait_for_atlas_visibility` polls the *same* find the controller uses until
# the object resolves, closing the race deterministically without stubbing the
# backend out. Transient reindex errors are treated as "not visible yet" and
# retried; the last one is re-raised if the object never appears.
module AtlasVisibility
  def wait_for_atlas_visibility(klass, id, attempts: 25, interval: 0.1)
    last_error = nil

    attempts.times do
      begin
        found = klass.find(id)
        return found if found
      rescue Faraday::Error, JSON::ParserError => e
        last_error = e
      end
      sleep interval
    end

    raise last_error || "Atlas #{klass}##{id} never became visible after #{attempts} attempts"
  end
end

RSpec.configure { |config| config.include AtlasVisibility }
