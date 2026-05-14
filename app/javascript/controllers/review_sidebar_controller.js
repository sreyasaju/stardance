import { Controller } from "@hotwired/stimulus";

// Transforms the review detail sidebar from sticky to a slide-out popup when
// the "boss note" section becomes visible. Returns to normal when scrolling back up.
//
// Targets:
//   - sidebar: The right sidebar element to transform
//   - trigger: The element that triggers the transformation (boss note card)
//   - toggle: The button that opens/closes the popup
//
// CSS Classes:
//   - is-popup-mode: Added to sidebar when boss note is visible
//   - is-open: Added to sidebar when popup is manually opened

export default class extends Controller {
  static targets = ["sidebar", "trigger", "toggle"];

  connect() {
    console.log("Review sidebar controller connected!");
    if (typeof IntersectionObserver === "undefined") return;

    // Track popup open state
    this.isOpen = false;

    // Observe the trigger element (boss note card)
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            // Boss note is visible - transform to popup mode
            console.log("Boss note visible - activating popup mode");
            this.sidebarTarget.classList.add("is-popup-mode");
          } else {
            // Scrolled back up - return to normal mode
            console.log("Boss note hidden - returning to normal mode");
            this.sidebarTarget.classList.remove("is-popup-mode");
            this.sidebarTarget.classList.remove("is-open");
            this.isOpen = false;
          }
        });
      },
      {
        // Trigger when any part of the element enters the viewport
        threshold: 0,
        rootMargin: "0px",
      }
    );

    this.observer.observe(this.triggerTarget);
  }

  disconnect() {
    this.observer?.disconnect();
  }

  // Toggle the popup open/closed
  togglePopup() {
    this.isOpen = !this.isOpen;
    this.sidebarTarget.classList.toggle("is-open", this.isOpen);
  }

  // Explicitly close the popup (for click-outside behavior if needed)
  closePopup() {
    this.isOpen = false;
    this.sidebarTarget.classList.remove("is-open");
  }
}
