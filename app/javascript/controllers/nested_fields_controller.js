import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["fields"];

  add(event) {
    event.preventDefault();
    const trigger = event.currentTarget;
    const time = new Date().getTime();
    const regexp = new RegExp(trigger.dataset.id, "g");
    this.fieldsTarget.insertAdjacentHTML(
      "beforeend",
      trigger.dataset.fields.replace(regexp, time),
    );
  }

  removeRow(event) {
    event.preventDefault();
    event.currentTarget.closest("tr").remove();
  }

  // A saved record stays in the form, hidden, for the next save to delete
  removeRecord(event) {
    event.preventDefault();
    const trigger = event.currentTarget;
    const input = document.createElement("input");
    input.type = "hidden";
    input.name = `${trigger.dataset.objectName}[_destroy]`;
    input.value = "true";
    trigger.after(input);
    trigger.closest("tr").hidden = true;
  }
}
