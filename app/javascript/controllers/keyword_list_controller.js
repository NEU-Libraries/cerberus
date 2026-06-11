import { Controller } from "@hotwired/stimulus"

// Repeatable keyword inputs (stacked-input pattern): each committed keyword is a
// row with a red "−" remove button; a final "entry" row with a green "+" promotes
// its typed value into a new row (Enter also commits). Every keyword input —
// committed rows AND the entry — submits as `<resource>[keywords][]`, so a value
// typed but not yet "+"-ed is never lost; the server strips/dedupes. At least one
// keyword is required (enforced server-side in descriptive_valid?).
export default class extends Controller {
  static targets = ["row", "template", "entry"]

  add() {
    const value = this.entryTarget.value.trim()
    if (value === "") { this.entryTarget.focus(); return }

    const row = this.templateTarget.content.cloneNode(true).firstElementChild
    row.dataset.keywordListTarget = "row"
    row.querySelector("input").value = value

    const entryRow = this.entryTarget.closest(".input-group")
    entryRow.parentNode.insertBefore(row, entryRow)

    this.entryTarget.value = ""
    this.entryTarget.focus()
  }

  addOnEnter(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.add()
    }
  }

  remove(event) {
    event.target.closest("[data-keyword-list-target='row']").remove()
  }
}
