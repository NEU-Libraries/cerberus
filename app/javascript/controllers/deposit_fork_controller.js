import { Controller } from "@hotwired/stimulus"

// The weighted deposit fork: two equal-weight destination cards (workspace vs
// publish). Choosing one reveals its branch and hides + disables the other, so
// only the active branch's inputs post (a stale value from the hidden branch
// never reaches the server). In the publish branch, changing the community
// repopulates the genre <select> from the per-community showcase map passed in
// as the `genres` value ({ communityNoid: { label: showcaseNoid } }).
export default class extends Controller {
  static targets = ["workspaceBranch", "publishBranch", "community", "genre"]
  static values  = { genres: Object }

  connect() {
    this.sync()
    this.communityChanged()
  }

  // A fork card was chosen (radio change) — reveal the matching branch.
  choose() { this.sync() }

  sync() {
    const publish = this.publishSelected()
    if (this.hasWorkspaceBranchTarget) this.toggleBranch(this.workspaceBranchTarget, !publish)
    if (this.hasPublishBranchTarget)   this.toggleBranch(this.publishBranchTarget, publish)
  }

  // Repopulate the genre <select> to match the selected community's showcases.
  communityChanged() {
    if (!this.hasGenreTarget) return

    const keys = Object.keys(this.genresValue)
    if (keys.length === 0) return

    const noid = this.hasCommunityTarget ? this.communityTarget.value : keys[0]
    const genres = this.genresValue[noid] || {}
    this.genreTarget.innerHTML = Object.keys(genres)
      .map((label) => `<option value="${this.escape(label)}">${this.escape(label)}</option>`)
      .join("")
  }

  publishSelected() {
    const checked = this.element.querySelector("input[name='deposit_to']:checked")
    return checked ? checked.value === "publish" : false
  }

  toggleBranch(branch, active) {
    branch.classList.toggle("d-none", !active)
    branch.querySelectorAll("input, select").forEach((el) => { el.disabled = !active })
  }

  escape(value) {
    const span = document.createElement("span")
    span.textContent = value
    return span.innerHTML.replace(/"/g, "&quot;")
  }
}
