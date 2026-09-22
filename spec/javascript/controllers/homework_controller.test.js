// The homework form's lesson picker, mounted through Stimulus over the
// topic and lesson selects the new-homework page renders

import HomeworkController from "../../../app/javascript/controllers/homework_controller";
import { mountControllers, unmount } from "../support/stimulus";

const lessons = [
  { id: 11, topic_id: 7, title: "Equivalent fractions" },
  { id: 12, topic_id: 8, title: "Photosynthesis" },
];

const form = `
  <div data-controller="homework"
       data-homework-lessons-value='${JSON.stringify(lessons)}'>
    <select id="topic" data-action="change->homework#loadLessons">
      <option value=""></option>
      <option value="7">Fractions</option>
      <option value="8">Plants</option>
    </select>
    <select id="lesson" data-homework-target="lessonSelect" disabled></select>
  </div>
`;

describe("homework", () => {
  let application;

  afterEach(() => unmount(application));

  async function selectTopic(topicId) {
    application = await mountControllers(form, {
      homework: HomeworkController,
    });
    const topic = document.getElementById("topic");
    topic.value = topicId;
    topic.dispatchEvent(new Event("change"));
  }

  const lessonSelect = () => document.getElementById("lesson");
  const lessonTitles = () =>
    Array.from(lessonSelect().options, (option) => option.textContent);

  it("lists lessons for the selected topic", async () => {
    await selectTopic("7");

    expect(lessonTitles()).toContain("Equivalent fractions");
    expect(lessonSelect().disabled).toBe(false);
  });

  it("does not list another topic's lesson", async () => {
    await selectTopic("7");

    expect(lessonTitles()).not.toContain("Photosynthesis");
  });
});
