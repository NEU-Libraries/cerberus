# frozen_string_literal: true

# The Showcase category choice on the Work Edit page: move a published Work to
# another genre showcase of the same community. See docs/discovery.md.
module WorkShowcaseCategory
  extend ActiveSupport::Concern

  SHOWCASE_REFUSED = 'The showcase category was not changed.'

  private

    # State for the choice. Offered to the Work's depositor and to admins, and
    # only for a Work that is already in a genre showcase.
    def load_showcase_category!(work)
      @showcase = showcase_editor?(work) ? WorkShowcase.call(scope: self, work_noid: params[:id]) : nil
      @showcase_genres = @showcase ? offered_genres(@showcase) : []
    end

    # Add before remove: a failure between the two leaves the Work in both
    # showcases, which an admin can see and fix, never in neither.
    def apply_showcase_category!
      genre = params.dig(:work, :showcase_genre).presence
      return if genre.nil?

      work = AtlasRb::Work.find(params[:id])
      placement = showcase_editor?(work) && WorkShowcase.call(scope: self, work_noid: params[:id])
      return if !placement || genre == placement.genre
      return flash[:alert] = SHOWCASE_REFUSED unless offered_genres(placement).include?(genre)

      swap_showcase(work, placement, genre)
    end

    def swap_showcase(work, placement, genre)
      AtlasRb::System::Work.add_linked_member(work.id, placement.options[genre], on_behalf_of: work.depositor)
      AtlasRb::System::Work.remove_linked_member(work.id, placement.showcase_noid, on_behalf_of: work.depositor)
      record_showcase_move(work, placement, genre, outcome: 'promoted')
      flash[:notice] = %(Moved to the “#{genre}” showcase.)
    rescue AtlasRb::ForbiddenError, AtlasRb::LinkedMemberError, AtlasRb::StaleResourceError => e
      Rails.logger.warn("[showcase] category change for work #{work.id} to #{genre} failed: #{e.class}: #{e.message}")
      record_showcase_move(work, placement, genre, outcome: 'refused')
      flash[:alert] = SHOWCASE_REFUSED
    end

    # Like a deposit's promotion, every move reaches the admin ledger.
    def record_showcase_move(work, placement, genre, outcome:)
      AdminNotice.create!(
        kind:         'showcase_promotion',
        subject:      outcome == 'refused' ? 'Showcase move refused' : %(Moved to the “#{genre}” showcase),
        actor_nuid:   current_user&.nuid,
        subject_noid: work.id,
        payload:      { outcome: outcome, reason: outcome == 'refused' ? 'atlas_forbidden' : nil,
                        showcase_noid: placement.options[genre], community_noid: placement.community_noid,
                        community_name: placement.community_title, work_title: work.title,
                        genre: genre, previous_genre: placement.genre }
      )
    end

    # Staff load theses, so a depositor is never offered that genre, as at deposit.
    def offered_genres(placement)
      FeaturedContent.genre_labels.select do |genre|
        next false unless placement.options.key?(genre)

        genre == placement.genre || effective_user&.admin? || FeaturedContent::STAFF_ONLY.exclude?(genre)
      end
    end

    # Atlas requires the depositor to own the Work, so an admin moves it on the
    # depositor's behalf; nobody else can.
    def showcase_editor?(work)
      effective_user&.admin? || (effective_user&.nuid.present? && effective_user.nuid == work&.depositor)
    end
end
