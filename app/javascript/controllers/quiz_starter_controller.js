import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";
import csrfFetch from "../lib/csrf_fetch";

export default class extends Controller {
  static values = { url: String, topic: String, lesson: String };

  async start() {
    const row = this.element;
    if (row.hasAttribute("disabled")) return;
    row.setAttribute("disabled", "disabled");
    const body = {
      quiz: { topic_id: this.topicValue },
    };
    if (this.hasLessonValue && this.lessonValue)
      body.quiz.lesson_id = this.lessonValue;
    const response = await csrfFetch(this.urlValue, {
      method: "POST",
      body: JSON.stringify(body),
      headers: { Accept: "text/html" },
    });
    if (!response.ok) {
      console.error("Quiz create failed", response.status);
      row.removeAttribute("disabled");
      return;
    }
    // The fetch has followed the redirect to the new quiz, or to the refusal
    Turbo.visit(response.url);
  }
}
