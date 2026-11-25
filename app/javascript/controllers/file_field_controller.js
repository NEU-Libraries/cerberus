import { Controller } from "@hotwired/stimulus"

// Shows the chosen file's name beside a shared/_file_field button, in place of
// the browser's own "No file chosen" text. The input's change event bubbles to
// this element, so a page needs no wiring beyond the partial.
//
// connect() reads the input once, because a browser can restore a chosen file
// when the reader comes back to the page.
export default class extends Controller {
  static targets = ["name"]

  connect() {
    this.show = this.show.bind(this)
    this.dragOver = () => this.element.classList.add("file-field--dragover")
    this.dragEnd = () => this.element.classList.remove("file-field--dragover")
    this.element.addEventListener("change", this.show)
    this.element.addEventListener("dragenter", this.dragOver)
    for (const type of ["dragleave", "drop"]) this.element.addEventListener(type, this.dragEnd)
    this.show()
  }

  disconnect() {
    this.element.removeEventListener("change", this.show)
    this.element.removeEventListener("dragenter", this.dragOver)
    for (const type of ["dragleave", "drop"]) this.element.removeEventListener(type, this.dragEnd)
    this.dragEnd()
  }

  show() {
    const file = this.element.querySelector("input[type=file]")?.files?.[0]
    this.nameTarget.textContent = file ? file.name : "No file chosen"
    this.element.classList.toggle("file-field--chosen", Boolean(file))
  }
}
