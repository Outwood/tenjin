import { Controller } from "@hotwired/stimulus";

// Submits the form as soon as a field changes, and puts the fields back to the
// state the server last accepted when it refuses the write
export default class extends Controller {
  static targets = ["status"];

  connect() {
    this.accepted = this.#snapshot();
  }

  submit() {
    this.#say("Saving…");
    this.element.requestSubmit();
  }

  // A submission Turbo abandoned for a newer one answers with no verdict, so
  // the fields stay as they are for the newer write to settle
  settle(event) {
    if (event.detail.success === true) {
      this.accepted = this.#snapshot();
      this.#say("Saved");
    }
    if (event.detail.success === false) {
      this.#restore(this.accepted);
      // The refusal's flash says why; the status only ever claims a save
      this.#say("");
    }
  }

  #say(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text;
  }

  #snapshot() {
    return Array.from(this.element.elements).map((field) => ({
      field,
      value: field.value,
      checked: field.checked,
    }));
  }

  #restore(accepted) {
    accepted.forEach(({ field, value, checked }) => {
      field.value = value;
      field.checked = checked;
    });
  }
}
