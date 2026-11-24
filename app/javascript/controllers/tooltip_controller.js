import { Controller } from "@hotwired/stimulus"
import bootstrap from "bootstrap"

// Longer than Bootstrap's fade (0.15s), so a queued transition callback runs
// before dispose() nulls the state that callback reads.
const DISPOSE_AFTER = 500

export default class extends Controller {
  connect() {
    clearTimeout(this.disposeTimer)
    this.tooltip = bootstrap.Tooltip.getOrCreateInstance(this.element)
    this.tooltip.enable()
  }

  // Leaving a page mid-fade queues a callback that throws if the tooltip is
  // already disposed. The bubble leaves the page now, so Turbo never caches it.
  disconnect() {
    const tooltip = this.tooltip
    if (!tooltip) return

    tooltip.disable()
    tooltip.tip?.remove()
    this.element.removeAttribute("aria-describedby")
    this.disposeTimer = setTimeout(() => tooltip.dispose(), DISPOSE_AFTER)
  }
}
