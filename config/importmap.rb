# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "jquery", to: "https://ga.jspm.io/npm:jquery@3.6.0/dist/jquery.js"

pin "@github/auto-complete-element", to: "https://cdn.jsdelivr.net/npm/@github/auto-complete-element/+esm"
pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.6/dist/umd/popper.min.js"
pin "bootstrap", to: "https://ga.jspm.io/npm:bootstrap@5.3.2/dist/js/bootstrap.js"
pin "ace-builds", to: "https://ga.jspm.io/npm:ace-builds@1.16.0/src-noconflict/ace.js"

pin_all_from "app/javascript/cerberus", under: "cerberus"
pin_all_from "app/javascript/preview_controllers", under: "preview_controllers"
# Preview is a separate application to avoid loading ace-builds for every page
pin 'preview_application'
