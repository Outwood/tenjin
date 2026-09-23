// The quiz-starter controller, mounted through Stimulus on a dashboard row;
// the quiz create request goes through a stubbed csrfFetch and the move to
// wherever it was redirected through a stubbed Turbo

import QuizStarterController from "../../../app/javascript/controllers/quiz_starter_controller";
import csrfFetch from "../../../app/javascript/lib/csrf_fetch";
import { Turbo } from "@hotwired/turbo-rails";
import { mountControllers, unmount } from "../support/stimulus";

jest.mock("../../../app/javascript/lib/csrf_fetch", () => jest.fn());
jest.mock("@hotwired/turbo-rails", () => ({ Turbo: { visit: jest.fn() } }));

const row = (lessonAttribute = "") => `
  <table><tbody>
    <tr id="row" data-controller="quiz-starter"
        data-quiz-starter-url-value="/subjects/3/quizzes"
        data-quiz-starter-topic-value="7"
        ${lessonAttribute}
        data-action="click->quiz-starter#start">
      <td>Fractions</td>
    </tr>
  </tbody></table>
`;

// Lets the click's fetch resolve and the visit follow
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("quiz-starter", () => {
  let application;

  afterEach(() => {
    unmount(application);
    jest.resetAllMocks();
  });

  async function clickRow(fixture) {
    csrfFetch.mockResolvedValue({ ok: true, url: "http://test/quizzes/42" });
    application = await mountControllers(fixture, {
      "quiz-starter": QuizStarterController,
    });
    document.getElementById("row").click();
    await flush();
  }

  const postedQuiz = () => JSON.parse(csrfFetch.mock.calls[0][1].body).quiz;

  it("starts a topic quiz in the row's subject and follows the redirect", async () => {
    await clickRow(row());

    expect(csrfFetch.mock.calls[0][0]).toBe("/subjects/3/quizzes");
    expect(postedQuiz()).toEqual({ topic_id: "7" });
    expect(Turbo.visit).toHaveBeenCalledWith("http://test/quizzes/42");
  });

  it("starts a lesson quiz when the row carries a lesson", async () => {
    await clickRow(row('data-quiz-starter-lesson-value="11"'));

    expect(postedQuiz()).toEqual({ topic_id: "7", lesson_id: "11" });
  });
});
