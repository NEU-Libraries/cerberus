# frozen_string_literal: true

# Kataba caches each fetched XSD on disk, then validates against the cached
# copy on every subsequent call. Default `offline_storage` is `Dir.tmpdir`,
# which can vanish on container restart and undo the caching. Pin it to a
# persistent path under the cerberus data root, matching the convention used
# by ThumbnailCreator's JP2 storage at config.x.cerberus.derivatives_root.
Kataba.configuration.offline_storage = Rails.application.config.x.cerberus.schema_cache_root

# Schemas not listed in the YAML are fetched as-declared.
Kataba.configuration.mirror_list = Rails.root.join('config', 'kataba_mirrors.yml').to_s

# Set explicitly, though these match the gem's own defaults, because the bound
# they impose is on a THIRD-PARTY host (whatever a document's schemaLocation
# names, usually loc.gov) reached from a request thread — XmlController
# validates inline. Kataba pays both per redirect hop and again on its
# alternate-scheme attempt, so the ceiling for one schema is a multiple of
# these. Raising them re-opens a Puma-thread stall; the disk cache means the
# cost is paid once per schema, not per validation.
Kataba.configuration.open_timeout = 3
Kataba.configuration.read_timeout = 10
