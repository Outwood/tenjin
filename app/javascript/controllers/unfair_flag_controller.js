import { Controller } from "@hotwired/stimulus";
import { Modal } from "bootstrap";
import csrfFetch from "../lib/csrf_fetch";

export default class extends Controller {
  async flag(event) {
    event.preventDefault();
    // A second click before the first answers would send the same verb again
    if (this.pending) return;
    this.pending = true;
    try {
      await this.#send();
    } finally {
      this.pending = false;
    }
  }

  async #send() {
    const icon = this.element.querySelector("i.fa-flag");
    const flagging = icon.classList.contains("far");
    const method = flagging ? "POST" : "DELETE";
    const response = await csrfFetch(this.element.href, { method });
    if (!response.ok) {
      console.error(`Flag question ${method} failed`, response.status);
      return;
    }

    if (flagging) {
      icon.classList.replace("far", "fas");
      Modal.getOrCreateInstance(
        document.getElementById("feedbackModal"),
      ).show();
    } else {
      icon.classList.replace("fas", "far");
    }
  }
}
