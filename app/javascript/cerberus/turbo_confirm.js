import bootstrap from "bootstrap"

// Routes every `data-turbo-confirm` through one shared Bootstrap modal instead
// of the browser's native window.confirm(), matching the app's tombstone-modal
// UX. Turbo calls the registered function with (message, formElement, submitter)
// and awaits a Promise<boolean>; resolving false aborts the visit/submission.
//
// Per-trigger overrides (read off the submitter, falling back to the form, so
// they work whether the data lives on a button or on a button_to's form):
//   data-turbo-confirm-title    — modal heading (default "Please confirm")
//   data-turbo-confirm-button   — confirm button label (default "Confirm")
//   data-turbo-confirm-variant  — Bootstrap button variant (default "danger",
//                                 since the confirms guarding these actions are
//                                 overwhelmingly destructive)

let modalEl
let modal
let titleEl
let bodyEl
let okButton

function build() {
  modalEl = document.createElement("div")
  modalEl.className = "modal fade"
  modalEl.tabIndex = -1
  modalEl.setAttribute("aria-hidden", "true")
  modalEl.setAttribute("aria-labelledby", "turbo-confirm-title")
  // `text-start` defends against `.text-end` ancestors bleeding in, mirroring
  // the tombstone modal, which shares this page context on show pages.
  modalEl.innerHTML = `
    <div class="modal-dialog modal-dialog-centered">
      <div class="modal-content text-start">
        <div class="modal-header">
          <h2 class="modal-title h5" id="turbo-confirm-title"></h2>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body"></div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
          <button type="button" class="btn"></button>
        </div>
      </div>
    </div>`
  document.body.appendChild(modalEl)
  modal = new bootstrap.Modal(modalEl)
  titleEl = modalEl.querySelector(".modal-title")
  bodyEl = modalEl.querySelector(".modal-body")
  okButton = modalEl.querySelector(".modal-footer .btn:not(.btn-secondary)")
}

// Render the message, preserving the blank-line paragraph breaks the existing
// messages rely on: the first block is the primary prompt, later blocks read as
// muted secondary detail (as in the tombstone modal). textContent escapes, so
// interpolated titles can't inject markup.
function renderMessage(message) {
  bodyEl.textContent = ""
  const blocks = String(message)
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .filter((block) => block.length > 0)

  blocks.forEach((block, index) => {
    const p = document.createElement("p")
    p.style.whiteSpace = "pre-line"
    p.className = index === 0 ? "mb-2" : "small text-muted mb-0"
    p.textContent = block
    bodyEl.appendChild(p)
  })
}

function readOption(name, submitter, formElement) {
  return submitter?.dataset?.[name] ?? formElement?.dataset?.[name] ?? null
}

function showConfirm(message, formElement, submitter) {
  if (!modalEl) build()

  titleEl.textContent =
    readOption("turboConfirmTitle", submitter, formElement) || "Please confirm"
  okButton.textContent =
    readOption("turboConfirmButton", submitter, formElement) || "Confirm"
  const variant =
    readOption("turboConfirmVariant", submitter, formElement) || "danger"
  okButton.className = `btn btn-${variant}`
  renderMessage(message)

  return new Promise((resolve) => {
    let confirmed = false

    const onOk = () => {
      confirmed = true
      modal.hide()
    }
    // Any dismissal path (Cancel, ×, backdrop, Esc) lands here; resolve once and
    // report whatever the OK button decided.
    const onHidden = () => {
      okButton.removeEventListener("click", onOk)
      modalEl.removeEventListener("hidden.bs.modal", onHidden)
      resolve(confirmed)
    }

    okButton.addEventListener("click", onOk)
    modalEl.addEventListener("hidden.bs.modal", onHidden)
    // Focus the confirm button once visible so Enter confirms / Esc cancels,
    // matching the native confirm() keyboard flow this replaces.
    modalEl.addEventListener("shown.bs.modal", () => okButton.focus(), { once: true })
    modal.show()
  })
}

export function installTurboConfirm() {
  const turbo = window.Turbo
  if (!turbo) return

  if (turbo.config?.forms) {
    turbo.config.forms.confirm = showConfirm
  } else if (typeof turbo.setConfirmMethod === "function") {
    turbo.setConfirmMethod(showConfirm)
  }
}

installTurboConfirm()
