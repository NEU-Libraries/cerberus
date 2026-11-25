import bootstrap from "bootstrap"

// Turbo snapshots a page as it leaves it, so anything open at that moment is
// cached open, and Back restores it with no Bootstrap instance behind it.
// Each is put back to closed before the snapshot. docs/design.md covers why.

// A restored modal shows with its backdrop and the body's scroll lock, but its
// close button does nothing.
function closeModals() {
  document.querySelectorAll(".modal.show").forEach((modal) => {
    bootstrap.Modal.getInstance(modal)?.dispose()
    modal.classList.remove("show")
    modal.style.display = "none"
    modal.setAttribute("aria-hidden", "true")
    modal.removeAttribute("aria-modal")
    modal.removeAttribute("role")
  })
  document.querySelectorAll(".modal-backdrop").forEach((backdrop) => backdrop.remove())
  document.body.classList.remove("modal-open")
  document.body.style.removeProperty("overflow")
  document.body.style.removeProperty("padding-right")
}

// A restored dropdown ignores an outside click and Escape, which only close a
// menu that has an instance. A dropdown closes without a transition, so its
// own hide() leaves nothing half-closed in the snapshot.
function closeDropdowns() {
  document.querySelectorAll('[data-bs-toggle="dropdown"].show').forEach((toggle) => {
    bootstrap.Dropdown.getOrCreateInstance(toggle).hide()
  })
}

// The phone navbar panel only: a facet a reader opened should stay open.
// Collapse.hide() animates and would cache the panel mid-transition, so the
// classes are reset directly.
function closeNavbarPanels() {
  document.querySelectorAll(".navbar-collapse.show").forEach((panel) => {
    bootstrap.Collapse.getInstance(panel)?.dispose()
    panel.classList.remove("show")
    document.querySelectorAll(`[data-bs-toggle="collapse"][data-bs-target="#${panel.id}"]`).forEach((toggler) => {
      toggler.classList.add("collapsed")
      toggler.setAttribute("aria-expanded", "false")
    })
  })
}

document.addEventListener("turbo:before-cache", () => {
  closeModals()
  closeDropdowns()
  closeNavbarPanels()
})

// The browser's own back-forward cache is a second way back. A visit that
// falls back to a full page load freezes this document with `<html>` still
// busy, and Turbo clears that only when a visit completes. Without this, the
// restored page keeps the progress cursor until the next click.
window.addEventListener("pageshow", (event) => {
  if (event.persisted) document.documentElement.removeAttribute("aria-busy")
})
