import { Controller } from "@hotwired/stimulus"

// Destination-collection picker for the XML/multipage loaders. A debounced
// title typeahead against the loader's collection_search endpoint; each result
// shows the title plus its NOID (monospace chip) so the operator can visually
// confirm the pick against a bad paste.
//
// Picking a result fills the hidden parent_collection_id field with the NOID.
// Free-typed text still submits as-is, so pasting a raw NOID works without
// picking; typing again after a pick invalidates the previous choice.
export default class extends Controller {
  static targets = ["query", "hidden", "results"]
  static values = { url: String }

  disconnect() { clearTimeout(this.timer) }

  search() {
    clearTimeout(this.timer)
    // Until a result is picked, submit the typed text as-is (raw-NOID entry).
    this.hiddenTarget.value = this.queryTarget.value.trim()
    const query = this.queryTarget.value.trim()
    if (query.length < 2) { this.renderResults([]); return }

    this.timer = setTimeout(() => this.fetchCollections(query), 250)
  }

  async fetchCollections(query) {
    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`,
      { headers: { Accept: "application/json" } })
    const collections = response.ok ? await response.json() : []
    this.renderResults(collections)
  }

  choose(event) {
    const { value, label } = event.currentTarget.dataset
    this.hiddenTarget.value = value
    this.queryTarget.value = `${label} (${value})`
    this.renderResults([])
  }

  renderResults(items) {
    this.resultsTarget.replaceChildren(...items.map((item) => this.resultButton(item)))
    this.resultsTarget.hidden = items.length === 0
  }

  // Title on the left, NOID as a monospace chip on the right — destinations
  // read like the audit ledger's identity cells, not free text. Reuses the
  // inbox typeahead's classes for a consistent picker look.
  resultButton({ value, label }) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "list-group-item list-group-item-action inbox-typeahead__item"
    button.dataset.value = value
    button.dataset.label = label
    button.dataset.action = "collection-picker#choose"

    const labelSpan = document.createElement("span")
    labelSpan.textContent = label
    const valueSpan = document.createElement("span")
    valueSpan.className = "inbox-typeahead__nuid"
    valueSpan.textContent = value

    button.append(labelSpan, valueSpan)
    return button
  }
}
