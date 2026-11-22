import { Controller } from "@hotwired/stimulus"

// The fragment names the innermost open pane, and each row opens whichever of
// its own panes holds it, so one fragment restores a row nested inside another
// row's pane. docs/edit-surfaces.md covers the nesting.
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
      if (!paneId) return

      const hash = this.hashFor(paneId)
      if (hash === window.location.hash) return

      // Preserve the existing state (Turbo stores its restorationIdentifier in
      // history.state). Passing null here wipes it, so Turbo's popstate handler
      // skips the restoration visit on Back and the previous page's DOM stays
      // on screen — the flaky "Back does nothing" bug.
      history.replaceState(history.state, "", hash)
    }
    this.element.addEventListener("shown.bs.tab", this._onTabShown)
  }

  disconnect() {
    window.removeEventListener("hashchange", this._onHashChange)
    this.element.removeEventListener("shown.bs.tab", this._onTabShown)
  }

  // Clicking an already-open tab is a no-op in Bootstrap, so this is safe to
  // run on every hash change — and it writes no history itself, so it cannot
  // loop against the replaceState above (replaceState does not fire
  // hashchange).
  showTabFromHash() {
    const target = this.paneFromHash()
    if (!target) return

    const btn = this.tabButtons().find((b) => this.paneFor(b)?.contains(target))
    if (btn) btn.click()
  }

  // The outer row opens its pane first, and must not overwrite a fragment that
  // names a pane inside it before the inner row has read it.
  hashFor(paneId) {
    const shown = this.paneById(paneId.slice(1))
    if (!shown) return paneId

    const current = this.paneFromHash()
    if (current && current !== shown && shown.contains(current)) return window.location.hash

    const nested = shown.querySelector('[data-controller~="tab-hash"] [data-bs-toggle="tab"].active')
    return nested ? this.hashFor(nested.getAttribute("data-bs-target")) : paneId
  }

  tabButtons() {
    return [...this.element.querySelectorAll('[data-bs-toggle="tab"][data-bs-target]')]
  }

  paneFor(button) {
    return this.paneById(button.getAttribute("data-bs-target").slice(1))
  }

  paneFromHash() {
    try {
      return this.paneById(decodeURIComponent(window.location.hash.slice(1)))
    } catch {
      return null
    }
  }

  paneById(id) {
    return id ? document.getElementById(id) : null
  }
}
