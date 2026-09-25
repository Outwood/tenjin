// The password-reset controller, mounted through Stimulus on a row's menu item
// and the confirmation modal the page renders; the reset itself arrives
// through a stubbed fetch

import { Modal } from "bootstrap";
import PasswordResetController from "../../../app/javascript/controllers/password_reset_controller";
import csrfFetch from "../../../app/javascript/lib/csrf_fetch";
import { mountControllers, unmount } from "../support/stimulus";

jest.mock("../../../app/javascript/lib/csrf_fetch", () => jest.fn());
jest.mock("bootstrap", () => {
  const modal = { show: jest.fn() };
  return { Modal: { getOrCreateInstance: jest.fn(() => modal) } };
});

const menuItem = (id, name) => `
  <button type="button" id="reset-${id}"
    data-action="password-reset#confirm"
    data-password-reset-url-param="/users/${id}/password_reset"
    data-password-reset-name-param="${name}">Reset password</button>
`;

const FIXTURE = `
  <div data-controller="password-reset">
    ${menuItem(1, "Ada Lovelace")}
    ${menuItem(2, "Alan Turing")}
    <div data-password-reset-target="modal">
      <h2 data-password-reset-target="title"></h2>
      <div data-password-reset-target="confirmStep">
        <p data-password-reset-target="error" hidden></p>
        <button type="button" id="confirm" data-action="password-reset#reset">Reset password</button>
      </div>
      <div data-password-reset-target="resultStep" hidden>
        <p data-password-reset-target="password"></p>
        <button type="button" id="copy" data-password-reset-target="copyButton"
          data-action="password-reset#copy">Copy</button>
      </div>
    </div>
  </div>
`;

// Lets a click's fetch resolve and the modal repaint
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("password-reset", () => {
  let application;

  const $ = (selector) => document.querySelector(selector);
  const target = (name) => $(`[data-password-reset-target="${name}"]`);

  async function click(selector) {
    $(selector).click();
    await flush();
  }

  function answer(ok, body) {
    csrfFetch.mockResolvedValue({ ok, json: async () => body });
  }

  beforeEach(async () => {
    application = await mountControllers(FIXTURE, {
      "password-reset": PasswordResetController,
    });
  });

  afterEach(() => {
    unmount(application);
    jest.clearAllMocks();
  });

  it("asks to confirm, naming the user, before resetting anything", async () => {
    await click("#reset-1");

    expect(target("title").textContent).toBe("Reset Ada Lovelace's password?");
    expect(Modal.getOrCreateInstance(target("modal")).show).toHaveBeenCalled();
    expect(csrfFetch).not.toHaveBeenCalled();
  });

  it("shows the new password once confirmed", async () => {
    answer(true, { password: "swift-otter-42" });
    await click("#reset-1");
    await click("#confirm");

    expect(csrfFetch).toHaveBeenCalledWith("/users/1/password_reset", {
      method: "POST",
    });
    expect(target("title").textContent).toBe("New password for Ada Lovelace");
    expect(target("password").textContent).toBe("swift-otter-42");
    expect(target("confirmStep").hidden).toBe(true);
    expect(target("resultStep").hidden).toBe(false);
  });

  it("shows a refusal's errors and stays on the confirmation", async () => {
    answer(false, { errors: ["Password is too short"] });
    await click("#reset-1");
    await click("#confirm");

    expect(target("error").textContent).toBe("Password is too short");
    expect(target("error").hidden).toBe(false);
    expect(target("resultStep").hidden).toBe(true);
  });

  it("says the reset failed when the request itself fails", async () => {
    csrfFetch.mockRejectedValue(new TypeError("Failed to fetch"));
    await click("#reset-1");
    await click("#confirm");

    expect(target("error").textContent).toBe("Password reset failed");
    expect(target("error").hidden).toBe(false);
  });

  it("starts the next user back at the confirmation", async () => {
    answer(false, { errors: ["Password is too short"] });
    await click("#reset-1");
    await click("#confirm");
    answer(true, { password: "swift-otter-42" });
    await click("#confirm");
    await click("#reset-2");

    expect(target("title").textContent).toBe("Reset Alan Turing's password?");
    expect(target("confirmStep").hidden).toBe(false);
    expect(target("resultStep").hidden).toBe(true);
    expect(target("error").hidden).toBe(true);
  });

  it("copies the new password", async () => {
    const writeText = jest.fn().mockResolvedValue();
    Object.assign(navigator, { clipboard: { writeText } });
    answer(true, { password: "swift-otter-42" });
    await click("#reset-1");
    await click("#confirm");
    await click("#copy");

    expect(writeText).toHaveBeenCalledWith("swift-otter-42");
    expect($("#copy").textContent).toBe("Copied");
  });
});
