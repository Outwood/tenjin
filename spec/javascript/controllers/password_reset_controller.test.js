import PasswordResetController from "../../../app/javascript/controllers/password_reset_controller";
import csrfFetch from "../../../app/javascript/lib/csrf_fetch";

jest.mock("../../../app/javascript/lib/csrf_fetch", () => jest.fn());

// Minimal Stimulus context — the controller reads only scope.element.
function makeController(element) {
  return new PasswordResetController({ scope: { element } });
}

describe("PasswordResetController#reset", () => {
  let cell, link, controller;

  beforeEach(() => {
    cell = document.createElement("td");
    link = document.createElement("a");
    link.href = "/users/1/reset_password";
    cell.appendChild(link);
    document.body.appendChild(cell);

    controller = makeController(link);
  });

  afterEach(() => {
    document.body.removeChild(cell);
    jest.resetAllMocks();
  });

  it("replaces the cell with the new password", async () => {
    csrfFetch.mockResolvedValue({
      ok: true,
      json: async () => ({ password: "swift-otter-42" }),
    });

    await controller.reset(new Event("click"));

    expect(cell.querySelector(".new-password").textContent).toBe(
      "swift-otter-42",
    );
  });

  it("shows what the record refused when the reset fails", async () => {
    csrfFetch.mockResolvedValue({
      ok: false,
      json: async () => ({ errors: ["Upi can't be blank"] }),
    });

    await controller.reset(new Event("click"));

    expect(cell.querySelector(".reset-password-error").textContent).toBe(
      "Upi can't be blank",
    );
    expect(cell.querySelector(".new-password")).toBeNull();
  });

  it("falls back to a generic message when the body carries no errors", async () => {
    csrfFetch.mockResolvedValue({
      ok: false,
      json: async () => {
        throw new Error("no body");
      },
    });

    await controller.reset(new Event("click"));

    expect(cell.querySelector(".reset-password-error").textContent).toBe(
      "Password reset failed",
    );
  });
});
