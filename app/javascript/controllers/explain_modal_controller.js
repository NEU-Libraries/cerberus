import { Controller } from "@hotwired/stimulus"

// Loads the "Why this result?" explanation into the shared #explainModal frame
// when the dialog opens, from the trigger's data-explain-url. Resets on close,
// so each open asks Solr again rather than showing the last result's answer.
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
    const url = event.relatedTarget?.dataset?.explainUrl
    if (!url) return
    this.frameTarget.innerHTML = this.initialFrame
    this.frameTarget.src = url
  }

  handleHidden() {
    this.frameTarget.removeAttribute("src")
    this.frameTarget.innerHTML = this.initialFrame
  }
}
