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

    this.timeout = setTimeout(() => this.reload(), this.intervalValue)
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  reload() {
    const frame = this.element.closest("turbo-frame")
    if (!frame) return

    if (frame.src) {
      frame.reload()
    } else {
      frame.src = this.urlValue
    }
  }
}
