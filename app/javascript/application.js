// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import $ from "jquery"
import bootstrap from "bootstrap"
import githubAutoCompleteElement from "@github/auto-complete-element"
import Blacklight from "blacklight"

Turbo.setProgressBarDelay(750)

let turboVisitActive = false
document.addEventListener('turbo:before-visit', () => { turboVisitActive = true })
document.addEventListener('turbo:load', () => { turboVisitActive = false })

document.addEventListener('turbo:before-fetch-response', async (event) => {
  if (!turboVisitActive) return
  const { fetchResponse } = event.detail
  if (!fetchResponse.succeeded) {
    event.preventDefault()
    window.location.href = fetchResponse.response.url
  }
})

window.$ = $
window.jQuery = $
