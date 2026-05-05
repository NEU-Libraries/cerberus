import { Controller } from "@hotwired/stimulus"

// Lazy-loads the downloads list into the shared #downloadsModal turbo-frame
// when the modal opens, sourced from the trigger button's data-downloads-url.
// Resets on close so each open re-fetches (permissions/files can change).
export default class extends Controller {
  static targets = ["frame"]

  connect() {
    this.handleShow = this.handleShow.bind(this)
    this.handleHidden = this.handleHidden.bind(this)
    this.element.addEventListener("show.bs.modal", this.handleShow)
    this.element.addEventListener("hidden.bs.modal", this.handleHidden)
    this.initialFrame = this.frameTarget.innerHTML
  }

  disconnect() {
    this.element.removeEventListener("show.bs.modal", this.handleShow)
    this.element.removeEventListener("hidden.bs.modal", this.handleHidden)
  }

  handleShow(event) {
    const url = event.relatedTarget?.dataset?.downloadsUrl
    if (!url) return
    this.frameTarget.innerHTML = this.initialFrame
    this.frameTarget.src = url
  }

  handleHidden() {
    this.frameTarget.removeAttribute("src")
    this.frameTarget.innerHTML = this.initialFrame
  }
}
