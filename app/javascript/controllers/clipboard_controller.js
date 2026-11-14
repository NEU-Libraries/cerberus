import { Controller } from "@hotwired/stimulus"

// Copy a value (the Set's public URL) to the clipboard. The outcome shows on
// the button's label and is announced through the status target, which sits
// outside the button because a button's children are not reliably announced.
export default class extends Controller {
  static values = { text: String }
  static targets = ["label", "status"]

  connect() {
    this.original = this.hasLabelTarget ? this.labelTarget.textContent : ""
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.report("Copied")
    } catch {
      this.report("Copy failed")
    }
  }

  report(message) {
    clearTimeout(this.timer)
    if (this.hasLabelTarget) this.labelTarget.textContent = message
    if (this.hasStatusTarget) {
      // VoiceOver skips a message identical to the region's last one, even
      // after the region was emptied, so a repeat carries a no-break space.
      const text = message === this.lastMessage ? `${message} ` : message
      this.statusTarget.textContent = text
      this.lastMessage = text
    }
    this.timer = setTimeout(() => this.reset(), 1500)
  }

  reset() {
    if (this.hasLabelTarget) this.labelTarget.textContent = this.original
    if (this.hasStatusTarget) this.statusTarget.textContent = ""
  }

  disconnect() { clearTimeout(this.timer) }
}
