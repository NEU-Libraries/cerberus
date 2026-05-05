// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import $ from "jquery"
import bootstrap from "bootstrap"
import githubAutoCompleteElement from "@github/auto-complete-element"
import Blacklight from "blacklight"

Turbo.setProgressBarDelay(750)

// Track the URL of the active Turbo visit so we only intercept the response
// for that visit — not unrelated fetches (e.g. link-hover prefetches) that
// can land while the visit is still in flight.
let activeVisitUrl = null
document.addEventListener('turbo:before-visit', (event) => { activeVisitUrl = event.detail.url })
document.addEventListener('turbo:load', () => { activeVisitUrl = null })

document.addEventListener('turbo:before-fetch-response', (event) => {
  if (!activeVisitUrl) return
  const { fetchResponse } = event.detail
  if (fetchResponse.response.url !== activeVisitUrl) return
  if (!fetchResponse.succeeded) {
    event.preventDefault()
    window.location.href = fetchResponse.response.url
  }
})

window.$ = $
window.jQuery = $
