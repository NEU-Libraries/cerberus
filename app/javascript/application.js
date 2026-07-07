// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import bootstrap from "bootstrap"
import githubAutoCompleteElement from "@github/auto-complete-element"
import Blacklight from "blacklight"
// Imported after turbo-rails so window.Turbo exists when it self-registers the
// Bootstrap-modal confirm dialog in place of the native window.confirm().
import "cerberus/turbo_confirm"

Turbo.setProgressBarDelay(750)
