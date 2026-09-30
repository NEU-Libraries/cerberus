import { Controller } from "@hotwired/stimulus"

// Holds a form's submit button disabled until its terms box is ticked, so a
// depositor never submits only to be sent back. The button is disabled here
// rather than in the markup, so the form still submits without JavaScript;
// the server refuses an unticked deposit either way.
export default class extends Controller {
  static targets = ["box", "submit"]

  connect() {
    this.sync()
  }

  sync() {
    this.submitTarget.disabled = !this.boxTarget.checked
  }
}
