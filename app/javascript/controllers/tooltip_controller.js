import { Controller } from "@hotwired/stimulus"
import { Tooltip } from "bootstrap"

export default class extends Controller {
  connect() {
    this.tooltip = Tooltip.getOrCreateInstance(this.element)
  }

  disconnect() {
    this.tooltip?.dispose()
  }
}
