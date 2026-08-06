import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.showTabFromHash()

    // A fragment-only navigation does not load a new document, so connect()
    // does not run again and the tab row would ignore the new hash: the URL
    // says #history while the page still shows Metadata. That is the shape of
    // every "open …/edit#history" instruction followed from the page it names.
    this._onHashChange = () => this.showTabFromHash()
    window.addEventListener("hashchange", this._onHashChange)

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
    window.removeEventListener("hashchange", this._onHashChange)
    this.element.removeEventListener("shown.bs.tab", this._onTabShown)
  }

  // Open whichever pane the hash names. Clicking an already-open tab is a
  // no-op in Bootstrap, so this is safe to run on every hash change — and it
  // writes no history itself, so it cannot loop against the replaceState above
  // (replaceState does not fire hashchange).
  showTabFromHash() {
    const hash = window.location.hash
    if (!hash) return

    const btn = this.element.querySelector(`[data-bs-target="${hash}"]`)
    if (btn) btn.click()
  }
}
