import { Controller } from "@hotwired/stimulus"

// Opt-in download sizes on the deposit metadata page. Three rows
// (small/medium/large), each a checkbox + range slider + number input,
// correlated by data-role. Eager-loaded by filename like the other form
// widgets (keyword_list, group_permissions).
//
// Invariants enforced here (the server re-validates as a backstop):
// - a row's inputs are disabled until its checkbox is on (disabled
//   inputs never submit — unchecked sizes simply don't arrive);
// - enabled sizes strictly increase small → medium → large;
// - everything stays within 1..max (the master's longest edge).
//
// All sliders deliberately share one scale (min=1, max=longest edge) so
// the thumbs read as a sorted ledger; ordering is enforced by clamping
// values on commit (change events) into the window between the nearest
// enabled neighbours, not by narrowing slider ranges. A window can be
// empty (e.g. small=5, large=6, enable medium): then the row gets a
// native validity error so the form won't submit until resolved.
export default class extends Controller {
  static targets = ["toggle", "slider", "number"]
  static values = { max: Number }

  ROLES = ["small", "medium", "large"]

  toggle(event) {
    const role = event.target.dataset.role
    const enabled = event.target.checked
    this.#slider(role).disabled = !enabled
    this.#number(role).disabled = !enabled
    if (enabled) this.#clampIntoWindow(role)
    this.#validateAll()
  }

  // Live mirror while dragging; ordering applies on release (commit).
  syncFromSlider(event) {
    const role = event.target.dataset.role
    this.#number(role).value = event.target.value
  }

  // Live mirror while typing, when parseable.
  syncFromNumber(event) {
    const role = event.target.dataset.role
    const value = parseInt(event.target.value, 10)
    if (!Number.isNaN(value)) this.#slider(role).value = value
  }

  // change event on slider (release) or number (blur/step): enforce the
  // neighbour window.
  commit(event) {
    this.#clampIntoWindow(event.target.dataset.role)
    this.#validateAll()
  }

  #clampIntoWindow(role) {
    const [lower, upper] = this.#window(role)
    if (lower > upper) return // empty window — #validateAll flags it

    const current = parseInt(this.#number(role).value, 10)
    const clamped = Math.min(Math.max(Number.isNaN(current) ? lower : current, lower), upper)
    this.#number(role).value = clamped
    this.#slider(role).value = clamped
  }

  // [min, max] the role's value must occupy, given enabled neighbours.
  #window(role) {
    const index = this.ROLES.indexOf(role)
    const enabledValue = (r) =>
      this.#toggle(r).checked ? parseInt(this.#number(r).value, 10) : null

    let lower = 1
    for (let i = index - 1; i >= 0; i--) {
      const v = enabledValue(this.ROLES[i])
      if (v !== null) { lower = v + 1; break }
    }
    let upper = this.maxValue
    for (let i = index + 1; i < this.ROLES.length; i++) {
      const v = enabledValue(this.ROLES[i])
      if (v !== null) { upper = v - 1; break }
    }
    return [lower, upper]
  }

  // Native validity carries the error to submit time: an empty window
  // (or any out-of-order combination that survived clamping) blocks the
  // form with a browser-rendered message on the offending row.
  #validateAll() {
    this.ROLES.forEach((role) => {
      const number = this.#number(role)
      if (!this.#toggle(role).checked) { number.setCustomValidity(""); return }

      const [lower, upper] = this.#window(role)
      const value = parseInt(number.value, 10)
      if (lower > upper || value < lower || value > upper) {
        number.setCustomValidity(
          `${role[0].toUpperCase() + role.slice(1)} must fall between its neighbouring enabled sizes.`
        )
      } else {
        number.setCustomValidity("")
      }
    })
  }

  #toggle(role) { return this.toggleTargets.find((t) => t.dataset.role === role) }
  #slider(role) { return this.sliderTargets.find((t) => t.dataset.role === role) }
  #number(role) { return this.numberTargets.find((t) => t.dataset.role === role) }
}
