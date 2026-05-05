# Suppress Sass deprecation warnings emitted from third-party stylesheets
# (Bootstrap, Blacklight, rails_bootstrap_forms) loaded via --load-path.
# Warnings from our own app/assets/stylesheets are still surfaced.
Rails.application.config.dartsass.build_options << "--quiet-deps"
