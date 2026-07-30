import { Controller } from "@hotwired/stimulus"

// A GET <form> submission never sends the #fragment portion of its action to
// the server — browsers strip it before building the navigation target — so
// a form nested inside a tab-hash-controlled tab (see tab_hash_controller.js)
// silently kicks the page back to whatever tab is .active by default once
// submitted. Reconstructs the GET navigation by hand instead, so the form's
// own action URL (fragment included) survives.
export default class extends Controller {
  submit(event) {
    event.preventDefault()

    const form = event.target
    const url = new URL(form.action, window.location.href)
    new FormData(form).forEach((value, key) => url.searchParams.set(key, value))
    window.location = url.toString()
  }
}
