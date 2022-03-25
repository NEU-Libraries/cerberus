// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import $ from "jquery"
import bootstrap from "bootstrap"
window.bootstrap = bootstrap // Required for Blacklight 7 so it can manage the modals
window.$ = $ // required as long as blacklight requires jquery
import "blacklight"
