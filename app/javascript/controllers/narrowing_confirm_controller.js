import { Controller } from "@hotwired/stimulus"

// Puts a confirmation in front of a permissions save that would take audience
// away from a Collection, because that save cascades to everything inside it
// and there is no undo: widening the collection again does NOT restore the
// descendants, so re-opening a collection leaves its contents private.
//
// ADVISORY ONLY. The server decides for real (NarrowingRequest), and it applies
// the same rule. If this misreads the form the worst case is a missing or a
// spurious prompt — never a different outcome. That is the reason it is safe to
// mirror the subset rule here in a few lines rather than round-tripping.
export default class extends Controller {
  static targets = ["form"]
  static values  = { initial: Array, affected: Number }

  connect() {
    this.update()
  }

  // Adding or removing a row is another controller's click handler, and both
  // run on the same event — so re-read the DOM on the next frame, once that
  // mutation has actually landed, rather than racing it.
  updateSoon() {
    requestAnimationFrame(() => this.update())
  }

  // Re-evaluated on every change in the pane: the visibility select, the
  // ability of a row, and adding or removing a row all move the audience.
  update() {
    const message = this.narrowing() ? this.message() : null
    if (message) {
      this.formTarget.dataset.turboConfirm      = message
      this.formTarget.dataset.turboConfirmTitle = "Restrict this collection?"
      this.formTarget.dataset.turboConfirmButton = "Restrict"
    } else {
      delete this.formTarget.dataset.turboConfirm
      delete this.formTarget.dataset.turboConfirmTitle
      delete this.formTarget.dataset.turboConfirmButton
    }
  }

  // Mirrors Permissions.audience_subset? — `public` is the universal audience,
  // so anything is within it, and nothing but itself contains it.
  narrowing() {
    const before = this.initialValue
    const after  = this.submittedAudience()
    if (after.includes("public")) return false
    if (before.includes("public")) return true
    return !before.every((group) => after.includes(group))
  }

  // What the form would send: the visibility select decides `public`, and the
  // committed rows carry the group grants. Rows set to Manage are edit grants,
  // not read, so they do not widen who can see it.
  submittedAudience() {
    const visibility = this.element.querySelector("select#mass")
    if (visibility && visibility.value === "public") return ["public"]

    return Array.from(this.element.querySelectorAll("[data-group-permissions-target='row']"))
      .filter((row) => this.rowAbility(row) === "read")
      .map((row) => this.rowGroup(row))
      .filter((group) => group)
  }

  // A row is either two selects (revocable) or two hidden inputs (locked).
  rowGroup(row) {
    const select = row.querySelector("select.groups")
    return select ? select.value : row.querySelector("input[name*='[group_id]']")?.value
  }

  rowAbility(row) {
    const select = row.querySelector("select.ability")
    return select ? select.value : row.querySelector("input[name*='[ability]']")?.value
  }

  message() {
    if (this.affectedValue === 0) {
      return "This collection will be restricted. There is nothing inside it to change."
    }
    const items = this.affectedValue === 1 ? "1 item" : `${this.affectedValue} items`
    return `${items} inside this collection will be restricted to match it.\n\n` +
      "Anything that is currently visible to a group the new audience does not include becomes private. " +
      "Re-opening the collection later will not undo this."
  }
}
