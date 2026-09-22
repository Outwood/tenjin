// The unfair-flag controller, mounted through Stimulus on the flag link the
// question renders; the server's acceptance arrives through a stubbed fetch

import { Modal } from "bootstrap";
import UnfairFlagController from "../../../app/javascript/controllers/unfair_flag_controller";
import { mountControllers, unmount } from "../support/stimulus";

jest.mock("bootstrap", () => {
  const show = jest.fn();
  return { Modal: { getOrCreateInstance: jest.fn(() => ({ show })) } };
});

const fixture = (style) => `
  <a href="/flagged_questions" id="unfairFlag"
     data-controller="unfair-flag" data-action="click->unfair-flag#flag">
    <i class="${style} fa-flag"></i>
  </a>
  <div id="feedbackModal"></div>
`;

// Lets the click's fetch resolve and the icon repaint
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("unfair-flag", () => {
  let application;

  async function mount(style) {
    application = await mountControllers(fixture(style), {
      "unfair-flag": UnfairFlagController,
    });
  }

  async function clickFlag() {
    global.fetch = jest.fn().mockResolvedValue({ ok: true });
    document.getElementById("unfairFlag").click();
    await flush();
  }

  const icon = () => document.querySelector("i.fa-flag").classList;

  afterEach(() => {
    unmount(application);
    delete global.fetch;
    jest.clearAllMocks();
  });

  it("fills the flag and thanks the student", async () => {
    await mount("far");
    await clickFlag();

    expect(icon().contains("fas")).toBe(true);
    expect(icon().contains("far")).toBe(false);
    expect(Modal.getOrCreateInstance).toHaveBeenCalledWith(
      document.getElementById("feedbackModal"),
    );
    expect(Modal.getOrCreateInstance().show).toHaveBeenCalled();
  });

  it("empties a flag already set without thanking again", async () => {
    await mount("fas");
    await clickFlag();

    expect(icon().contains("far")).toBe(true);
    expect(icon().contains("fas")).toBe(false);
    expect(Modal.getOrCreateInstance).not.toHaveBeenCalled();
  });
});
