import { Controller } from "@hotwired/stimulus"

// The Derivative access tab: the per-tier open/Restrict toggle, and the stacked
// group rows revealed under "Restrict to groups". The rows follow the
// Permissions tab's idiom — a committed grant per row with a red "−", an entry
// row whose green "+" promotes a pick — but the group is chosen by typeahead
// rather than a <select>, because the registry runs to dozens of groups and a
// list that long is unreadable eight times over.
//
// One controller spans the whole ladder rather than one per tier. Every tier
// offers the same registry, so a controller per tier would repeat it eight
// times in the markup; instead each event locates its own tier through the DOM.
// That is also why the per-tier elements are found by class and not by Stimulus
// target: targets resolve against the controller element, which here spans all
// eight tiers at once, so a target would collect every tier's copy.
export default class extends Controller {
  static values = { groups: Array }

  disconnect() { clearTimeout(this.timer) }

  toggle(event) {
    const tier = event.target.closest(".derivative-tier")
    const groups = tier?.querySelector(".derivative-tier__groups")
    groups?.classList.toggle("d-none", event.target.value !== "restrict")
  }

  // --- entry row ---

  // Filtered in the browser over the registry the server already rendered, so
  // picking a group costs no request. The list is bounded (the known Grouper
  // groups), unlike the person typeaheads elsewhere that must query a directory.
  search(event) {
    clearTimeout(this.timer)
    const entry = event.target.closest(".derivative-tier__entry")
    // Typing invalidates an earlier pick — the hidden field carries a chosen
    // identifier or nothing, never whatever was typed over it.
    entry.querySelector(".js-group-id").value = ""

    const query = event.target.value.trim()
    if (query.length < 2) { this.render(entry, []); return }

    this.timer = setTimeout(() => this.filter(entry, query), 200)
  }

  // Matches the raw Grouper identifier as well as the cosmetic name, mirroring
  // Group.search: a curator arrives holding one or the other.
  filter(entry, query) {
    const needle = query.toLowerCase()
    const taken = this.chosenIds(entry.closest(".derivative-tier"))
    const matches = this.groupsValue
      .filter(({ value, label }) =>
        !taken.includes(value) &&
        (label.toLowerCase().includes(needle) || value.toLowerCase().includes(needle)))
      .slice(0, 10)
    this.render(entry, matches)
  }

  choose(event) {
    const { value, label } = event.currentTarget.dataset
    const entry = event.currentTarget.closest(".derivative-tier__entry")
    entry.querySelector(".js-group-id").value = value
    entry.querySelector(".js-group-query").value = label
    this.render(entry, [])
    entry.querySelector(".js-group-query").focus()
  }

  // Enter in the entry field means "add this group". Without this it would
  // submit the form instead, saving a policy the curator had not finished.
  commit(event) {
    if (event.key !== "Enter") return

    event.preventDefault()
    this.add(event)
  }

  add(event) {
    const entry = event.target.closest(".derivative-tier__entry")
    const tier = entry.closest(".derivative-tier")
    const field = entry.querySelector(".js-group-id")
    const query = entry.querySelector(".js-group-query")
    if (field.value === "") { query.focus(); return }

    const row = tier.querySelector("template").content.cloneNode(true).firstElementChild
    row.querySelector(".js-label").textContent = query.value
    row.querySelector(".js-field").value = field.value
    tier.querySelector(".derivative-tier__rows").appendChild(row)

    field.value = ""
    query.value = ""
    this.render(entry, [])
    query.focus()
  }

  remove(event) {
    event.target.closest(".derivative-tier__row").remove()
  }

  // --- shared dropdown rendering ---

  render(entry, items) {
    const results = entry.querySelector(".inbox-typeahead")
    results.replaceChildren(...items.map((item) => this.resultButton(item)))
    results.hidden = items.length === 0
  }

  // Cosmetic name on the left, raw Grouper identifier as a monospace chip on
  // the right — the same identity typography as the recipient and impersonation
  // typeaheads, so a group reads the same wherever it is picked.
  resultButton({ value, label }) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "list-group-item list-group-item-action inbox-typeahead__item"
    button.dataset.value = value
    button.dataset.label = label
    button.dataset.action = "derivative-policy#choose"

    const labelSpan = document.createElement("span")
    labelSpan.className = "derivative-tier__result-name"
    labelSpan.textContent = label
    const valueSpan = document.createElement("span")
    valueSpan.className = "inbox-typeahead__nuid"
    valueSpan.textContent = value

    button.append(labelSpan, valueSpan)
    return button
  }

  chosenIds(tier) {
    return Array.from(tier.querySelectorAll(".derivative-tier__rows input[type=hidden]"))
      .map((field) => field.value)
  }
}
