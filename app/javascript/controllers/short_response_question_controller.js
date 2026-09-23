import { Controller } from "@hotwired/stimulus";
import csrfFetch from "../lib/csrf_fetch";

export default class extends Controller {
  static targets = ["input", "submitButton", "nextButton"];
  static outlets = ["quiz-stats"];

  async check(event) {
    event.preventDefault();
    const guess = this.inputTarget.value;
    this.submitButtonTarget.setAttribute("disabled", "disabled");
    this.inputTarget.setAttribute("disabled", "disabled");

    const response = await csrfFetch(window.location.pathname, {
      method: "PUT",
      body: JSON.stringify({ answer: { short_answer: guess } }),
    });
    // A refusal leaves the server on this question, so the page is stale:
    // show it as it now stands rather than a dead input
    if (!response.ok) {
      this.reload();
      return;
    }
    const payload = await response.json();

    this._mark(payload);
    if (this.hasQuizStatsOutlet) this.quizStatsOutlet.update(payload);

    this.nextButtonTarget.classList.remove("invisible");
    this.nextButtonTarget.focus();
  }

  reload() {
    location.reload();
  }

  // The server decides correctness; the answers are only for the reveal
  _mark({ correct, answer }) {
    const button = this.submitButtonTarget;

    if (correct) {
      button.classList.add("correct-answer");
      button.textContent = "Correct!";
      button.insertAdjacentHTML(
        "beforeend",
        '<i class="fas fa-check fa-lg float-right my-1 ms-2"></i>',
      );
      return;
    }
    button.classList.add("incorrect-answer");
    button.textContent = "Incorrect";
    button.insertAdjacentHTML(
      "beforeend",
      '<i class="fas fa-times fa-lg float-right my-1 ms-2"></i>',
    );
    if (answer.length) {
      this.inputTarget.classList.add("correct-answer");
      this.inputTarget.value = answer.map((r) => r.text).join(" or ");
    }
  }
}
