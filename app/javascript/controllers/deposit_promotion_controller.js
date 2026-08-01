import { Controller } from "@hotwired/stimulus"

// Optional promotion into a community genre showcase, on the deposit form.
// Placement is decided by the route, so this governs one orthogonal choice:
// whether to also surface the new Work in a showcase, and which.
//
// Ticking the box reveals the community/genre pair; unticking hides AND
// disables them, so a stale selection never posts alongside an unchecked box.
// Changing the community repopulates the genre <select> from the per-community
// showcase map passed in as the `genres` value ({ communityNoid: { label: noid } }).
export default class extends Controller {
  static targets = ["fields", "community", "genre"]
  static values  = { genres: Object }

  connect() {
    this.toggle()
    this.communityChanged()
  }

  toggle() {
    if (!this.hasFieldsTarget) return

    const on = this.checked()
    this.fieldsTarget.classList.toggle("d-none", !on)
    this.fieldsTarget.querySelectorAll("input, select").forEach((el) => { el.disabled = !on })
  }

  // Repopulate the genre <select> to match the selected community's showcases.
  communityChanged() {
    if (!this.hasGenreTarget) return

    const keys = Object.keys(this.genresValue)
    if (keys.length === 0) return

    const noid = this.hasCommunityTarget ? this.communityTarget.value : keys[0]
    const genres = this.genresValue[noid] || {}
    this.genreTarget.innerHTML = Object.keys(genres)
      .map((label) => `<option value="${this.escape(label)}">${this.escape(label)}</option>`)
      .join("")
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
