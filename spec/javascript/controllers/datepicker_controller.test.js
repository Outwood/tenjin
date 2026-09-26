// The datepicker controller, mounted through Stimulus on the due-date input
// the new-homework form renders

import DatepickerController from "../../../app/javascript/controllers/datepicker_controller";
import { mountControllers, unmount } from "../support/stimulus";

const FIXTURE = `
  <label for="homework_due_date">Due date</label>
  <input id="homework_due_date" type="text" name="homework[due_date]"
         value="2030-10-08 23:59" aria-describedby="homework_due_date_error"
         aria-invalid="true" data-controller="datepicker">
  <div id="homework_due_date_error">Due date can't be in the past</div>
`;

describe("datepicker", () => {
  let application;

  beforeEach(async () => {
    application = await mountControllers(FIXTURE, {
      datepicker: DatepickerController,
    });
  });

  afterEach(() => unmount(application));

  const submitted = () => document.querySelector("[name='homework[due_date]']");
  const labelled = () =>
    document.getElementById(
      document.querySelector("label").getAttribute("for"),
    );

  it("starts the week on Monday", () => {
    const weekdays = [...document.querySelectorAll(".flatpickr-weekday")].map(
      (cell) => cell.textContent.trim(),
    );

    expect(weekdays).toEqual(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]);
  });

  it("shows the due time as the app writes it, and submits it unchanged", () => {
    expect(labelled().value).toBe("8 Oct 2030, 23:59");
    expect(submitted().value).toBe("2030-10-08 23:59");
  });

  it("points the label at the field shown, which takes no typing", () => {
    expect(labelled()).not.toBe(submitted());
    expect(labelled().type).toBe("text");
    expect(labelled().readOnly).toBe(true);
  });

  it("moves the error's description onto the field shown", () => {
    expect(labelled().getAttribute("aria-describedby")).toBe(
      "homework_due_date_error",
    );
    expect(labelled().getAttribute("aria-invalid")).toBe("true");
    expect(submitted().hasAttribute("aria-describedby")).toBe(false);
  });

  it("hands the naming back to the input when disconnected", async () => {
    const input = submitted();
    input.removeAttribute("data-controller");
    await Promise.resolve();

    expect(input.id).toBe("homework_due_date");
    expect(input.getAttribute("aria-describedby")).toBe(
      "homework_due_date_error",
    );
  });
});

describe("datepicker sent back with a past due date", () => {
  let application;

  beforeEach(async () => {
    application = await mountControllers(
      `<input id="homework_due_date" type="text" name="homework[due_date]"
              value="2020-01-01 10:00" data-controller="datepicker">`,
      { datepicker: DatepickerController },
    );
  });

  afterEach(() => unmount(application));

  it("still shows the date", () => {
    expect(document.getElementById("homework_due_date").value).toBe(
      "1 Jan 2020, 10:00",
    );
  });

  it("submits it unchanged", () => {
    expect(document.getElementsByName("homework[due_date]")[0].value).toBe(
      "2020-01-01 10:00",
    );
  });

  it("still offers no day before today", () => {
    const picker =
      document.getElementsByName("homework[due_date]")[0]._flatpickr;
    const day = 24 * 60 * 60 * 1000;

    expect(picker.isEnabled(new Date(Date.now() - day), true)).toBe(false);
    expect(picker.isEnabled(new Date(Date.now() + day), true)).toBe(true);
  });
});
