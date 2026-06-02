import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "expandBtn", "collapseBtn"]

  connect() {
    this.expanded = false
    this.updateToggle = this.updateToggle.bind(this)

    // Measure once after first paint, when scrollHeight/clientHeight are
    // reliable. The expand button starts hidden (d-none in the markup) and
    // is only revealed when the value actually overflows the clamp.
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

  // Show the expand affordance only when the clamped value is truncated.
  // Skipped while expanded so a resize doesn't re-clamp the user's view.
  updateToggle() {
    if (this.expanded) return
    const el = this.containerTarget
    const overflowing = el.scrollHeight - el.clientHeight > 1
    this.expandBtnTarget.classList.toggle("d-none", !overflowing)
  }

  expand() {
    this.expanded = true
    this.containerTarget.classList.remove("metadata-section-clamped")
    this.expandBtnTarget.classList.add("d-none")
    this.collapseBtnTarget.classList.remove("d-none")
  }

  collapse() {
    this.expanded = false
    this.containerTarget.classList.add("metadata-section-clamped")
    this.collapseBtnTarget.classList.add("d-none")
    // It was expandable (the user just collapsed it), so it overflows by
    // definition — bring the expand button back.
    this.expandBtnTarget.classList.remove("d-none")
  }
}
