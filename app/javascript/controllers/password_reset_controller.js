import { Controller } from "@hotwired/stimulus";
import { Modal } from "bootstrap";
import csrfFetch from "../lib/csrf_fetch";

// Resets a user's password from their row's menu: the modal asks first, then
// shows the new password to read out or copy
export default class extends Controller {
  static targets = [
    "modal",
    "title",
    "confirmStep",
    "error",
    "resultStep",
    "password",
    "copyButton",
  ];

  confirm({ params: { url, name } }) {
    this.url = url;
    this.name = name;
    this.titleTarget.textContent = `Reset ${name}'s password?`;
    this.#showError(null);
    this.confirmStepTarget.hidden = false;
    this.resultStepTarget.hidden = true;
    Modal.getOrCreateInstance(this.modalTarget).show();
  }

  async reset() {
    // A second click before the first answers would reset the password again
    if (this.pending) return;
    this.pending = true;
    try {
      const response = await csrfFetch(this.url, { method: "POST" });
      const body = await response.json().catch(() => ({}));
      if (response.ok) {
        this.#showPassword(body.password);
      } else {
        this.#showError(body.errors?.join(", ") || "Password reset failed");
      }
    } catch {
      this.#showError("Password reset failed");
    } finally {
      this.pending = false;
    }
  }

  async copy() {
    await navigator.clipboard.writeText(this.passwordTarget.textContent);
    this.copyButtonTarget.textContent = "Copied";
  }

  #showPassword(password) {
    this.titleTarget.textContent = `New password for ${this.name}`;
    this.passwordTarget.textContent = password;
    this.copyButtonTarget.textContent = "Copy";
    this.confirmStepTarget.hidden = true;
    this.resultStepTarget.hidden = false;
  }

  // The message carries a record's own validation text, so it is written as text
  #showError(message) {
    this.errorTarget.textContent = message ?? "";
    this.errorTarget.hidden = !message;
  }
}
