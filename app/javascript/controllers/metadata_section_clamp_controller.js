import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "toggle"]

  connect() {
    this.expanded = false
    this.updateToggle = this.updateToggle.bind(this)

    // Measure once after first paint, when scrollHeight/clientHeight are
    // reliable. The toggle starts hidden (d-none in the markup) and is only
    // revealed when the value actually overflows the clamp.
    requestAnimationFrame(this.updateToggle)

    // A late web-font swap can change the rendered height after the first
    // measure, so re-check once fonts have settled.
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(this.updateToggle)
    }

    // Responsive reflow can make a value start or stop overflowing, so
    // re-evaluate whenever the clamped container changes size.
    if (typeof ResizeObserver !== "undefined") {
      this.observer = new ResizeObserver(this.updateToggle)
      this.observer.observe(this.containerTarget)
    }
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }

  // Show the toggle only when the clamped value is truncated. Skipped while
  // expanded so a resize doesn't re-clamp the user's view.
  updateToggle() {
    if (this.expanded) return
    const el = this.containerTarget
    const overflowing = el.scrollHeight - el.clientHeight > 1
    this.toggleTarget.classList.toggle("d-none", !overflowing)
  }

  // The button stays visible in both states: it was shown because the value
  // overflows, so a collapsed value still needs it.
  toggle() {
    this.expanded = !this.expanded
    this.containerTarget.classList.toggle("metadata-section-clamped", !this.expanded)
    this.toggleTarget.setAttribute("aria-expanded", String(this.expanded))
  }
}
