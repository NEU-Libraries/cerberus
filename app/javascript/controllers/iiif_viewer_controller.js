import { Controller } from "@hotwired/stimulus"

// Mounts the Tify IIIF viewer on multipage work show pages. Tify (which
// bundles Vue + OpenSeadragon, ~440KB) is imported dynamically here, so
// only pages that actually mount a viewer ever fetch it. view: "" opens
// on the bare scan pane — the compact chrome is finished off in
// _iiif_viewer.scss (page-turning + zoom only).
export default class extends Controller {
  static values = { url: String }

  async connect() {
    await import("tify") // IIFE build: registers window.Tify
    this.viewer = new window.Tify({
      container: this.element,
      manifestUrl: this.urlValue,
      view: ""
    })
  }

  disconnect() {
    this.viewer?.destroy?.()
  }
}
