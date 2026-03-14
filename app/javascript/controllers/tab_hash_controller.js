import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const hash = window.location.hash
    if (hash) {
      const btn = this.element.querySelector(`[data-bs-target="${hash}"]`)
      if (btn) btn.click()
    }

    this._onTabShown = (e) => {
      const paneId = e.target.getAttribute("data-bs-target")
      if (paneId) history.replaceState(null, "", paneId)
    }
    this.element.addEventListener("shown.bs.tab", this._onTabShown)
  }

  disconnect() {
    this.element.removeEventListener("shown.bs.tab", this._onTabShown)
  }
}
