// The sync-notice controller, mounted through Stimulus on the markup the
// classrooms page renders: one subject form per row, plus the sync button's
// own form, all inside the section the controller watches

import SyncNoticeController from "../../../app/javascript/controllers/sync_notice_controller";
import { mountControllers, unmount } from "../support/stimulus";

const NEEDED_LABEL = "Sync needed";
const NEEDED_BUTTON = "School sync required. Click here to start.";

const FIXTURE = `
  <section data-controller="sync-notice"
           data-sync-notice-needed-label-value="${NEEDED_LABEL}"
           data-action="turbo:submit-end->sync-notice#settle">
    <b id="syncStatus" data-sync-notice-target="status">Synced</b>
    <form id="sync-form">
      <button id="syncButton" class="btn btn-primary btn-block my-3"
              data-sync-notice-target="button">Sync Classrooms &amp; Users</button>
    </form>
    <form id="first-form">
      <select id="first" data-action="change->sync-notice#notify"></select>
    </form>
    <form id="second-form">
      <select id="second" data-action="change->sync-notice#notify"></select>
    </form>
  </section>
`;

describe("sync-notice", () => {
  let application, status, button;

  beforeEach(async () => {
    application = await mountControllers(FIXTURE, {
      "sync-notice": SyncNoticeController,
    });
    status = document.querySelector("#syncStatus");
    button = document.querySelector("#syncButton");
  });

  afterEach(() => unmount(application));

  function changeSubject(id) {
    document
      .querySelector(`#${id}`)
      .dispatchEvent(new Event("change", { bubbles: true }));
  }

  function submitEnds(id, success) {
    document.querySelector(`#${id}`).dispatchEvent(
      new CustomEvent("turbo:submit-end", {
        bubbles: true,
        detail: { success },
      }),
    );
  }

  // Turbo abandons the submission in flight when a newer one starts, and its
  // submit-end carries no verdict
  function submitAbandoned(id) {
    document
      .querySelector(`#${id}`)
      .dispatchEvent(
        new CustomEvent("turbo:submit-end", { bubbles: true, detail: {} }),
      );
  }

  it("reads as sync needed as soon as a subject changes", () => {
    changeSubject("first");

    expect(status.textContent).toBe(NEEDED_LABEL);
    expect(button.textContent).toBe(NEEDED_BUTTON);
    expect(button.classList.contains("btn-danger")).toBe(true);
  });

  it("keeps the notice once the write lands", () => {
    changeSubject("first");
    submitEnds("first-form", true);

    expect(status.textContent).toBe(NEEDED_LABEL);
    expect(button.classList.contains("btn-danger")).toBe(true);
  });

  it("puts the notice back when the write is refused", () => {
    changeSubject("first");
    submitEnds("first-form", false);

    expect(status.textContent).toBe("Synced");
    expect(button.textContent).toBe("Sync Classrooms & Users");
    expect(button.classList.contains("btn-primary")).toBe(true);
    expect(button.classList.contains("btn-danger")).toBe(false);
  });

  it("holds the notice until every write it flipped for has answered", () => {
    changeSubject("first");
    changeSubject("second");
    submitEnds("first-form", false);

    expect(status.textContent).toBe(NEEDED_LABEL);
  });

  it("keeps the notice a later write earned when an earlier one is refused", () => {
    changeSubject("first");
    changeSubject("second");
    submitEnds("first-form", false);
    submitEnds("second-form", true);

    expect(status.textContent).toBe(NEEDED_LABEL);
    expect(button.classList.contains("btn-danger")).toBe(true);
  });

  it("puts the notice back only once both writes are refused", () => {
    changeSubject("first");
    changeSubject("second");
    submitEnds("first-form", false);
    submitEnds("second-form", false);

    expect(status.textContent).toBe("Synced");
  });

  it("keeps the notice a later write earned when the same form's earlier one is abandoned", () => {
    changeSubject("first");
    changeSubject("first");
    submitAbandoned("first-form");
    submitEnds("first-form", true);

    expect(status.textContent).toBe(NEEDED_LABEL);
    expect(button.classList.contains("btn-danger")).toBe(true);
  });

  it("leaves a refusal from the sync button's own form alone", () => {
    changeSubject("first");
    submitEnds("sync-form", false);

    expect(status.textContent).toBe(NEEDED_LABEL);
  });

  it("restores nothing when a refusal arrives with no change pending", () => {
    submitEnds("first-form", false);

    expect(status.textContent).toBe("Synced");
    expect(button.classList.contains("btn-primary")).toBe(true);
  });
});
