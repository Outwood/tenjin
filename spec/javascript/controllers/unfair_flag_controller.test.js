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
  <a href="/questions/5/flag" id="unfairFlag"
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

  it("flags the question, fills the flag and thanks the student", async () => {
    await mount("far");
    await clickFlag();

    expect(global.fetch.mock.calls[0][1].method).toBe("POST");
    expect(icon().contains("fas")).toBe(true);
    expect(icon().contains("far")).toBe(false);
    expect(Modal.getOrCreateInstance).toHaveBeenCalledWith(
      document.getElementById("feedbackModal"),
    );
    expect(Modal.getOrCreateInstance().show).toHaveBeenCalled();
  });

  it("unflags a flagged question without thanking again", async () => {
    await mount("fas");
    await clickFlag();

    expect(global.fetch.mock.calls[0][1].method).toBe("DELETE");
    expect(icon().contains("far")).toBe(true);
    expect(icon().contains("fas")).toBe(false);
    expect(Modal.getOrCreateInstance).not.toHaveBeenCalled();
  });
  it("ignores a second click until the first request answers", async () => {
    await mount("far");
    let answer;
    global.fetch = jest.fn(() => new Promise((resolve) => (answer = resolve)));
    const link = document.getElementById("unfairFlag");

    link.click();
    link.click();
    expect(global.fetch).toHaveBeenCalledTimes(1);

    answer({ ok: true });
    await flush();
    global.fetch = jest.fn().mockResolvedValue({ ok: true });
    link.click();
    await flush();
    expect(global.fetch.mock.calls[0][1].method).toBe("DELETE");
  });
});
