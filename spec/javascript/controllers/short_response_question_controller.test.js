// The short-response-question controller, mounted through Stimulus on the
// markup the short answer question renders; the server's verdict arrives
// through a stubbed fetch

import QuizStatsController from "../../../app/javascript/controllers/quiz_stats_controller";
import ShortResponseQuestionController from "../../../app/javascript/controllers/short_response_question_controller";
import { mountControllers, unmount } from "../support/stimulus";

const FIXTURE = `
  <div data-controller="quiz-stats">
    <span id="streak" data-quiz-stats-target="streak">0</span>
    <span id="answeredCorrect" data-quiz-stats-target="answeredCorrect">0</span>
    <span id="multiplier" data-quiz-stats-target="multiplier">1</span>
  </div>
  <div data-controller="short-response-question"
       data-short-response-question-quiz-stats-outlet="[data-controller~='quiz-stats']">
    <input data-short-response-question-target="input"
           data-action="keydown.enter->short-response-question#check">
    <button data-short-response-question-target="submitButton"
            data-action="click->short-response-question#check">Check Answer</button>
    <button class="invisible" data-short-response-question-target="nextButton">Next</button>
  </div>
`;

// Lets the click's fetch resolve and the verdict paint
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("short-response-question", () => {
  let application, input, submit, next;

  beforeEach(async () => {
    application = await mountControllers(FIXTURE, {
      "short-response-question": ShortResponseQuestionController,
      "quiz-stats": QuizStatsController,
    });
    input = document.querySelector("input");
    [submit, next] = document.querySelectorAll("button");
  });

  afterEach(() => {
    unmount(application);
    delete global.fetch;
  });

  async function check(guess, verdict) {
    global.fetch = jest
      .fn()
      .mockResolvedValue({ ok: true, json: async () => verdict });
    input.value = guess;
    submit.click();
    await flush();
  }

  it("posts the guess and paints the server's verdict rather than comparing the guess itself", async () => {
    await check("the autumn", {
      correct: false,
      answer: [{ text: "the autumn" }],
    });

    expect(global.fetch.mock.calls[0][1]).toMatchObject({
      method: "PUT",
      body: JSON.stringify({ answer: { short_answer: "the autumn" } }),
    });
    expect(submit.classList.contains("incorrect-answer")).toBe(true);
    expect(submit.textContent).toMatch(/^Incorrect/);
    expect(input.disabled).toBe(true);
    expect(next.classList.contains("invisible")).toBe(false);
  });

  it("marks a correct verdict", async () => {
    await check("anything", { correct: true, answer: [{ text: "To Autumn" }] });

    expect(submit.classList.contains("correct-answer")).toBe(true);
    expect(submit.textContent).toMatch(/^Correct!/);
    expect(input.value).toBe("anything");
  });

  it("reveals every accepted answer after a miss", async () => {
    await check("nope", {
      correct: false,
      answer: [{ text: "To Autumn" }, { text: "The Autumn" }],
    });

    expect(input.value).toBe("To Autumn or The Autumn");
    expect(input.classList.contains("correct-answer")).toBe(true);
  });

  it("puts a check on a correct verdict", async () => {
    await check("Paris", { correct: true, answer: [{ text: "Paris" }] });

    expect(submit.querySelector("i.fa-check")).not.toBeNull();
    expect(submit.querySelector("i.fa-times")).toBeNull();
  });

  it("puts a cross on a wrong verdict", async () => {
    await check("London", { correct: false, answer: [{ text: "Paris" }] });

    expect(submit.querySelector("i.fa-times")).not.toBeNull();
    expect(submit.querySelector("i.fa-check")).toBeNull();
  });

  it("passes the returned stats to the quiz stats", async () => {
    await check("Paris", {
      correct: true,
      answer: [{ text: "Paris" }],
      streak: 3,
      answeredCorrect: 5,
      multiplier: 2,
    });

    expect(document.getElementById("streak").textContent).toBe("3");
    expect(document.getElementById("answeredCorrect").textContent).toBe("5");
    expect(document.getElementById("multiplier").textContent).toBe("2");
  });
});
