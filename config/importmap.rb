# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "jquery", to: "jquery.js"

pin "@github/auto-complete-element", to: "@github--auto-complete-element.js"
pin "@github/combobox-nav", to: "@github--combobox-nav.js"
pin "@popperjs/core", to: "@popperjs--core.js"
pin "bootstrap", to: "bootstrap.js"
pin "ace-builds", to: "ace-builds.js"
# IIIF viewer (vendored dist, AGPL-3.0). Dynamically imported by
# iiif_viewer_controller — never preloaded; only multipage work pages pay.
pin "tify", to: "tify.js"

pin_all_from "app/javascript/cerberus", under: "cerberus"
pin_all_from "app/javascript/preview_controllers", under: "preview_controllers"
# Preview is a separate application to avoid loading ace-builds for every page
pin 'preview_application'
