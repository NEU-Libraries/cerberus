import { Controller } from "@hotwired/stimulus"

// Row checkboxes plus a select-all for the visible page. The bulk well stays
// hidden until a row is checked, and each submit button's confirmation names
// how many rows it will act on, counted in the page's own noun.
export default class extends Controller {
  static targets = ["all", "item", "well", "count", "confirm"]
  static values = { noun: { type: String, default: "item" } }

  // A Turbo cache restore brings back the boxes as they were left.
  connect() {
    this.update()
  }

  toggleAll() {
    this.itemTargets.forEach((box) => { box.checked = this.allTarget.checked })
    this.update()
  }

  update() {
    const total = this.itemTargets.length
    const checked = this.itemTargets.filter((box) => box.checked).length
    const items = `${checked} ${this.nounValue}${checked === 1 ? "" : "s"}`

    if (this.hasAllTarget) {
      this.allTarget.checked = total > 0 && checked === total
      this.allTarget.indeterminate = checked > 0 && checked < total
    }
    if (this.hasWellTarget) this.wellTarget.hidden = checked === 0
    if (this.hasCountTarget) this.countTarget.textContent = `${items} selected`
    this.confirmTargets.forEach((button) => {
      button.dataset.turboConfirm = button.dataset.confirmTemplate.replace("{items}", items)
    })
  }
}
