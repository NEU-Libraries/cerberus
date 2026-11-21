import { Controller } from "@hotwired/stimulus"
import bootstrap from "bootstrap"

// A response slower than this opens the modal on its spinner instead, so a
// click never goes unanswered.
const SLOW_LOAD_MS = 1000

// Lazy-loads the downloads list into the shared #downloadsModal turbo-frame
// when the modal opens, sourced from the trigger button's data-downloads-url.
// Resets on close so each open re-fetches (permissions/files can change).
//
// The modal is held back until the list arrives, so it fades in at its final
// size: a centred dialog that grew mid-fade visibly jumped.
export default class extends Controller {
  static targets = ["frame"]

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
    // The show that reveal() starts itself, once the list is in.
    if (this.revealing) {
      this.revealing = false
      return
    }

    const url = event.relatedTarget?.dataset?.downloadsUrl
    if (!url) return

    event.preventDefault()
    if (this.waiting) return

    this.waiting = true
    this.trigger = event.relatedTarget
    this.showBusy(true)
    this.frameTarget.innerHTML = this.initialFrame
    this.frameTarget.addEventListener("turbo:frame-load", this.reveal, { once: true })
    this.timer = setTimeout(this.reveal, SLOW_LOAD_MS)
    this.frameTarget.src = url
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

  // Nothing is on screen while the list loads, so the cursor says the click
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
    this.frameTarget.removeAttribute("src")
    this.frameTarget.innerHTML = this.initialFrame
    // Bootstrap returns focus to the trigger only when it opened the modal
    // itself, and here reveal() did.
    this.trigger?.focus()
    this.trigger = null
  }
}
