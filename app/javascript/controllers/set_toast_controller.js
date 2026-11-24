import { Controller } from "@hotwired/stimulus"

const SHOWN_FOR = 8000

// The status region must already be in the page, empty, when its text lands:
// a live region announces a change, not the text it arrives with.
const ANNOUNCE_AFTER = 150

// Raises the set-aside teaching toast (server-rendered from flash[:aside])
// and retires it after a beat. The Undo inside is a plain put-back form —
// no client state lives here, so a missed dismissal costs nothing.
export default class extends Controller {
  static targets = ["message", "announce"]

  // A toast is raised once. disconnect() retires it before Turbo caches the
  // page, so a restored copy arrives hidden and must not announce again.
  connect() {
    if (this.element.hidden) return

    requestAnimationFrame(() => this.element.classList.add("show"))
    this.announceTimer = setTimeout(() => this.announce(), ANNOUNCE_AFTER)
    this.arm()
  }

  disconnect() {
    clearTimeout(this.timer)
    clearTimeout(this.announceTimer)
    this.element.classList.remove("show")
    this.element.hidden = true
    this.announceTarget.textContent = ""
  }

  announce() {
    const text = this.messageTarget.textContent.replace(/\s+/g, " ").trim()
    this.announceTarget.textContent = `${text} Undo available.`
  }

  arm() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.dismiss(), SHOWN_FOR)
  }

  // Never retire the toast while focus is on its Undo: hiding it would drop
  // the keyboard user's focus back to the top of the page.
  pause() {
    clearTimeout(this.timer)
  }

  resume(event) {
    if (!this.element.contains(event.relatedTarget)) this.arm()
  }

  // The fade is opacity only, which leaves Undo focusable while invisible, so
  // the toast leaves the page once the fade has run.
  async dismiss() {
    this.element.classList.remove("show")
    await Promise.allSettled(this.element.getAnimations().map((animation) => animation.finished))
    this.element.hidden = true
    this.announceTarget.textContent = ""
  }
}
