import { Controller } from "@hotwired/stimulus"

// Shows a section only while the radio that asks for it is chosen. The section
// is hidden rather than removed, so its fields still submit and a choice
// switched away from and back again keeps what was entered.
export default class extends Controller {
  static targets = ["section"]
  static values = { when: String }

  connect() { this.sync() }

  sync() {
    const chosen = this.element.querySelector("input[type=radio]:checked")
    this.sectionTarget.hidden = chosen?.value !== this.whenValue
  }
}
