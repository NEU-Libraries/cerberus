import { Controller } from "@hotwired/stimulus"

// Repeatable creator rows (stacked-input pattern, mirroring keyword_list /
// group_permissions): committed rows carry a red "−"; a final entry row's green
// "+" (or Enter) promotes its typed value(s) into a committed row. Every input —
// committed rows AND the entry — submits, so a value typed but not "+"-ed is
// never lost; MODSMerge drops blank rows server-side. Two lists in one
// controller: personal (first + last) and corporate (organization).
export default class extends Controller {
  static targets = ["personalTemplate", "personalFirst", "personalLast", "corporateTemplate", "corporateEntry"]

  addPersonal() {
    const first = this.personalFirstTarget.value.trim()
    const last = this.personalLastTarget.value.trim()
    if (first === "" && last === "") { this.personalFirstTarget.focus(); return }

    const row = this.personalTemplateTarget.content.cloneNode(true).firstElementChild
    const inputs = row.querySelectorAll("input")
    inputs[0].value = first
    inputs[1].value = last
    this.insertBeforeEntry(row, this.personalFirstTarget)

    this.personalFirstTarget.value = ""
    this.personalLastTarget.value = ""
    this.personalFirstTarget.focus()
  }

  addCorporate() {
    const value = this.corporateEntryTarget.value.trim()
    if (value === "") { this.corporateEntryTarget.focus(); return }

    const row = this.corporateTemplateTarget.content.cloneNode(true).firstElementChild
    row.querySelector("input").value = value
    this.insertBeforeEntry(row, this.corporateEntryTarget)

    this.corporateEntryTarget.value = ""
    this.corporateEntryTarget.focus()
  }

  addPersonalOnEnter(event) {
    if (event.key === "Enter") { event.preventDefault(); this.addPersonal() }
  }

  addCorporateOnEnter(event) {
    if (event.key === "Enter") { event.preventDefault(); this.addCorporate() }
  }

  remove(event) {
    event.currentTarget.closest(".input-group").remove()
  }

  insertBeforeEntry(row, entryInput) {
    const entryGroup = entryInput.closest(".input-group")
    entryGroup.parentNode.insertBefore(row, entryGroup)
  }
}
