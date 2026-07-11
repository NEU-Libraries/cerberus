import { Controller } from "@hotwired/stimulus"

// Mounts video.js on an audio/video work's player. video.js (UMD, ~600KB) is
// imported dynamically here so only A/V work pages ever fetch it — the same
// posture as the Tify viewer. The media <source> points at the Range-capable
// /media/:id endpoint, so the player seeks via HTTP byte ranges.
export default class extends Controller {
  static targets = ["media"]

  async connect() {
    await import("video-js") // UMD build: registers window.videojs
    // With no poster, video.js still renders a <picture><img> whose blank src
    // resolves to the page URL — a broken image. Flag the no-poster case so CSS
    // hides .vjs-poster (posterless videos: rendition pending / poster failed).
    if (!this.mediaTarget.getAttribute("poster")) {
      this.element.classList.add("av-player--no-poster")
    }
    // DRS never serves live streams — everything is video-on-demand. video.js
    // paints a "LIVE" badge whenever it can't determine a finite duration (e.g.
    // a byte response without a definitive total), which is always misleading
    // here. Dropping the live-only controls means the badge can never render.
    this.player = window.videojs(this.mediaTarget, {
      controls: true,
      preload: "metadata",
      fluid: true,
      liveui: false,
      controlBar: { liveDisplay: false, seekToLive: false }
    })
  }

  disconnect() {
    this.player?.dispose?.()
  }
}
