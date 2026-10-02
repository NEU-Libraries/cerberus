import { Controller } from "@hotwired/stimulus"

// Polls a LoadReport's turbo-frame while its background ingest is still
// running, then stops once the report reaches a terminal status.
//
// The controller lives *inside* the frame content (rendered by
// loads/_report), so every frame reload disconnects the old instance and
// connects a fresh one carrying the latest `terminal` value — no stale
// closures, no interval that outlives the work. When `terminal` is true
// (completed / completed_with_warnings / failed) connect() is a no-op and
// the polling chain ends naturally.
//
// The frame has no markup src (a frame whose src is its own page is
// rejected by Turbo as a self-reference). Instead the first poll sets the
// src to kick off a load; subsequent polls reload() the existing src. The
// server renders that response without a src too, so it never self-refs.
export default class extends Controller {
  static values = {
    terminal: Boolean,
    url: String,
    interval: { type: Number, default: 3000 }
  }

  connect() {
    if (this.terminalValue) return

    // A failed reload leaves this content, and this instance, in place: no
    // fresh connect() runs to schedule the next poll, so one bad response would
    // stop the page updating for good. Each failure shape needs its own hook:
    // a non-2xx response (HTML or not) is seen only in before-fetch-response,
    // a network failure only in fetch-request-error, and a 2xx page without
    // this frame (a sign-in redirect) only in frame-missing, whose default
    // would also blank the report.
    this.frame = this.element.closest("turbo-frame")
    this.retry = () => this.schedule()
    this.inspect = (event) => { if (!event.detail.fetchResponse.succeeded) this.schedule() }
    this.missing = (event) => { event.preventDefault(); this.schedule() }
    this.frame?.addEventListener("turbo:before-fetch-response", this.inspect)
    this.frame?.addEventListener("turbo:fetch-request-error", this.retry)
    this.frame?.addEventListener("turbo:frame-missing", this.missing)

    this.schedule()
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
    this.frame?.removeEventListener("turbo:before-fetch-response", this.inspect)
    this.frame?.removeEventListener("turbo:fetch-request-error", this.retry)
    this.frame?.removeEventListener("turbo:frame-missing", this.missing)
  }

  schedule() {
    if (this.timeout) clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.reload(), this.intervalValue)
  }

  reload() {
    if (!this.frame) return

    if (this.frame.src) {
      this.frame.reload()
    } else {
      this.frame.src = this.urlValue
    }
  }
}
