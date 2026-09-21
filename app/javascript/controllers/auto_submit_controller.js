import { Controller } from "@hotwired/stimulus";

// Submits the form as soon as a field changes, and puts the fields back to the
// state the server last accepted when it refuses the write
export default class extends Controller {
  connect() {
    this.accepted = this.#snapshot();
  }

  submit() {
    this.element.requestSubmit();
  }

  // A submission Turbo abandoned for a newer one answers with no verdict, so
  // the fields stay as they are for the newer write to settle
  settle(event) {
    if (event.detail.success === true) this.accepted = this.#snapshot();
    if (event.detail.success === false) this.#restore(this.accepted);
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
