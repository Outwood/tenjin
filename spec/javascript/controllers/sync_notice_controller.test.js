// The sync-notice controller, mounted through Stimulus on the markup the
// classrooms page renders around its subject selects and sync button

import SyncNoticeController from "../../../app/javascript/controllers/sync_notice_controller";
import { mountControllers, unmount } from "../support/stimulus";

const NEEDED_LABEL = "Sync needed";

const FIXTURE = `
  <section data-controller="sync-notice"
           data-sync-notice-needed-label-value="${NEEDED_LABEL}"
           data-action="turbo:submit-end->sync-notice#settle">
    <b id="syncStatus" data-sync-notice-target="status">Successful</b>
    <form id="sync-form">
      <button id="syncButton" class="btn btn-primary btn-block my-3"
              data-sync-notice-target="button">Sync Classrooms &amp; Users</button>
    </form>
    <form id="subject-form">
      <select data-action="change->sync-notice#notify"></select>
    </form>
  </section>
`;

describe("sync-notice", () => {
  let application, status, button, subjectForm;

  beforeEach(async () => {
    application = await mountControllers(FIXTURE, {
      "sync-notice": SyncNoticeController,
    });
    status = document.querySelector("#syncStatus");
    button = document.querySelector("#syncButton");
    subjectForm = document.querySelector("#subject-form");
  });

  afterEach(() => unmount(application));

  function changeSubject() {
    document
      .querySelector("select")
      .dispatchEvent(new Event("change", { bubbles: true }));
  }

  function submitEnds(success) {
    subjectForm.dispatchEvent(
      new CustomEvent("turbo:submit-end", {
        bubbles: true,
        detail: { success },
      }),
    );
  }

  it("reads as sync needed as soon as the subject changes", () => {
    changeSubject();

    expect(status.textContent).toBe(NEEDED_LABEL);
    expect(button.textContent).toBe(
      "School sync required. Click here to start.",
    );
    expect(button.classList.contains("btn-danger")).toBe(true);
  });

  it("keeps the notice once the write lands", () => {
    changeSubject();
    submitEnds(true);

    expect(status.textContent).toBe(NEEDED_LABEL);
    expect(button.classList.contains("btn-danger")).toBe(true);
  });

  it("puts the status back when the write is refused", () => {
    changeSubject();
    submitEnds(false);

    expect(status.textContent).toBe("Successful");
    expect(button.textContent).toBe("Sync Classrooms & Users");
    expect(button.classList.contains("btn-primary")).toBe(true);
    expect(button.classList.contains("btn-danger")).toBe(false);
  });

  it("restores the state from before the first of several changes", () => {
    changeSubject();
    changeSubject();
    submitEnds(false);

    expect(status.textContent).toBe("Successful");
  });

  it("restores nothing when a submit it never flipped is refused", () => {
    submitEnds(false);

    expect(status.textContent).toBe("Successful");
    expect(button.classList.contains("btn-primary")).toBe(true);
  });
});
