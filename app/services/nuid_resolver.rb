# frozen_string_literal: true

# Cached NUID → display-name resolution over the Atlas user directory.
# Caching and Namae prettification live here by design — the atlas_rb
# binding is a thin pass-through and Atlas returns names as stored
# ("Family, Given"); presentation is Cerberus's job.
#
# Unresolvable NUIDs (unknown, or excluded roles — Atlas's directory hides
# guest/anonymous/system and the two are indistinguishable by design) fall
# back to the raw NUID so callers always get something renderable.
class NuidResolver
  CACHE_TTL = 12.hours

  # Batch resolve. @return [Hash{String => String}] nuid => display name.
  def self.names_for(nuids)
    nuids = nuids.compact.uniq
    return {} if nuids.empty?

    cached = Rails.cache.read_multi(*nuids.map { |n| cache_key(n) })
                  .transform_keys { |key| key.split('/').last }
    cached.merge(fetch_names(nuids - cached.keys))
  end

  def self.name_for(nuid)
    names_for([nuid])[nuid]
  end

  # "Family, Given" (or any Namae-parsable form) → "Given Family".
  # Unparsable input passes through untouched.
  def self.prettify(name)
    parsed = Namae.parse(name.to_s)[0]
    return name if parsed.blank?

    [parsed.given, parsed.family].compact.join(' ').presence || name
  end

  def self.fetch_names(nuids)
    return {} if nuids.empty?

    found = AtlasRb::User.resolve(nuids, nuid: Current.nuid)
                         .to_h { |user| [user['nuid'], prettify(user['name'])] }
    found.each { |nuid, name| Rails.cache.write(cache_key(nuid), name, expires_in: CACHE_TTL) }
    # Atlas silently drops unresolvables — backfill so every key resolves.
    # Misses are deliberately not cached: a user provisioned a minute later
    # should resolve without waiting out the TTL.
    nuids.index_with { |nuid| found[nuid] || nuid }
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error("NuidResolver: #{e.class} #{e.message}")
    nuids.index_with { |nuid| nuid }
  end
  private_class_method :fetch_names

  def self.cache_key(nuid)
    "nuid_resolver/#{nuid}"
  end
  private_class_method :cache_key
end
