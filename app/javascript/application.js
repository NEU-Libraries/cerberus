// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import $ from "jquery"
import bootstrap from "bootstrap"
window.bootstrap = bootstrap // Required for Blacklight 7 so it can manage the modals
window.$ = $ // required as long as blacklight requires jquery
import "blacklight"

import {far} from "@fortawesome/free-regular-svg-icons"
import {fas} from "@fortawesome/free-solid-svg-icons"
import {fab} from "@fortawesome/free-brands-svg-icons"
import {library} from "@fortawesome/fontawesome-svg-core"
import "@fortawesome/fontawesome-free"
library.add(far, fas, fab)

FontAwesome.config.mutateApproach = 'sync'

import "cerberus/popover"
