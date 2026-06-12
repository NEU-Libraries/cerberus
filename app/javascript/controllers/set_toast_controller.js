import { Controller } from "@hotwired/stimulus"

// Raises the set-aside teaching toast (server-rendered from flash[:aside])
// and retires it after a beat. The Undo inside is a plain put-back form —
// no client state lives here, so a missed dismissal costs nothing.
export default class extends Controller {
  connect() {
    requestAnimationFrame(() => this.element.classList.add("show"))
    this.timer = setTimeout(() => this.element.classList.remove("show"), 8000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
