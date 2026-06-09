import { Controller } from "@hotwired/stimulus"

// Group permission rows, stacked-input pattern (mirrors keyword_list): each
// committed grant is a row with a red "−"; the entry row's green "+" promotes the
// selected group + ability into a new committed row and resets the entry. Both
// committed rows and the entry submit as <resource>[permissions][<i>][...], so a
// selection not yet "+"-ed is still saved; blank/entry rows are skipped server-side.
export default class extends Controller {
  static targets = ["row", "template", "entry", "entryGroup", "entryAbility"]
  static values  = { resource: String }

  connect() {
    this.nextIndex = this.rowTargets.length + 1
  }

  add() {
    const group = this.entryGroupTarget.value
    if (group === "") { this.entryGroupTarget.focus(); return }
    const ability = this.entryAbilityTarget.value

    const i = this.nextIndex++
    const row = this.templateTarget.content.cloneNode(true).firstElementChild
    row.id = `group-list_${i}`
    row.dataset.groupPermissionsTarget = "row"

    const groupSelect   = row.querySelector("select.groups")
    const abilitySelect = row.querySelector("select.ability")
    groupSelect.name    = `${this.resourceValue}[permissions][${i}][group_id]`
    abilitySelect.name  = `${this.resourceValue}[permissions][${i}][ability]`
    groupSelect.value   = group
    abilitySelect.value = ability

    this.entryTarget.parentNode.insertBefore(row, this.entryTarget)

    this.entryGroupTarget.value = ""
    this.entryAbilityTarget.selectedIndex = 0
    this.entryGroupTarget.focus()
  }

  remove(event) {
    event.target.closest("[data-group-permissions-target='row']").remove()
  }
}
