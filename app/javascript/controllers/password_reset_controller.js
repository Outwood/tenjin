import { Controller } from "@hotwired/stimulus";
import csrfFetch from "../lib/csrf_fetch";

export default class extends Controller {
  async reset(event) {
    event.preventDefault();
    const response = await csrfFetch(this.element.href, { method: "POST" });
    const body = await response.json().catch(() => ({}));
    // Tabulator renders cells as `div.tabulator-cell` rather than `<td>`.
    const cell = this.element.closest("td, .tabulator-cell");

    if (response.ok) {
      this.#replace(cell, "new-password", body.password);
    } else {
      this.#replace(
        cell,
        "reset-password-error text-danger small",
        body.errors?.join(", ") || "Password reset failed",
      );
    }
  }

  // The message carries a record's own validation text, so it is written as text
  #replace(cell, className, text) {
    const result = document.createElement("div");
    result.className = className;
    result.textContent = text;
    cell.replaceChildren(result);
  }
}
