import { Controller } from "@hotwired/stimulus"
import bootstrap from "bootstrap"

export default class extends Controller {
  connect() {
    this.tooltip = bootstrap.Tooltip.getOrCreateInstance(this.element)
  }

  disconnect() {
    this.tooltip?.dispose()
  }
}
