# frozen_string_literal: true

# libvips caches every operation, file loads included, keyed on the filename.
# A replace or revert restages its file to the same path as the last run on
# that Work, so a cached load returns the previous file's pixels and the new
# thumbnails and sizes are built from the old image. The `revalidate` load
# option fixes this per call but needs libvips 8.15, newer than the image's.
# Every vips call here is a one-off job, so the cache saves nothing.
Vips.cache_set_max(0)
