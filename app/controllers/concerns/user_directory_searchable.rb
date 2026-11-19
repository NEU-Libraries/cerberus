# frozen_string_literal: true

# Shared typeahead JSON for the user-directory pickers — inbox recipients, set
# sharing, and admin impersonation all search the same Atlas directory and
# render the same `[{ nuid:, name: }]` shape.
#
# Atlas's directory excludes guest, anonymous, system and fixity-checker roles
# server-side and caps results at 10. It includes the requesting user, so the
# picker drops them here: you don't message, share with, or impersonate
# yourself or a non-human principal.
#
# One NUID can hold several Atlas accounts (e.g. a staff and a student login),
# which the directory returns as separate rows sharing the same nuid + name.
# These pickers target a person, not an account, so results collapse to one
# entry per NUID.
module UserDirectorySearchable
  extend ActiveSupport::Concern

  private

    # @return [Array<Hash>] prettified directory matches, or [] for a blank
    #   query / unreachable Atlas (fail-soft so the typeahead never 500s).
    def user_directory_results
      query = params[:q].to_s.strip
      return [] if query.blank?

      others_matching(query).map { |user| { nuid: user['nuid'], name: directory_name(user) } }
                            .uniq { |result| result[:nuid] }
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.error("#{self.class.name}#recipients: #{e.class} #{e.message}")
      []
    end

    def others_matching(query)
      me = current_user.nuid
      AtlasRb::User.search(query, nuid: me).reject { |user| user['nuid'] == me }
    end

    # Atlas matches the curated Person name too, so a result found by it must
    # show it. A curated name renders verbatim; only the SSO name is Namae'd.
    def directory_name(user)
      user['display_name'].presence || NuidResolver.prettify(user['name'])
    end
end
