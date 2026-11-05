# frozen_string_literal: true

# The Showcase section on the Work Edit page: move a published Work to another
# genre in every community it appears in, or take it out of one community.
# See docs/discovery.md.
module WorkShowcaseCategory
  extend ActiveSupport::Concern

  SHOWCASE_REFUSED = 'The showcase category was not changed.'
  SHOWCASE_REMOVE_REFUSED = 'The work was not removed from that showcase.'

  # Takes the Work out of one community's showcase and leaves it in the others.
  def remove_showcase
    work = AtlasRb::Work.find(params[:id])
    placement = removable_placement(work)
    return back_to_showcase(alert: SHOWCASE_REMOVE_REFUSED) unless placement

    unlink_showcase(work, placement)
  end

  private

    # Only one of this Work's own showcases, and only for its depositor or an admin.
    def removable_placement(work)
      return nil unless showcase_editor?(work)

      current_placements.find { |placement| placement.showcase_noid == params[:showcase_id].to_s }
    end

    def unlink_showcase(work, placement)
      AtlasRb::System::Work.remove_linked_member(work.id, placement.showcase_noid, on_behalf_of: work.depositor)
      record_showcase_change(work, placement, outcome: 'removed')
      back_to_showcase(notice: %(Removed from #{placement.community_title}’s “#{placement.genre}” showcase.))
    rescue AtlasRb::ForbiddenError, AtlasRb::LinkedMemberError, AtlasRb::StaleResourceError => e
      Rails.logger.warn("[showcase] removal of work #{work.id} from #{placement.showcase_noid} failed: #{e.message}")
      record_showcase_change(work, placement, outcome: 'refused')
      back_to_showcase(alert: SHOWCASE_REMOVE_REFUSED)
    end

    # State for the section. Offered to the Work's depositor and to admins, and
    # only for a Work that is already in a genre showcase.
    def load_showcase_category!(work)
      @showcases = showcase_editor?(work) ? current_placements : []
      @showcase_genres = offered_genres(@showcases)
    end

    # A Work has one category, so a move applies to every community it is in.
    def apply_showcase_category!
      genre = params.dig(:work, :showcase_genre).presence
      return if genre.nil?

      work = AtlasRb::Work.find(params[:id])
      placements = showcase_editor?(work) ? current_placements : []
      moves = placements.reject { |placement| placement.genre == genre }
      return if moves.empty?
      return flash[:alert] = SHOWCASE_REFUSED unless offered_genres(placements).include?(genre)

      failed = moves.reject { |placement| swap_showcase(work, placement, genre) }
      report_moves(genre, failed)
    end

    def current_placements
      @current_placements ||= WorkShowcase.call(scope: self, work_noid: params[:id])
    end

    # Add before remove: a failure between the two leaves the Work in both
    # showcases, which an admin can see and fix, never in neither.
    def swap_showcase(work, placement, genre)
      AtlasRb::System::Work.add_linked_member(work.id, placement.options[genre], on_behalf_of: work.depositor)
      AtlasRb::System::Work.remove_linked_member(work.id, placement.showcase_noid, on_behalf_of: work.depositor)
      record_showcase_change(work, placement, outcome: 'promoted', genre: genre)
      true
    rescue AtlasRb::ForbiddenError, AtlasRb::LinkedMemberError, AtlasRb::StaleResourceError => e
      Rails.logger.warn("[showcase] category change for work #{work.id} to #{genre} failed: #{e.class}: #{e.message}")
      record_showcase_change(work, placement, outcome: 'refused', genre: genre)
      false
    end

    def report_moves(genre, failed)
      return flash[:notice] = %(Moved to the “#{genre}” showcase.) if failed.empty?

      flash[:alert] = "The showcase category was not changed in #{failed.map(&:community_title).to_sentence}."
    end

    # Like a deposit's promotion, every move and removal reaches the admin ledger.
    # `genre` is where a move went; a removal has none.
    def record_showcase_change(work, placement, outcome:, genre: nil)
      AdminNotice.create!(
        kind:         'showcase_promotion',
        subject:      showcase_change_subject(placement, outcome, genre),
        actor_nuid:   current_user&.nuid,
        subject_noid: work.id,
        payload:      showcase_change_payload(work, placement, outcome, genre)
      )
    end

    def showcase_change_payload(work, placement, outcome, genre)
      { outcome: outcome, reason: outcome == 'refused' ? 'atlas_forbidden' : nil,
        showcase_noid: genre ? placement.options[genre] : placement.showcase_noid,
        community_noid: placement.community_noid, community_name: placement.community_title,
        work_title: work.title, genre: genre || placement.genre, previous_genre: genre && placement.genre }
    end

    def showcase_change_subject(placement, outcome, genre)
      return 'Showcase change refused' if outcome == 'refused'
      return %(Removed from the “#{placement.genre}” showcase) if outcome == 'removed'

      %(Moved to the “#{genre}” showcase)
    end

    # The categories every placement's community has, so a move can land in all
    # of them. Staff load theses, so a depositor is never offered that genre.
    def offered_genres(placements)
      return [] if placements.empty?

      current = placements.map(&:genre)
      FeaturedContent.picker_order(FeaturedContent.genre_labels).select do |genre|
        placements.all? { |placement| placement.options.key?(genre) } && genre_for_reader?(genre, current)
      end
    end

    def genre_for_reader?(genre, current)
      current.include?(genre) || effective_user&.admin? || FeaturedContent::STAFF_ONLY.exclude?(genre)
    end

    # Atlas requires the depositor to own the Work, so an admin moves it on the
    # depositor's behalf; nobody else can.
    def showcase_editor?(work)
      effective_user&.admin? || (effective_user&.nuid.present? && effective_user.nuid == work&.depositor)
    end

    def back_to_showcase(flash_opts)
      redirect_to edit_work_path(params[:id]), **flash_opts
    end
end
