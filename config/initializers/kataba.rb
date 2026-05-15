# frozen_string_literal: true

# Kataba caches each fetched XSD on disk, then validates against the cached
# copy on every subsequent call. Default `offline_storage` is `Dir.tmpdir`,
# which can vanish on container restart and undo the caching. Pin it to a
# persistent path under /home/cerberus, matching the convention used by
# ThumbnailCreator's JP2 storage at /home/cerberus/images.
Kataba.configuration.offline_storage = '/home/cerberus/kataba_cache'

# LoC's schema server sits behind Cloudflare and 503s plain-HTTP requests
# while serving the HTTPS variants 200. MODS records authored over the
# last two decades declare `schemaLocation` with `http://...` URLs; this
# mirror list maps those declarations to their HTTPS equivalents at fetch
# time so we don't have to rewrite the records themselves. Schemas not
# listed in the YAML are fetched as-declared.
Kataba.configuration.mirror_list = Rails.root.join('config', 'kataba_mirrors.yml').to_s
