# frozen_string_literal: true

# Shared typeahead JSON for the user-directory pickers — inbox recipients, set
# sharing, and admin impersonation all search the same Atlas directory and
# render the same `[{ nuid:, name: }]` shape.
#
# Atlas's directory excludes guest/anonymous/system roles server-side and caps
# results at 10; `nuid:` drops the requesting user from their own results. That
# scoping is exactly right for every consumer: you don't message, share with, or
# impersonate yourself or a non-human principal.
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

      AtlasRb::User.search(query, nuid: current_user.nuid)
                   .map { |user| { nuid: user['nuid'], name: NuidResolver.prettify(user['name']) } }
                   .uniq { |result| result[:nuid] }
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.error("#{self.class.name}#recipients: #{e.class} #{e.message}")
      []
    end
end
