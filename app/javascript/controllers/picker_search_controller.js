import { Controller } from "@hotwired/stimulus"

// Debounced typeahead for the Add-to-set modal: each keystroke re-submits
// the GET filter form, whose response replaces only the rows turbo-frame.
// The form (and so the input) lives outside that frame, so focus and the
// typed value survive every refresh.
export default class extends Controller {
  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 250)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
