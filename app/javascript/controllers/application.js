import { Application } from "@hotwired/stimulus"
import ace from 'ace-builds'

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }
