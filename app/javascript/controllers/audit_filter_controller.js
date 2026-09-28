import { Controller } from "@hotwired/stimulus"

// Narrows the audit table to one action. The options are read from the
// rendered rows' Action cells, so they always match the labels on screen
// whichever per-action partial drew a row. Stays hidden without JavaScript,
// and when a table has fewer than two distinct actions to choose between.
export default class extends Controller {
  static targets = ["wrapper", "select"]

  connect() {
    // A Turbo cache restore brings back the options added last time.
    this.selectTarget.length = 1
    const labels = [...new Set(this.rows.map((row) => this.labelOf(row)))].filter(Boolean).sort()
    if (labels.length < 2) return

    labels.forEach((label) => this.selectTarget.add(new Option(label, label)))
    this.wrapperTarget.hidden = false
  }

  filter() {
    const wanted = this.selectTarget.value
    this.rows.forEach((row) => {
      row.hidden = wanted !== "" && this.labelOf(row) !== wanted
    })
  }

  get rows() {
    return [...this.element.querySelectorAll("tbody tr.audit-event")]
  }

  labelOf(row) {
    return row.cells[1]?.innerText.trim() ?? ""
  }
}
