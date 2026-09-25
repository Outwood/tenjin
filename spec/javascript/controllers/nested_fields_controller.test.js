// The nested-fields controller, mounted through Stimulus on the answer table
// the question form renders: Add Answer appends the link's row template keyed
// by the time of the click, an unsaved row's Remove takes it out of the form,
// and a saved answer's Remove hides it and marks it for the next save to delete.
// The add wiring keeps its browser smoke in
// spec/system/questions/author_edits_a_question_spec.rb.

import NestedFieldsController from "../../../app/javascript/controllers/nested_fields_controller";
import { mountControllers, unmount } from "../support/stimulus";

// add_row_button keys its template by the unsaved answer's object_id
const PLACEHOLDER = 1032;
const NOW = 1700000000000;

// The _answer partial for an unsaved question's answer at that index
function answerRow(index) {
  return `
    <tr>
      <td>
        <input class="form-control text-answer" type="text"
               name="question[answers_attributes][${index}][text]"
               id="answer-text-${index}">
      </td>
      <td>
        <input name="question[answers_attributes][${index}][correct]" type="hidden" value="0">
        <input class="form-check-input" type="checkbox" value="1"
               name="question[answers_attributes][${index}][correct]"
               id="answer-check-${index}">
      </td>
      <td>
        <button type="button" class="btn btn-danger" data-action="click->nested-fields#removeRow">Remove</button>
      </td>
    </tr>
  `;
}

// Rails quotes the template for the attribute by escaping only the double quotes
const attribute = (html) => html.replace(/"/g, "&quot;");

const FIXTURE = `
  <form data-controller="nested-fields">
    <table id="table-answers">
      <tbody data-nested-fields-target="fields">
        ${answerRow(0)}
        ${answerRow(1)}
      </tbody>
    </table>
    <button type="button" class="btn btn-primary" data-action="click->nested-fields#add"
       data-id="${PLACEHOLDER}" data-fields="${attribute(answerRow(PLACEHOLDER))}">Add Answer</button>
  </form>
`;

// What the table's rows would post, in order
const inputNames = (root) =>
  [...root.querySelectorAll("input")].map((input) => input.name);
const answerNames = (index) => [
  `question[answers_attributes][${index}][text]`,
  `question[answers_attributes][${index}][correct]`,
  `question[answers_attributes][${index}][correct]`,
];

describe("nested-fields", () => {
  let application, tbody;

  beforeEach(async () => {
    application = await mountControllers(FIXTURE, {
      "nested-fields": NestedFieldsController,
    });
    tbody = document.querySelector("tbody");
  });

  afterEach(() => unmount(application));

  describe("add", () => {
    // Pinned after the mount, so the runtime boots on real timers
    beforeEach(() => jest.useFakeTimers({ now: NOW }));
    afterEach(() => jest.useRealTimers());

    it("appends the template row keyed throughout by the time of the click", () => {
      document.querySelector("button.btn-primary").click();

      expect(inputNames(tbody)).toEqual([
        ...answerNames(0),
        ...answerNames(1),
        ...answerNames(NOW),
      ]);
      expect(tbody.querySelector(`#answer-check-${NOW}`)).not.toBeNull();
      expect(tbody.innerHTML).not.toContain(String(PLACEHOLDER));
    });
  });

  describe("removeRow", () => {
    it("takes the clicked row out of the form", () => {
      tbody.querySelector("tr:first-of-type button").click();

      expect(inputNames(tbody)).toEqual(answerNames(1));
    });
  });
});

// A saved answer's row as the editor renders it, with its id field beside it
const SAVED_FIXTURE = `
  <form data-controller="nested-fields">
    <table id="table-answers">
      <tbody data-nested-fields-target="fields">
        <tr>
          <td><input type="text" name="question[answers_attributes][0][text]" value="Glucose"></td>
          <td>
            <button type="button" class="btn btn-danger" data-object-name="question[answers_attributes][0]"
                    data-action="click->nested-fields#removeRecord">Remove</button>
          </td>
        </tr>
        <input type="hidden" name="question[answers_attributes][0][id]" value="7">
      </tbody>
    </table>
  </form>
`;

describe("nested-fields on a saved answer", () => {
  let application, submit;

  beforeEach(async () => {
    application = await mountControllers(SAVED_FIXTURE, {
      "nested-fields": NestedFieldsController,
    });
    submit = jest
      .spyOn(HTMLFormElement.prototype, "submit")
      .mockImplementation(() => {});
  });

  afterEach(() => {
    submit.mockRestore();
    unmount(application);
  });

  describe("removeRecord", () => {
    beforeEach(() => document.querySelector("button.btn-danger").click());

    it("hides the row and marks the answer for deletion", () => {
      const form = document.querySelector("form");

      expect(document.querySelector("tr").hidden).toBe(true);
      expect(
        new FormData(form).get("question[answers_attributes][0][_destroy]"),
      ).toBe("true");
    });

    it("leaves the save to the form", () => {
      expect(submit).not.toHaveBeenCalled();
    });
  });
});
