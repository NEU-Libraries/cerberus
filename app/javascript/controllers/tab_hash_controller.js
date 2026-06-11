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
      // Preserve the existing state (Turbo stores its restorationIdentifier in
      // history.state). Passing null here wipes it, so Turbo's popstate handler
      // skips the restoration visit on Back and the previous page's DOM stays
      // on screen — the flaky "Back does nothing" bug.
      if (paneId) history.replaceState(history.state, "", paneId)
    }
    this.element.addEventListener("shown.bs.tab", this._onTabShown)
  }

  disconnect() {
    this.element.removeEventListener("shown.bs.tab", this._onTabShown)
  }
}
