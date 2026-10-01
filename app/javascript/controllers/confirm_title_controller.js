import { Controller } from "@hotwired/stimulus"

// Holds a destructive submit disabled until the typed text matches the item's
// title, as GitHub does before deleting a repository. Spacing does not count.
// The button is disabled here rather than in the markup, and the server makes
// the same comparison, so the check never depends on this controller.
export default class extends Controller {
  static targets = ["input", "submit"]
  static values = { expected: String }

  connect() {
    this.sync()
  }

  sync() {
    const typed = this.inputTarget.value.replace(/\s+/g, " ").trim()
    this.submitTarget.disabled = typed !== this.expectedValue
  }
}
