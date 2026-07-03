import { Controller } from "@hotwired/stimulus"

// The Derivative access tab's per-tier toggle: a tier's group picker is shown
// only when "Restrict to groups" is chosen. One controller spans the whole
// ladder; the changed radio locates its own tier via the DOM, so the four tiers
// stay independent without a controller instance each.
export default class extends Controller {
  toggle(event) {
    const tier = event.target.closest(".derivative-tier")
    const groups = tier?.querySelector(".derivative-tier__groups")
    groups?.classList.toggle("d-none", event.target.value !== "restrict")
  }
}
