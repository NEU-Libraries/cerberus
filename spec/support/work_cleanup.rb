# frozen_string_literal: true

# Removes the Works a spec file leaves in one of the two stuck states.
#
# A Work created and never completed stays `in_progress` for the rest of the run,
# and one marked incomplete stays flagged. Both are exactly what the admin triage
# registry lists, so a file that creates Works and walks away is quietly seeding
# another file's fixtures. The registry's own specs then measure how much the rest
# of the suite left behind rather than what the filter does, and they change
# verdict as the suite grows past a page.
#
# Purges by STATE rather than by tracked id, so it also clears what a file that
# never opted in left behind. `after(:all)` at the TOP level of a file is the place
# for it: every example in that file is finished by then, and files run one at a
# time, so nothing else is holding one of these.
#
# A purge, not a tombstone — a tombstoned Work is still a Work, and still answers
# the operator filter. Purging is admin-only, hence the fixture admin's NUID.
module WorkCleanup
  PURGE_NUID = '000000004'

  # Atlas answers a DELETE on a Work with 204, and the raise-on-error middleware
  # does not cover that path, so the status has to be read rather than rescued.
  # 404 counts as done: a Work already gone is the state this is trying to reach.
  PURGED_STATUSES = [200, 202, 204, 404].freeze

  # Pages defensively rather than asking for one huge page, because the page size
  # Atlas honours is its business, not this helper's. Capped so a paging change
  # cannot turn cleanup into an endless loop.
  PAGE_LIMIT = 20
  PER_PAGE = 100

  # @param nuid [String] the acting admin's NUID.
  # @return [Integer] how many Works were purged.
  def purge_stuck_works!(nuid: PURGE_NUID)
    ids = stuck_work_ids(nuid: nuid)
    ids.each { |id| purge_work(id, nuid: nuid) }
    ids.size
  end

  private

    # Atlas's operator filter rather than Solr: it answers from the record, so a
    # Work whose index write has not landed yet is still found and still cleaned up.
    def stuck_work_ids(nuid:)
      [{ in_progress: true }, { incomplete: true }].flat_map { |state| ids_for(state, nuid: nuid) }.uniq
    end

    def ids_for(state, nuid:)
      ids = []
      (1..PAGE_LIMIT).each do |page|
        works = AtlasRb::Work.list(**state, page: page, per_page: PER_PAGE, nuid: nuid).works
        break if works.blank?

        ids.concat(works.pluck('id'))
        break if works.size < PER_PAGE
      end
      ids
    end

    # Anything other than "gone" is left to raise: a cleanup that swallows its own
    # failures is how the leak reached a page in the first place.
    def purge_work(id, nuid:)
      status = AtlasRb::Admin::Work.destroy(id, confirm: :i_understand, nuid: nuid).status
      return if PURGED_STATUSES.include?(status)

      raise "WorkCleanup could not purge Work #{id}: Atlas answered #{status}"
    end
end

RSpec.configure { |config| config.include WorkCleanup }
