import { Controller } from "@hotwired/stimulus"

// Compose-form recipient picker: person/group mode toggle plus a debounced
// typeahead against the inbox recipients endpoint in person mode. Only a
// picked result fills the hidden recipient_nuid — typing again clears the
// previous pick, so free-typed text is never submitted as a chosen NUID
// (though a raw NUID typed verbatim still works as a recipient).
export default class extends Controller {
  static targets = ["personPane", "groupPane", "query", "nuid", "results", "group"]
  static values = { url: String }

  disconnect() { clearTimeout(this.timer) }

  switchMode(event) {
    const person = event.target.value === "person"
    this.personPaneTarget.hidden = !person
    this.groupPaneTarget.hidden = person
    if (person) {
      this.groupTarget.value = ""
    } else {
      this.nuidTarget.value = ""
      this.queryTarget.value = ""
      this.renderResults([])
    }
  }

  search() {
    clearTimeout(this.timer)
    // Until a result is picked, submit the typed text as-is (raw-NUID entry).
    this.nuidTarget.value = this.queryTarget.value.trim()
    const query = this.queryTarget.value.trim()
    if (query.length < 2) { this.renderResults([]); return }

    this.timer = setTimeout(() => this.fetchResults(query), 250)
  }

  async fetchResults(query) {
    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`,
      { headers: { Accept: "application/json" } })
    this.renderResults(response.ok ? await response.json() : [])
  }

  choose(event) {
    const { nuid, name } = event.currentTarget.dataset
    this.nuidTarget.value = nuid
    this.queryTarget.value = `${name} (${nuid})`
    this.renderResults([])
  }

  renderResults(items) {
    this.resultsTarget.replaceChildren(...items.map((item) => this.resultButton(item)))
    this.resultsTarget.hidden = items.length === 0
  }

  // Name on the left, NUID as a monospace chip on the right — recipients
  // read like the audit ledger's identity cells, not free text.
  resultButton({ nuid, name }) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "list-group-item list-group-item-action inbox-typeahead__item"
    button.dataset.nuid = nuid
    button.dataset.name = name
    button.dataset.action = "recipient-picker#choose"

    const nameSpan = document.createElement("span")
    nameSpan.textContent = name
    const nuidSpan = document.createElement("span")
    nuidSpan.className = "inbox-typeahead__nuid"
    nuidSpan.textContent = nuid

    button.append(nameSpan, nuidSpan)
    return button
  }
}
