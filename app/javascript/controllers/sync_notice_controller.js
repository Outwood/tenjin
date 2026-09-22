import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["status"];
  static values = { neededLabel: String };

  // Flips the notice to "sync needed" before the write has been answered
  notify(event) {
    this.pending ??= [];
    this.before ??= this.statusTarget.textContent;
    this.pending.push(event.target.form);
    this.statusTarget.textContent = this.neededLabelValue;
  }

  // The notice belongs to every submission it was flipped for, so it goes back
  // only once all of them have answered and none of them landed. A form
  // resubmitted before its answer is counted once per submission, since Turbo
  // answers the abandoned one too
  settle(event) {
    if (!this.#retire(event.target)) return;
    this.landed ||= event.detail.success;
    if (this.pending.length) return;

    if (!this.landed) this.statusTarget.textContent = this.before;
    this.before = null;
    this.landed = false;
  }

  #retire(form) {
    const index = this.pending?.indexOf(form) ?? -1;
    if (index < 0) return false;
    this.pending.splice(index, 1);
    return true;
  }
}
