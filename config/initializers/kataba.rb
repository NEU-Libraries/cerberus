# frozen_string_literal: true

# Kataba caches each fetched XSD on disk, then validates against the cached
# copy on every subsequent call. Default `offline_storage` is `Dir.tmpdir`,
# which can vanish on container restart and undo the caching. Pin it to a
# persistent path under /home/cerberus, matching the convention used by
# ThumbnailCreator's JP2 storage at /home/cerberus/images.
Kataba.configuration.offline_storage = '/home/cerberus/kataba_cache'

# Schemas not listed in the YAML are fetched as-declared.
Kataba.configuration.mirror_list = Rails.root.join('config', 'kataba_mirrors.yml').to_s
