import { Controller } from "@hotwired/stimulus"

// Repeatable keyword inputs (stacked-input pattern): each committed keyword is a
// row with a red "−" remove button; a final "entry" row with a green "+" promotes
// its typed value into a new row (Enter also commits). Every keyword input —
// committed rows AND the entry — submits as `<resource>[keywords][]`, so a value
// typed but not yet "+"-ed is never lost; the server strips/dedupes. At least one
// keyword is required — enforced server-side in descriptive_valid?, and mirrored
// client-side here by requiring the entry input whenever no keyword holds a value
// (so the browser blocks an empty submit, but never demands a value once one
// exists — including a typed-but-not-added entry).
export default class extends Controller {
  static targets = ["row", "template", "entry"]

  connect() { this.syncRequired() }

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
    this.syncRequired()
  }

  addOnEnter(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.add()
    }
  }

  remove(event) {
    event.target.closest("[data-keyword-list-target='row']").remove()
    this.syncRequired()
  }

  // Require the entry input only when no keyword input (committed row or entry)
  // holds a non-empty value, so the form can't submit with zero keywords. Wired
  // to connect/add/remove and to each keyword input's `input` event.
  syncRequired() {
    const hasValue = [...this.element.querySelectorAll("input[name$='[keywords][]']")]
      .some((input) => input.value.trim() !== "")
    this.entryTarget.required = !hasValue
  }
}
