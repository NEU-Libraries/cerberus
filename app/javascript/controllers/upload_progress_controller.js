import { Controller } from "@hotwired/stimulus"

// Byte-level progress for any form that uploads a file. Turbo's own bar is
// time-driven: it eases toward full while the request is in flight, so a
// stalled upload looks exactly like a finishing one. See docs/uploads.md.
//
// Two ways to send, chosen by whether the form names a TUS endpoint:
//
// - Resumable: the file goes to the endpoint in chunks first, then the form is
//   submitted through Turbo carrying only `tus_upload_id`. A dropped connection
//   retries, and submitting again resumes rather than starting over.
// - Whole: the form goes as one multipart XHR, the only request that reports
//   upload progress (`fetch` has no equivalent event).
//
// A form with no file chosen is left alone, so Turbo submits it as usual.
const CHUNK_BYTES = 16 * 1024 * 1024
const RETRY_DELAYS = [0, 1000, 3000, 5000, 10000, 20000]

export default class extends Controller {
  static targets = ["panel", "fill", "label", "percent", "note", "status"]
  static values = {
    tusEndpoint: String,
    processingLabel: { type: String, default: "Processing on the server" },
    processingNote: { type: String, default: "Keep this tab open until the next page loads." }
  }

  connect() {
    this.initialNote = this.noteTarget.textContent
  }

  // Turbo caches the page after this runs, so the form goes back as the server
  // rendered it, and an upload still in flight stops rather than finishing
  // into a form that is no longer on the page.
  disconnect() {
    this.cancelled = true
    this.upload?.abort()
    this.xhr?.abort()
    this.idField?.remove()
    if (this.sentInput) this.sentInput.disabled = false
    this.disabledButtons?.forEach((button) => { button.disabled = false })
    this.panelTarget.hidden = true
    this.panelTarget.classList.remove("upload-progress--indeterminate", "upload-progress--failed")
    this.labelTarget.textContent = "Uploading"
    this.noteTarget.textContent = this.initialNote
    this.statusTarget.textContent = ""
    this.setFraction(0)
  }

  submit(event) {
    // The second submit is our own, after the resumable upload: Turbo takes it.
    if (this.handingOff || event.defaultPrevented) return

    const input = this.chosenInput()
    if (!input) return

    event.preventDefault()
    this.begin()
    if (this.tusEndpointValue) {
      this.sendResumable(input)
    } else {
      this.sendWhole(event.submitter)
    }
  }

  chosenInput() {
    return [...this.element.querySelectorAll("input[type=file]")].find((input) => !input.disabled && input.files.length)
  }

  begin() {
    this.panelTarget.hidden = false
    this.panelTarget.classList.remove("upload-progress--indeterminate", "upload-progress--failed")
    this.disabledButtons = [...this.element.elements].filter((el) => el.type === "submit" && !el.disabled)
    this.disabledButtons.forEach((button) => { button.disabled = true })
    this.setFraction(0)
    this.labelTarget.textContent = "Uploading"
    this.noteTarget.textContent = this.initialNote
    this.announce("Uploading.")
  }

  async sendResumable(input) {
    const tus = await loadTus()
    if (this.cancelled) return
    // The multipart path is always there underneath, so a browser without the
    // library, or one that failed to fetch it, still uploads.
    if (!tus?.isSupported) return this.sendWhole()

    const file = input.files[0]
    const upload = new tus.Upload(file, {
      endpoint: this.tusEndpointValue,
      chunkSize: CHUNK_BYTES,
      retryDelays: RETRY_DELAYS,
      metadata: { filename: file.name, filetype: file.type },
      headers: { "X-CSRF-Token": csrfToken() },
      removeFingerprintOnSuccess: true,
      onProgress: (sent, total) => this.setFraction(total ? sent / total : 1),
      onError: () => this.fail("The upload stopped. Check your connection, then submit again to resume where it left off."),
      onSuccess: () => this.handOff(input, upload.url)
    })
    this.upload = upload

    const previous = await upload.findPreviousUploads()
    if (this.cancelled) return
    if (previous.length) upload.resumeFromPreviousUpload(previous[0])
    upload.start()
  }

