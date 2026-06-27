import { Controller } from "@hotwired/stimulus"

// Target-user typeahead for the admin impersonation start form. A debounced
// search against the admin user-directory endpoint; picking a result fills the
// hidden `nuid` field, while free-typed text still submits as-is so an admin
// can paste a raw NUID and hit Act as / View as without a lookup.
//
// Mirrors the person mode of recipient_picker_controller (and reuses the same
// .inbox-typeahead dropdown styling), minus the group-mode machinery the
// compose form needs.
export default class extends Controller {
  static targets = ["query", "nuid", "results"]
  static values = { url: String }

  disconnect() { clearTimeout(this.timer) }

  search() {
    clearTimeout(this.timer)
    // Until a result is picked, submit the typed text as-is (raw-NUID entry).
    const query = this.queryTarget.value.trim()
    this.nuidTarget.value = query
    if (query.length < 2) { this.renderResults([]); return }

    this.timer = setTimeout(() => this.fetchPeople(query), 250)
  }

  async fetchPeople(query) {
    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`,
      { headers: { Accept: "application/json" } })
    const people = response.ok ? await response.json() : []
    this.renderResults(people.map(({ nuid, name }) => ({ value: nuid, label: name })))
  }

  choose(event) {
    const { value, label } = event.currentTarget.dataset
    this.nuidTarget.value = value
    this.queryTarget.value = `${label} (${value})`
    this.renderResults([])
  }

  renderResults(items) {
    this.resultsTarget.replaceChildren(...items.map((item) => this.resultButton(item)))
    this.resultsTarget.hidden = items.length === 0
  }

  // Label on the left, NUID as a monospace chip on the right — same identity
  // typography as the inbox typeahead and the audit ledger.
  resultButton({ value, label }) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "list-group-item list-group-item-action inbox-typeahead__item"
    button.dataset.value = value
    button.dataset.label = label
    button.dataset.action = "impersonation-search#choose"

    const labelSpan = document.createElement("span")
    labelSpan.textContent = label
    const valueSpan = document.createElement("span")
    valueSpan.className = "inbox-typeahead__nuid"
    valueSpan.textContent = value

    button.append(labelSpan, valueSpan)
    return button
  }
}
