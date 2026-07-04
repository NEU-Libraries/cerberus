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

  # Two-tier resolution: a librarian-curated Person display_name is
  # authoritative and wins; NUIDs without a curated Person fall back to the
  # SSO users directory. Each source fails independently, so a Person-endpoint
  # hiccup degrades to SSO names rather than breaking name rendering.
  def self.fetch_names(nuids)
    return {} if nuids.empty?

    found = resolve_people(nuids)
    missing = nuids - found.keys
    found.merge!(resolve_users(missing)) if missing.any?

    found.each { |nuid, name| Rails.cache.write(cache_key(nuid), name, expires_in: CACHE_TTL) }
    # Atlas silently drops unresolvables — backfill so every key resolves.
    # Misses are deliberately not cached: a person/user provisioned a minute
    # later should resolve without waiting out the TTL. (A curator's name edit
    # likewise takes up to CACHE_TTL to propagate.)
    nuids.index_with { |nuid| found[nuid] || nuid }
  end
  private_class_method :fetch_names

  # Authoritative, librarian-curated names. Used verbatim — a curator set the
  # display_name to render exactly so, so no Namae prettification.
  def self.resolve_people(nuids)
    AtlasRb::Person.resolve(nuids, nuid: Current.nuid).each_with_object({}) do |person, names|
      names[person['nuid']] = person['display_name'] if person['display_name'].present?
    end
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error("NuidResolver(person): #{e.class} #{e.message}")
    {}
  end
  private_class_method :resolve_people

  # SSO directory fallback for NUIDs without a curated Person name. Atlas
  # stores names as "Family, Given"; presentation (Namae) is Cerberus's job.
  def self.resolve_users(nuids)
    AtlasRb::User.resolve(nuids, nuid: Current.nuid)
                 .to_h { |user| [user['nuid'], prettify(user['name'])] }
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error("NuidResolver(user): #{e.class} #{e.message}")
    {}
  end
  private_class_method :resolve_users

  def self.cache_key(nuid)
    "nuid_resolver/#{nuid}"
  end
  private_class_method :cache_key
end
