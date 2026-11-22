import bootstrap from "bootstrap"

// Turbo snapshots a page as it leaves it, so a modal open at that moment is
// cached open. Back restores it shown, with its backdrop and the body's scroll
// lock, but Bootstrap holds no state for the restored copy, so its close
// button does nothing. Every modal is put back to closed before the snapshot.
document.addEventListener("turbo:before-cache", () => {
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
})
