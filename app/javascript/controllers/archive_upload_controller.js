import { Controller } from "@hotwired/stimulus"

// Byte-level progress for a loader archive upload, which is routinely hundreds
// of megabytes over a slow link.
//
// This exists because Turbo's own progress bar is TIME-driven, not byte-driven:
// it eases toward full while the request is still in flight, so it reads as
// finished long before the bytes are, and a stalled upload looks exactly like a
// finishing one. A librarian watching it cannot tell whether to keep waiting.
//
// Only XMLHttpRequest reports upload progress. `fetch` has no equivalent event
// and a plain form submit has none either, so Turbo cannot be asked for this.
// Owning the request means owning the response, which is what `send` does below.
export default class extends Controller {
  static targets = ["file", "panel", "fill", "label", "percent", "note", "submit"]

  // Two distinct phases, and keeping them apart is the point of the whole
  // controller. Bytes leaving the browser is a measurable fraction; the server
  // unpacking the archive afterwards is not, and reporting it as 100% is the
  // lie the old bar told.
  submit(event) {
    const form = this.element
    if (!form.reportValidity()) return

    event.preventDefault()
    this.begin()
    this.send(form)
  }

  begin() {
    this.panelTarget.hidden = false
    this.submitTarget.disabled = true
    this.setFraction(0)
    this.labelTarget.textContent = "Uploading"
  }

  send(form) {
    const xhr = new XMLHttpRequest()

    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) this.setFraction(event.loaded / event.total)
    })

    // The bytes are all sent, and the request is still open while the server
    // writes the archive to disk. Drop the percentage rather than sit at 100:
    // an indeterminate bar cannot be misread as "done".
    xhr.upload.addEventListener("load", () => this.awaitServer())

    xhr.addEventListener("load", () => this.finish(xhr))
    xhr.addEventListener("error", () => this.fail("The upload failed. Check your connection and try again."))
    xhr.addEventListener("abort", () => this.fail("The upload was cancelled."))

    xhr.open(form.method, form.action)
    xhr.setRequestHeader("Accept", "text/html, application/xhtml+xml")
    xhr.send(new FormData(form))
  }

  // The percentage is cleared rather than reworded: that slot is bold and
  // nowrap for tabular digits, so prose in it overflows a narrow viewport. The
  // note carries the wait instead, where a sentence belongs.
  awaitServer() {
    this.panelTarget.classList.add("archive-upload--indeterminate")
    this.panelTarget.removeAttribute("aria-valuenow")
    this.labelTarget.textContent = "Unpacking on the server"
    this.percentTarget.textContent = ""
    this.noteTarget.textContent = "This can take a few minutes for a large archive. Keep this tab open."
  }

  // A success redirect is followed by XHR transparently, so responseURL is the
  // page to land on. Re-requesting it costs one GET and keeps Turbo's history
  // and cache authoritative, rather than hand-rendering a body it never saw.
  //
  // The only other answer this action gives is a 422 re-render of the form with
  // an inline alert. Swapping the body in place keeps that alert, and Stimulus
  // re-binds because it observes the document for added nodes.
  finish(xhr) {
    if (xhr.status >= 200 && xhr.status < 300) {
      window.location = xhr.responseURL || window.location.href
      return
    }

    if (xhr.status === 422 && xhr.responseText) {
      const replacement = new DOMParser().parseFromString(xhr.responseText, "text/html")
      document.body.replaceWith(replacement.body)
      return
    }

    this.fail("The server rejected the upload. Try again, or ask an admin to check the logs.")
  }

  // The label carries the reason and the note says what to do about it, so the
  // failure is never communicated by colour alone.
  fail(message) {
    this.panelTarget.classList.remove("archive-upload--indeterminate")
    this.panelTarget.classList.add("archive-upload--failed")
    this.labelTarget.textContent = "Upload failed"
    this.percentTarget.textContent = ""
    this.noteTarget.textContent = message
    this.submitTarget.disabled = false
  }

  setFraction(fraction) {
    const percent = Math.min(100, Math.round(fraction * 100))
    this.fillTarget.style.width = `${percent}%`
    this.percentTarget.textContent = `${percent}%`
    this.panelTarget.setAttribute("aria-valuenow", String(percent))
  }
}
