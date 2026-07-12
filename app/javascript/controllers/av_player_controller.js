import { Controller } from "@hotwired/stimulus"

// Mounts video.js on an audio/video work's player. video.js (UMD, ~600KB) is
// imported dynamically here so only A/V work pages ever fetch it — the same
// posture as the Tify viewer. The media <source> points at the Range-capable
// /media/:id endpoint, so the player seeks via HTTP byte ranges.
export default class extends Controller {
  static targets = ["media"]
  static values = { audioPoster: Boolean }

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
    // audioPosterMode keeps the poster on screen for a sound recording (a bare
    // <audio> element can't show one), so audio-with-poster renders like video.
    this.player = window.videojs(this.mediaTarget, {
      controls: true,
      preload: "metadata",
      fluid: true,
      liveui: false,
      controlBar: { liveDisplay: false, seekToLive: false },
      audioPosterMode: this.audioPosterValue
    })
    // audioPosterMode mounts a sound recording on a <video> element (to show the
    // still), which leaves video.js's "Video Player" / "Play Video" labels on
    // what is audio. video.js re-applies those defaults at several points during
    // setup, so a one-shot fix gets overwritten — re-assert the audio labels
    // whenever the player's aria-label changes (the guard keeps it idempotent, so
    // no loop; the observer is torn down on disconnect).
    if (this.audioPosterValue) {
      this.player.ready(() => {
        this.relabelAsAudio()
        this.labelObserver = new MutationObserver(() => this.relabelAsAudio())
        this.labelObserver.observe(this.player.el(), { attributes: true, attributeFilter: ["aria-label"] })
      })
    }
  }

  relabelAsAudio() {
    const el = this.player.el()
    if (el.getAttribute("aria-label") !== "Audio Player") el.setAttribute("aria-label", "Audio Player")
    const bigPlay = this.player.getChild("BigPlayButton")
    if (bigPlay && bigPlay.controlText() !== "Play") bigPlay.controlText("Play")
  }

  disconnect() {
    this.labelObserver?.disconnect()
    this.player?.dispose?.()
  }
}
