// The multiple-choice-question controller, mounted through Stimulus on the
// markup the question renders; the server's verdict arrives through a
// stubbed fetch

import MultipleChoiceQuestionController from "../../../app/javascript/controllers/multiple_choice_question_controller";
import { mountControllers, unmount } from "../support/stimulus";

const FIXTURE = `
  <div data-controller="multiple-choice-question"
       data-multiple-choice-question-quiz-stats-outlet="[data-controller~='quiz-stats']">
    <button id="response-1" data-multiple-choice-question-target="button"
            data-action="click->multiple-choice-question#select">Paris</button>
    <button id="response-2" data-multiple-choice-question-target="button"
            data-action="click->multiple-choice-question#select">Rome</button>
    <button class="invisible" id="nextButton"
            data-multiple-choice-question-target="nextButton">Next Question</button>
  </div>
`;

// Lets the click's fetch resolve and the verdict paint
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("multiple-choice-question", () => {
  let application, reload;

  beforeEach(async () => {
    // jsdom cannot navigate, so the reload is observed at the controller's seam
    reload = jest
      .spyOn(MultipleChoiceQuestionController.prototype, "reload")
      .mockImplementation(() => {});
    application = await mountControllers(FIXTURE, {
      "multiple-choice-question": MultipleChoiceQuestionController,
    });
  });

  afterEach(() => {
    unmount(application);
    reload.mockRestore();
    delete global.fetch;
  });

  async function select(id, response) {
    global.fetch = jest.fn().mockResolvedValue(response);
    document.getElementById(id).click();
    await flush();
  }

  const classes = (id) => document.getElementById(id).classList;

  it("paints the server's verdict and offers the next question", async () => {
    await select("response-2", {
      ok: true,
      json: async () => ({ correct: false, answer: [{ id: 1 }] }),
    });

    expect(classes("response-1").contains("correct-answer")).toBe(true);
    expect(classes("response-2").contains("incorrect-answer")).toBe(true);
    expect(classes("nextButton").contains("invisible")).toBe(false);
    expect(reload).not.toHaveBeenCalled();
  });

  it("reloads the page when the server refuses the guess", async () => {
    await select("response-2", { ok: false, status: 422 });

    expect(reload).toHaveBeenCalled();
    expect(classes("nextButton").contains("invisible")).toBe(true);
  });
});
