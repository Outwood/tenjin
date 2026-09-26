import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["lessonSelect"];
  static values = { lessons: Array };

  loadLessons(event) {
    const topicId = event.target.value;
    const matching = this.lessonsValue.filter(
      (l) => String(l.topic_id) === String(topicId),
    );
    // The server renders the blank choice, which names what leaving it means
    const blank = this.lessonSelectTarget.options[0];
    const options = matching.map((l) => {
      const opt = document.createElement("option");
      opt.value = l.id;
      opt.textContent = l.title;
      return opt;
    });
    this.lessonSelectTarget.replaceChildren(blank, ...options);
    blank.selected = true;
    this.lessonSelectTarget.disabled = matching.length === 0;
  }
}
