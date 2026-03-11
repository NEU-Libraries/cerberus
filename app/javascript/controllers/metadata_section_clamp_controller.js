import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "expandBtn", "collapseBtn"]

  expand() {
    this.containerTarget.classList.remove("metadata-section-clamped")
    this.expandBtnTarget.classList.add("d-none")
    this.collapseBtnTarget.classList.remove("d-none")
  }

  collapse() {
    this.containerTarget.classList.add("metadata-section-clamped")
    this.expandBtnTarget.classList.remove("d-none")
    this.collapseBtnTarget.classList.add("d-none")
  }
}
