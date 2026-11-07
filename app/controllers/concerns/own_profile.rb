# frozen_string_literal: true

# The NOID of the effective user's own Person, for the header's name link. The
# header renders on every page, so the answer is cached in the session per
# NUID, and a "no Person" answer is cached too. A failed read is not cached.
# See docs/people-and-routing.md.
module OwnProfile
  extend ActiveSupport::Concern

  TTL = 10.minutes

  included do
    helper_method :own_profile_noid
  end

  def own_profile_noid
    nuid = effective_user&.nuid
    return if nuid.blank?
    return @own_profile_noid if defined?(@own_profile_noid)

    @own_profile_noid = cached_profile_noid(nuid)
  end

  private

    def cached_profile_noid(nuid)
      entry = session[:own_profile]
      return entry['noid'] if fresh_entry?(entry, nuid)

      noid = resolve_profile_noid(nuid)
      session[:own_profile] = { 'nuid' => nuid, 'noid' => noid, 'at' => Time.current.to_i }
      noid
    rescue Faraday::Error, AtlasRb::Error, JSON::ParserError => e
      Rails.logger.error("OwnProfile lookup for #{nuid}: #{e.class} #{e.message}")
      nil
    end

    def fresh_entry?(entry, nuid)
      entry.is_a?(Hash) && entry['nuid'] == nuid && entry['at'].to_i > TTL.ago.to_i
    end

    def resolve_profile_noid(nuid)
      Array(AtlasRb::Person.resolve([nuid], nuid: Current.nuid)).first&.[]('id')
    end
end
