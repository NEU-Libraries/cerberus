import { Controller } from "@hotwired/stimulus"
import bootstrap from "bootstrap"

// A response slower than this opens the modal on its placeholder instead, so a
// click never goes unanswered.
const SLOW_LOAD_MS = 1000

// Holds a modal back until the turbo-frame inside it has loaded, so it opens at
// its final size. docs/design.md ("Modals that load their content") explains
// the two modes and why.
export default class extends Controller {
  static targets = ["frame"]
  static values = { urlKey: String }

  connect() {
    this.handleShow = this.handleShow.bind(this)
    this.handleHidden = this.handleHidden.bind(this)
    this.reveal = this.reveal.bind(this)
    this.element.addEventListener("show.bs.modal", this.handleShow)
    this.element.addEventListener("hidden.bs.modal", this.handleHidden)
    this.initialFrame = this.frameTarget.innerHTML
  }

  disconnect() {
    this.element.removeEventListener("show.bs.modal", this.handleShow)
    this.element.removeEventListener("hidden.bs.modal", this.handleHidden)
    this.stopWaiting()
  }

  handleShow(event) {
    // The show that reveal() starts itself, once the frame is in.
    if (this.revealing) {
      this.revealing = false
      return
    }

    const trigger = event.relatedTarget
    let url = null
    if (this.hasUrlKeyValue) {
      url = trigger?.dataset?.[this.urlKeyValue]
      if (!url) return
    } else if (this.frameTarget.hasAttribute("complete")) {
      // Not the frame's `complete` property, which means only "not loading
      // now" and so is true for a lazy frame that has never loaded.
      return
    }

    event.preventDefault()
    if (this.waiting) return

    this.waiting = true
    this.trigger = trigger
    this.showBusy(true)
    this.frameTarget.addEventListener("turbo:frame-load", this.reveal, { once: true })
    this.timer = setTimeout(this.reveal, SLOW_LOAD_MS)

    if (url) {
      this.frameTarget.innerHTML = this.initialFrame
      this.frameTarget.src = url
    } else {
      // A lazy frame loads only once it is visible, which a hidden modal never is.
      this.frameTarget.loading = "eager"
    }
  }

  reveal() {
    if (!this.waiting) return

    this.stopWaiting()
    this.revealing = true
    bootstrap.Modal.getOrCreateInstance(this.element).show(this.trigger)
  }

  stopWaiting() {
    this.waiting = false
    clearTimeout(this.timer)
    this.frameTarget.removeEventListener("turbo:frame-load", this.reveal)
    this.showBusy(false)
  }

  // Nothing is on screen while the frame loads, so the cursor says the click
  // is working. The button sets its own pointer cursor, and the mouse is on
  // it, so it needs the cursor as well as the page.
  showBusy(busy) {
    for (const el of [document.documentElement, this.trigger]) {
      if (!el) continue
      if (busy) el.style.cursor = "progress"
      else el.style.removeProperty("cursor")
    }
    if (busy) this.trigger?.setAttribute("aria-busy", "true")
    else this.trigger?.removeAttribute("aria-busy")
  }

  handleHidden() {
    if (this.hasUrlKeyValue) {
      this.frameTarget.removeAttribute("src")
      this.frameTarget.innerHTML = this.initialFrame
    }
    // Bootstrap returns focus to the trigger only when it opened the modal
    // itself; when reveal() opened it, this does.
    this.trigger?.focus()
    this.trigger = null
  }
}
