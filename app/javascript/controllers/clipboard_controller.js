import { Controller } from "@hotwired/stimulus"

// Copy a value (the Set's public URL) to the clipboard, with brief inline
// feedback on the labelled button. Falls back to a manual-copy hint where the
// async Clipboard API is unavailable.
export default class extends Controller {
  static values = { text: String }
  static targets = ["label"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.flash("Copied")
    } catch {
      this.flash("Press ⌘/Ctrl+C")
    }
  }

  flash(message) {
    if (!this.hasLabelTarget) return
    const original = this.labelTarget.textContent
    this.labelTarget.textContent = message
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.labelTarget.textContent = original }, 1500)
  }

  disconnect() { clearTimeout(this.timer) }
}
