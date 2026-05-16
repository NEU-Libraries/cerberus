import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "template", "addButton"]
  static values  = { resource: String }

  connect() {
    this.nextIndex = this.rowTargets.length + 1
    if (this.rowTargets.length === 0) this.add()
  }

  add() {
    const i = this.nextIndex++
    const fragment = this.templateTarget.content.cloneNode(true)
    const row = fragment.firstElementChild
    row.id = `group-list_${i}`
    row.querySelector("select.groups").name  = `${this.resourceValue}[permissions][${i}][group_id]`
    row.querySelector("select.ability").name = `${this.resourceValue}[permissions][${i}][ability]`
    row.dataset.groupPermissionsTarget = "row"
    this.templateTarget.parentNode.insertBefore(row, this.templateTarget)
  }

  remove(event) {
    event.target.closest("[data-group-permissions-target='row']").remove()
  }
}
