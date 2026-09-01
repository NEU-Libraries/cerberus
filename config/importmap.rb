# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

pin "@github/auto-complete-element", to: "@github--auto-complete-element.js"
pin "@github/combobox-nav", to: "@github--combobox-nav.js"
pin "@popperjs/core", to: "@popperjs--core.js"
pin "bootstrap", to: "bootstrap.js"
pin "ace-builds", to: "ace-builds.js", preload: false
# Charting for the /admin usage-analytics dashboard. Both ship with the
# chartkick gem on the asset path; imported only by the dashboard.
pin "chartkick", to: "chartkick.js", preload: false
pin "Chart.bundle", to: "Chart.bundle.js", preload: false
# IIIF viewer (vendored dist, AGPL-3.0). Dynamically imported by
# iiif_viewer_controller, so only multipage work pages pay.
pin "tify", to: "tify.js", preload: false
# video.js (UMD ~600KB) for the in-page A/V player; dynamically imported by
# av_player_controller, so only A/V work pages fetch it.
pin "video-js", to: "video-js.js", preload: false

pin_all_from "app/javascript/cerberus", under: "cerberus"
pin_all_from "app/javascript/preview_controllers", under: "preview_controllers", preload: false
# Preview is a separate application to avoid loading ace-builds for every page.
# Only the XML editor pulls it in, via javascript_import_module_tag.
pin 'preview_application', preload: false
