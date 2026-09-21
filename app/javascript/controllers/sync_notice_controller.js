import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["status", "button"];
  static values = { neededLabel: String };

  // Flips the page to "sync needed" before the write has been answered
  notify(event) {
    this.pending ??= [];
    this.before ??= this.#snapshot();
    this.pending.push(event.target.form);

    this.statusTarget.textContent = this.neededLabelValue;
    if (!this.hasButtonTarget) return; // sync-status helper renders text instead of a button mid-sync
    this.buttonTarget.classList.remove("btn-primary");
    this.buttonTarget.classList.add("btn-danger");
    this.buttonTarget.textContent =
      "School sync required. Click here to start.";
  }

  // The notice belongs to every submission it was flipped for, so it goes back
  // only once all of them have answered and none of them landed. A form
  // resubmitted before its answer is counted once per submission, since Turbo
  // answers the abandoned one too
  settle(event) {
    if (!this.#retire(event.target)) return;
    this.landed ||= event.detail.success;
    if (this.pending.length) return;

    if (!this.landed) this.#restore(this.before);
    this.before = null;
    this.landed = false;
  }

  #retire(form) {
    const index = this.pending?.indexOf(form) ?? -1;
    if (index < 0) return false;
    this.pending.splice(index, 1);
    return true;
  }

  #snapshot() {
    return {
      status: this.statusTarget.textContent,
      button: this.hasButtonTarget && {
        className: this.buttonTarget.className,
        text: this.buttonTarget.textContent,
      },
    };
  }

  #restore(before) {
    this.statusTarget.textContent = before.status;
    if (!before.button) return;
    this.buttonTarget.className = before.button.className;
    this.buttonTarget.textContent = before.button.text;
  }
}
