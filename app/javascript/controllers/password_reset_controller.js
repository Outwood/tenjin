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
    "resetButton",
    "dismiss",
  ];

  confirm({ params: { url, name } }) {
    // The modal cannot close while a reset waits, but a menu can still be reached by keyboard
    if (this.pending) return;
    this.url = url;
    this.name = name;
    this.titleTarget.textContent = `Reset ${name}'s password?`;
    this.#showError(null);
    this.confirmStepTarget.hidden = false;
    this.resultStepTarget.hidden = true;
    Modal.getOrCreateInstance(this.modalTarget).show();
  }

  // Closing mid-reset would lose the new password, or let another user's
  // confirmation take its place and show it under their name
  holdOpen(event) {
    if (this.pending) event.preventDefault();
  }

  async reset() {
    // A second click before the first answers would reset the password again
    if (this.pending) return;
    const { url, name } = this;
    this.#setPending(true);
    try {
      const response = await csrfFetch(url, { method: "POST" });
      const body = await response.json().catch(() => ({}));
      // A refused authorization redirects, and fetch follows it to a page of
      // HTML that answers 200, so only a reply carrying a password is a reset
      if (response.ok && body.password) {
        this.#showPassword(name, body.password);
      } else {
        this.#showError(body.errors?.join(", ") || "Password reset failed");
      }
    } catch {
      this.#showError("Password reset failed");
    } finally {
      this.#setPending(false);
    }
  }

  async copy() {
    await navigator.clipboard.writeText(this.passwordTarget.textContent);
    this.copyButtonTarget.textContent = "Copied";
  }

  #setPending(pending) {
    this.pending = pending;
    this.resetLabel ??= this.resetButtonTarget.textContent;
    this.resetButtonTarget.textContent = pending
      ? "Resetting…"
      : this.resetLabel;
    this.resetButtonTarget.disabled = pending;
    this.dismissTargets.forEach((button) => (button.disabled = pending));
  }

  #showPassword(name, password) {
    this.titleTarget.textContent = `New password for ${name}`;
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
