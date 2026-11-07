import { Controller } from "@hotwired/stimulus"

// Optional promotion into community genre showcases, on the deposit form.
// Placement is decided by the route, so this governs one orthogonal choice:
// whether to also surface the new Work in showcases, which communities, and
// under which one category.
//
// Ticking the box reveals the category and the communities; unticking hides
// AND disables them, so a stale selection never posts alongside an unchecked box.
//
// In someone else's workspace (`requiresProxy`) the whole promote block waits
// for Proxy deposit: a showcase entry is its depositor's, and only a proxy
// deposit makes the workspace's owner the depositor. The server refuses a
// promotion without one either way; hiding it keeps the form honest.
//
// A Work has one category in every community, so the category <select> offers
// the genres every checked community has, from the per-community showcase map
// passed in as the `genres` value ({ communityNoid: { label: noid } }).
export default class extends Controller {
  static targets = ["fields", "community", "genre", "promote"]
  static values  = { genres: Object, requiresProxy: Boolean }

  connect() {
    this.proxyChanged()
    this.communityChanged()
  }

  proxyChanged() {
    if (this.requiresProxyValue && this.hasPromoteTarget) {
      const proxy = this.element.querySelector("input[name='upload_as'][value='proxy']")
      const on = proxy ? proxy.checked : false
      this.promoteTarget.classList.toggle("d-none", !on)
      const box = this.promoteTarget.querySelector("input[name='publish']")
      if (box && !on) box.checked = false
      if (box) box.disabled = !on
    }
    this.toggle()
  }

  toggle() {
    if (!this.hasFieldsTarget) return

    const on = this.checked()
    this.fieldsTarget.classList.toggle("d-none", !on)
    this.fieldsTarget.querySelectorAll("input, select").forEach((el) => { el.disabled = !on })
  }

  // Offer the genres every checked community shares, in the first one's order,
  // keeping the current choice when it is still on offer.
  communityChanged() {
    if (!this.hasGenreTarget) return

    const noids = this.chosenCommunities()
    if (noids.length === 0) return

    const maps = noids.map((noid) => this.genresValue[noid] || {})
    const labels = Object.keys(maps[0]).filter((label) => maps.every((map) => label in map))
    const current = this.genreTarget.value
    this.genreTarget.innerHTML = labels
      .map((label) => `<option value="${this.escape(label)}">${this.escape(label)}</option>`)
      .join("")
    if (labels.includes(current)) this.genreTarget.value = current
  }

  // The checked communities, or every community when none is checked yet, so
  // the category list never empties while the depositor is still choosing.
  chosenCommunities() {
    const all = Object.keys(this.genresValue)
    if (!this.hasCommunityTarget) return all.slice(0, 1)

    const checked = this.communityTargets.filter((box) => box.checked).map((box) => box.value)
    return checked.length > 0 ? checked : all
  }

  checked() {
    const box = this.element.querySelector("input[name='publish']")
    return box ? box.checked : false
  }

  escape(value) {
    const span = document.createElement("span")
    span.textContent = value
    return span.innerHTML.replace(/"/g, "&quot;")
  }
}
