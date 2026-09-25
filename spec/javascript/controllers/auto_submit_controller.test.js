// The auto-submit controller, mounted through Stimulus on the markup the
// classroom subject select and the topic settings fields render

import AutoSubmitController from "../../../app/javascript/controllers/auto_submit_controller";
import { mountControllers, unmount } from "../support/stimulus";

const FIXTURE = `
  <form id="subject-form"
        data-controller="auto-submit"
        data-action="turbo:submit-end->auto-submit#settle">
    <select name="subject" data-action="change->auto-submit#submit">
      <option value="1" selected>Maths</option>
      <option value="2">Physics</option>
      <option value="3">Chemistry</option>
    </select>
    <input type="checkbox" name="active" checked data-action="change->auto-submit#submit">
  </form>
`;

describe("auto-submit", () => {
  let application, form, select, checkbox, submitted;

  beforeEach(async () => {
    application = await mountControllers(FIXTURE, {
      "auto-submit": AutoSubmitController,
    });
    form = document.querySelector("#subject-form");
    select = document.querySelector("select");
    checkbox = document.querySelector("input[type=checkbox]");
    submitted = jest.spyOn(form, "requestSubmit").mockImplementation(() => {});
  });

  afterEach(() => {
    submitted.mockRestore();
    unmount(application);
  });

  function choose(value) {
    select.value = value;
    select.dispatchEvent(new Event("change", { bubbles: true }));
  }

  function submitEnds(success) {
    form.dispatchEvent(
      new CustomEvent("turbo:submit-end", {
        bubbles: true,
        detail: { success },
      }),
    );
  }

  // Turbo abandons the submission in flight when a newer one starts, and its
  // submit-end carries no verdict
  function submitAbandoned() {
    form.dispatchEvent(
      new CustomEvent("turbo:submit-end", { bubbles: true, detail: {} }),
    );
  }

  it("submits the form as soon as a field changes", () => {
    choose("2");

    expect(submitted).toHaveBeenCalledTimes(1);
  });

  it("keeps the new value once the write lands", () => {
    choose("2");
    submitEnds(true);

    expect(select.value).toBe("2");
  });

  it("puts the field back when the write is refused", () => {
    choose("2");
    submitEnds(false);

    expect(select.value).toBe("1");
  });

  it("puts a checkbox back, which carries its state outside its value", () => {
    checkbox.checked = false;
    checkbox.dispatchEvent(new Event("change", { bubbles: true }));
    submitEnds(false);

    expect(checkbox.checked).toBe(true);
  });

  it("restores the value the server accepted, not the one before the last change", () => {
    choose("2");
    choose("1");
    choose("2");
    submitEnds(false);

    expect(select.value).toBe("1");
  });

  it("restores to a value a later write made the accepted one", () => {
    choose("2");
    submitEnds(true);
    submitEnds(false);

    expect(select.value).toBe("2");
  });

  it("keeps the value a later write landed when the earlier one is abandoned", () => {
    choose("2");
    choose("3");
    submitAbandoned();
    submitEnds(true);

    expect(select.value).toBe("3");
  });

  it("does not take an abandoned write as accepted", () => {
    choose("2");
    choose("3");
    submitAbandoned();
    submitEnds(false);

    expect(select.value).toBe("1");
  });
});

// The topic settings fields carry a status line; the classroom select does not
describe("auto-submit with a status", () => {
  let application, form, input, status;

  beforeEach(async () => {
    application = await mountControllers(
      `
      <form id="name-form"
            data-controller="auto-submit"
            data-action="turbo:submit-end->auto-submit#settle">
        <input name="topic[name]" value="Forces" data-action="change->auto-submit#submit">
        <div role="status" data-auto-submit-target="status"></div>
      </form>
      `,
      { "auto-submit": AutoSubmitController },
    );
    form = document.querySelector("#name-form");
    input = document.querySelector("input");
    status = document.querySelector("[role=status]");
    jest.spyOn(form, "requestSubmit").mockImplementation(() => {});
  });

  afterEach(() => {
    jest.restoreAllMocks();
    unmount(application);
  });

  function rename(value) {
    input.value = value;
    input.dispatchEvent(new Event("change", { bubbles: true }));
  }

  function submitEnds(detail) {
    form.dispatchEvent(
      new CustomEvent("turbo:submit-end", { bubbles: true, detail }),
    );
  }

  it("says the write is in flight", () => {
    rename("Motion");

    expect(status.textContent).toBe("Saving…");
  });

  it("says saved once the write lands", () => {
    rename("Motion");
    submitEnds({ success: true });

    expect(status.textContent).toBe("Saved");
  });

  it("claims nothing when the write is refused", () => {
    rename("Motion");
    submitEnds({ success: true });
    rename("");
    submitEnds({ success: false });

    expect(status.textContent).toBe("");
  });

  it("stays in flight while an abandoned write waits for the newer one", () => {
    rename("Motion");
    rename("Motion and forces");
    submitEnds({});

    expect(status.textContent).toBe("Saving…");
  });
});
