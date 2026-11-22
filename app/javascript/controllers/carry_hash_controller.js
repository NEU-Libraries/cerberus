import { Controller } from "@hotwired/stimulus"

// The tab-hash row records the open tab in the URL fragment, but a GET form
// drops the fragment when it submits, and a server-built link carries at most
// a fixed one, so either reloads the page on the wrong tab. Puts the current
// fragment on every same-page navigation that starts inside this element.
export default class extends Controller {
  submit(event) {
    const form = event.target
    if (form.method.toLowerCase() !== "get") return

    const url = this.samePageUrl(form.action)
    if (!url) return

    event.preventDefault()
    url.search = new URLSearchParams(new FormData(form, event.submitter)).toString()
    url.hash = window.location.hash
    window.location.assign(url.toString())
  }

  // Rewrites the href in place rather than navigating, so Turbo still follows
  // the link once this click bubbles up to it.
  click(event) {
    const link = event.target.closest("a[href]")
    if (!link || !this.element.contains(link)) return

    const url = this.samePageUrl(link.href)
    if (!url) return

    url.hash = window.location.hash
    link.href = url.toString()
  }

  samePageUrl(href) {
    if (!window.location.hash) return null

    const url = new URL(href, window.location.href)
    if (url.origin !== window.location.origin || url.pathname !== window.location.pathname) return null
    return url
  }
}
