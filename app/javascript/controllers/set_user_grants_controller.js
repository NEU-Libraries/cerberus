import { Controller } from "@hotwired/stimulus"

// Edit-access people picker for the Set Sharing tab. Debounced typeahead
// against the sets recipients endpoint (mirrors recipient_picker); a picked
// result becomes a removable chip carrying a hidden set[edit_users][] field.
// Already-granted users are pre-rendered as chips server-side; duplicates are
// rejected so the same NUID is never granted twice.
export default class extends Controller {
  static targets = ["query", "results", "chips", "template"]
  static values = { url: String }

  disconnect() { clearTimeout(this.timer) }

  search() {
    clearTimeout(this.timer)
    const query = this.queryTarget.value.trim()
    if (query.length < 2) { this.renderResults([]); return }
    this.timer = setTimeout(() => this.fetchPeople(query), 250)
  }

  async fetchPeople(query) {
    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`,
      { headers: { Accept: "application/json" } })
    const people = response.ok ? await response.json() : []
    this.renderResults(people)
  }

  renderResults(people) {
    this.resultsTarget.replaceChildren(...people.map((person) => this.resultButton(person)))
    this.resultsTarget.hidden = people.length === 0
  }

  resultButton({ nuid, name }) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "list-group-item list-group-item-action inbox-typeahead__item"
    button.dataset.nuid = nuid
    button.dataset.name = name
    button.dataset.action = "set-user-grants#choose"

    const label = document.createElement("span")
    label.textContent = name
    const nuidChip = document.createElement("span")
    nuidChip.className = "inbox-typeahead__nuid"
    nuidChip.textContent = nuid

    button.append(label, nuidChip)
    return button
  }

  choose(event) {
    const { nuid, name } = event.currentTarget.dataset
    if (!this.alreadyGranted(nuid)) this.addChip(nuid, name)
    this.queryTarget.value = ""
    this.renderResults([])
    this.queryTarget.focus()
  }

  addChip(nuid, name) {
    const chip = this.templateTarget.content.cloneNode(true).firstElementChild
    chip.querySelector(".js-name").textContent = name
    chip.querySelector(".js-nuid").textContent = nuid
    chip.querySelector(".js-field").value = nuid
    this.chipsTarget.appendChild(chip)
  }

  remove(event) {
    event.target.closest("li").remove()
  }

  alreadyGranted(nuid) {
    return Array.from(this.chipsTarget.querySelectorAll("input[type=hidden]"))
      .some((field) => field.value === nuid)
  }
}