  // The file input is disabled, not removed, so the form never sends the bytes
  // a second time and its `required` no longer blocks the submit.
  handOff(input, url) {
    this.idField = Object.assign(document.createElement("input"), {
      type: "hidden", name: "tus_upload_id", value: new URL(url, window.location.href).pathname.split("/").pop()
    })
    this.element.append(this.idField)
    input.disabled = true
    this.sentInput = input
    this.awaitServer()
    this.handingOff = true
    this.element.requestSubmit()
  }

  sendWhole(submitter) {
    const form = this.element
    const xhr = new XMLHttpRequest()
    this.xhr = xhr

    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) this.setFraction(event.loaded / event.total)
    })
    // Every byte is sent and the request is still open while the server works.
    xhr.upload.addEventListener("load", () => this.awaitServer())
    xhr.addEventListener("load", () => this.finish(xhr))
    xhr.addEventListener("error", () => this.fail("The upload failed. Check your connection and try again."))
    xhr.addEventListener("abort", () => this.cancelled || this.fail("The upload was cancelled."))

    xhr.open(form.method, form.action)
    xhr.setRequestHeader("Accept", "text/html, application/xhtml+xml")
    xhr.send(submitter ? new FormData(form, submitter) : new FormData(form))
  }

  // The percentage is cleared rather than reworded: that slot is bold and
  // nowrap for tabular digits, so prose in it overflows a narrow viewport.
  awaitServer() {
    this.panelTarget.classList.add("upload-progress--indeterminate")
    this.panelTarget.removeAttribute("aria-valuenow")
    this.labelTarget.textContent = this.processingLabelValue
    this.percentTarget.textContent = ""
    this.noteTarget.textContent = this.processingNoteValue
    this.announce(`${this.processingLabelValue}.`)
  }

  // XHR follows a redirect itself, so the response is already the page to land
  // on, flash and all. Handing it to Turbo as a preloaded visit renders it
  // without a second GET, which would find the flash already spent.
  //
  // The only other answer an upload action gives is a 422 re-render of the
  // form. Swapping the body in place keeps its alert, and Stimulus re-binds
  // because it observes the document for added nodes.
  finish(xhr) {
    const html = xhr.responseText
    if (xhr.status >= 200 && xhr.status < 300 && html) {
      const location = xhr.responseURL || window.location.href
      window.Turbo.cache.clear()
      window.Turbo.visit(location, {
        action: "advance",
        response: { statusCode: xhr.status, responseHTML: html, redirected: location !== this.element.action }
      })
      return
    }

    if (xhr.status === 422 && html) {
      document.body.replaceWith(new DOMParser().parseFromString(html, "text/html").body)
      return
    }

    this.fail("The server rejected the upload. Try again, or ask an admin to check the logs.")
  }

  // The label carries the reason and the note says what to do about it, so the
  // failure is never communicated by colour alone.
  fail(message) {
    this.handingOff = false
    this.panelTarget.classList.remove("upload-progress--indeterminate")
    this.panelTarget.classList.add("upload-progress--failed")
    this.labelTarget.textContent = "Upload failed"
    this.percentTarget.textContent = ""
    this.noteTarget.textContent = message
    this.announce(`Upload failed. ${message}`)
    this.disabledButtons?.forEach((button) => { button.disabled = false })
  }

  // Phases only, never the percentage, which would talk over everything else.
  announce(text) {
    this.statusTarget.textContent = text
  }

  // Floored, so the bar never reads 100% while a last fraction is still owed.
  setFraction(fraction) {
    const percent = Math.min(100, Math.floor(fraction * 100))
    this.fillTarget.style.width = `${percent}%`
    this.percentTarget.textContent = `${percent}%`
    this.panelTarget.setAttribute("aria-valuenow", String(percent))
  }
}

async function loadTus() {
  try {
    await import("tus-js-client") // UMD build: registers window.tus
    return window.tus
  } catch {
    return null
  }
}

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content ?? ""
}
