// The confirm-text controller, mounted through Stimulus on the markup the
// reset-year and reset-passwords confirmations render

import ConfirmTextController from "../../../app/javascript/controllers/confirm_text_controller";
import { mountControllers, unmount } from "../support/stimulus";

const FIXTURE = `
  <div data-controller="confirm-text">
    <strong data-confirm-text-target="match"> reset year </strong>
    <input data-confirm-text-target="input" data-action="input->confirm-text#check">
    <button data-confirm-text-target="button" disabled>Reset</button>
  </div>
`;

describe("confirm-text", () => {
  let application, input, button;

  beforeEach(async () => {
    application = await mountControllers(FIXTURE, {
      "confirm-text": ConfirmTextController,
    });
    input = document.querySelector("input");
    button = document.querySelector("button");
  });

  afterEach(() => unmount(application));

  function type(value) {
    input.value = value;
    input.dispatchEvent(new Event("input", { bubbles: true }));
  }

  it("enables the button once the input matches the confirmation text", () => {
    type("reset year");

    expect(button.disabled).toBe(false);
  });

  it("disables the button again when the input stops matching", () => {
    type("reset year");
    type("reset yea");

    expect(button.disabled).toBe(true);
  });
});
