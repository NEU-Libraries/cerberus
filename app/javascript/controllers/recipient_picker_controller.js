import { Controller } from "@hotwired/stimulus"

// Compose-form recipient picker with a person/group mode toggle.
//
// Person mode: debounced typeahead against the inbox recipients endpoint.
// Group mode: client-side filter over the groups on the sender's own
// session (mirrors the permissions widget — you address groups you belong
// to), labeled with their Group cosmetic names.
//
// In both modes, only a picked result fills the hidden field with a chosen
// value; free-typed text still submits as-is (raw NUID / raw group name),
// and typing again after a pick invalidates it.
export default class extends Controller {
  static targets = ["personPane", "groupPane", "query", "nuid", "results",
                    "group", "groupQuery", "groupResults"]
  static values = { url: String, groups: Array }

  disconnect() { clearTimeout(this.timer) }

  switchMode(event) {
    const person = event.target.value === "person"
    this.personPaneTarget.hidden = !person
    this.groupPaneTarget.hidden = person
    if (person) {
      this.groupTarget.value = ""
      this.groupQueryTarget.value = ""
      this.renderResults(this.groupResultsTarget, [])
    } else {
      this.nuidTarget.value = ""
      this.queryTarget.value = ""
      this.renderResults(this.resultsTarget, [])
    }
  }

  // --- person mode (server-backed) ---

  search() {
    clearTimeout(this.timer)
    // Until a result is picked, submit the typed text as-is (raw-NUID entry).
    this.nuidTarget.value = this.queryTarget.value.trim()
    const query = this.queryTarget.value.trim()
    if (query.length < 2) { this.renderResults(this.resultsTarget, []); return }

    this.timer = setTimeout(() => this.fetchPeople(query), 250)
  }

  async fetchPeople(query) {
    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`,
      { headers: { Accept: "application/json" } })
    const people = response.ok ? await response.json() : []
    this.renderResults(
      this.resultsTarget,
      people.map(({ nuid, name }) => ({ value: nuid, label: name })),
      "choosePerson"
    )
  }

  choosePerson(event) {
    const { value, label } = event.currentTarget.dataset
    this.nuidTarget.value = value
    this.queryTarget.value = `${label} (${value})`
    this.renderResults(this.resultsTarget, [])
  }

  // --- group mode (session groups, filtered locally) ---

  searchGroups() {
    const query = this.groupQueryTarget.value.trim()
    // Unpicked text still submits as a raw group name.
    this.groupTarget.value = query
    if (query.length < 2) { this.renderResults(this.groupResultsTarget, []); return }

    const needle = query.toLowerCase()
    const matches = this.groupsValue
      .filter(({ raw, cosmetic }) =>
        raw.toLowerCase().includes(needle) || cosmetic.toLowerCase().includes(needle))
      .slice(0, 10)
      .map(({ raw, cosmetic }) => ({ value: raw, label: cosmetic }))
    this.renderResults(this.groupResultsTarget, matches, "chooseGroup")
  }

  chooseGroup(event) {
    const { value, label } = event.currentTarget.dataset
    this.groupTarget.value = value
    this.groupQueryTarget.value = label
    this.renderResults(this.groupResultsTarget, [])
  }

  // --- shared dropdown rendering ---

  renderResults(target, items, action) {
    target.replaceChildren(...items.map((item) => this.resultButton(item, action)))
    target.hidden = items.length === 0
  }

  // Label on the left, raw identifier (NUID / grouper name) as a monospace
  // chip on the right — recipients read like the audit ledger's identity
  // cells, not free text.
  resultButton({ value, label }, action) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "list-group-item list-group-item-action inbox-typeahead__item"
    button.dataset.value = value
    button.dataset.label = label
    button.dataset.action = `recipient-picker#${action}`

    const labelSpan = document.createElement("span")
    labelSpan.textContent = label
    const valueSpan = document.createElement("span")
    valueSpan.className = "inbox-typeahead__nuid"
    valueSpan.textContent = value

    button.append(labelSpan, valueSpan)
    return button
  }
}
