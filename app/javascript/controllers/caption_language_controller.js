import { Controller } from "@hotwired/stimulus"

// Shows the caption upload's free language tag and label only while "Other" is
// chosen. The server ignores both fields for a listed language, so hiding them
// is presentation only; it never decides what is sent.
export default class extends Controller {
  static targets = ["select", "other"]

  connect() { this.toggle() }

  toggle() {
    this.otherTarget.hidden = this.selectTarget.value !== "other"
  }
}
