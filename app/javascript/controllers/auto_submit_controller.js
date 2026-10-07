import { Controller } from "@hotwired/stimulus"

// Submits a GET filter form as soon as a select changes, so a choice such as
// the page size takes effect without a second click.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
