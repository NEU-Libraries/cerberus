import { Controller } from "@hotwired/stimulus"
import bootstrap from "bootstrap"

// Mounted on the view-as banner. Stops every state-changing form submission
// before it is sent and explains, in a modal, that view-as is read-only. The
// server refuses the same writes regardless (ImpersonationSession), so this
// only spares the admin a round trip and keeps them on the page they were on.
//
// It listens in the capture phase on document: Turbo's own submit handler runs
// in the bubble phase and skips an event whose default is already prevented,
// and a form with data-turbo="false" is stopped the same way.
export default class extends Controller {
  static values = { message: String, allowed: Array }

  connect() {
    this.onSubmit = this.onSubmit.bind(this)
    document.addEventListener("submit", this.onSubmit, true)
  }

  disconnect() {
    document.removeEventListener("submit", this.onSubmit, true)
    this.modal?.dispose()
    this.modalEl?.remove()
  }

  onSubmit(event) {
    const form = event.target
    const submitter = event.submitter
    if (!(form instanceof HTMLFormElement)) return
    if (!this.isWrite(form, submitter) || this.isAllowed(form, submitter)) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.show()
  }

  // Rails tunnels PATCH, PUT and DELETE through a POST with a hidden _method,
  // so the form's own method attribute is not the whole answer.
  isWrite(form, submitter) {
    const tunnelled = form.querySelector('input[name="_method"]')?.value
    const method = submitter?.getAttribute("formmethod") || tunnelled || form.getAttribute("method") || "get"
    return !["get", "dialog"].includes(method.toLowerCase())
  }

  isAllowed(form, submitter) {
    const action = submitter?.getAttribute("formaction") || form.getAttribute("action") || window.location.href
    const path = new URL(action, window.location.href).pathname
    return this.allowedValue.includes(path)
  }

  show() {
    if (!this.modalEl) this.build()
    this.modal.show()
  }

  build() {
    this.modalEl = document.createElement("div")
    this.modalEl.className = "modal fade"
    this.modalEl.tabIndex = -1
    this.modalEl.setAttribute("aria-hidden", "true")
    this.modalEl.setAttribute("aria-labelledby", "view-as-guard-title")
    this.modalEl.innerHTML = `
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content text-start">
          <div class="modal-header">
            <h2 class="modal-title h5" id="view-as-guard-title">
              <i class="fa-solid fa-eye me-2" aria-hidden="true"></i>View-as is read-only
            </h2>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body"><p class="mb-0"></p></div>
          <div class="modal-footer">
            <button type="button" class="btn btn-primary" data-bs-dismiss="modal">OK</button>
          </div>
        </div>
      </div>`
    // textContent, so a target's display name cannot inject markup.
    this.modalEl.querySelector(".modal-body p").textContent = this.messageValue
    document.body.appendChild(this.modalEl)
    this.modal = new bootstrap.Modal(this.modalEl)
    this.modalEl.addEventListener("shown.bs.modal", () => {
      this.modalEl.querySelector(".modal-footer .btn").focus()
    })
  }
}
