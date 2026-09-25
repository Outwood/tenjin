// The datepicker controller, mounted through Stimulus on the due-date input
// the new-homework form renders

import DatepickerController from "../../../app/javascript/controllers/datepicker_controller";
import { mountControllers, unmount } from "../support/stimulus";

const FIXTURE = `
  <input id="homework_due_date" type="text" data-controller="datepicker">
`;

describe("datepicker", () => {
  let application;

  beforeEach(async () => {
    application = await mountControllers(FIXTURE, {
      datepicker: DatepickerController,
    });
  });

  afterEach(() => unmount(application));

  it("starts the week on Monday", () => {
    const weekdays = [...document.querySelectorAll(".flatpickr-weekday")].map(
      (cell) => cell.textContent.trim(),
    );

    expect(weekdays).toEqual(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]);
  });
});
