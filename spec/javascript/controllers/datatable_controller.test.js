// The datatable controller's pagination footer, which it hides while the table
// fits on one page, and its CSV download. Tabulator lays its table out with the browser's geometry,
// which jsdom lacks, so a stand-in records the options and events it is given.

jest.mock("tabulator-tables", () => {
  const instances = [];
  class TabulatorFull {
    constructor(table, options) {
      this.options = options;
      this.handlers = {};
      this.pageMax = 1;
      this.element = document.createElement("div");
      this.element.innerHTML = '<div class="tabulator-footer"></div>';
      table.replaceWith(this.element);
      this.download = jest.fn();
      instances.push(this);
    }

    on(event, handler) {
      this.handlers[event] = handler;
    }

    getPageMax() {
      return this.pageMax;
    }

    // Stands in for a render that leaves the table on the given number of pages
    render(pages) {
      this.pageMax = pages;
      this.handlers.renderComplete?.();
    }

    destroy() {}
  }
  return { __esModule: true, TabulatorFull, instances };
});

import { instances } from "tabulator-tables";
import DatatableController from "../../../app/javascript/controllers/datatable_controller";
import { mountControllers, unmount } from "../support/stimulus";

function fixture(options, attributes = "") {
  return `
    <div data-controller="datatable" data-datatable-options-value='${JSON.stringify(options)}' ${attributes}>
      <button type="button" data-action="datatable#downloadCsv">CSV</button>
      <table data-datatable-target="table">
        <thead><tr><th>Name</th></tr></thead>
        <tbody><tr><td>Ada</td></tr></tbody>
      </table>
    </div>
  `;
}

describe("datatable pagination footer", () => {
  let application, table;

  async function mount(options = {}) {
    application = await mountControllers(fixture(options), {
      datatable: DatatableController,
    });
    table = instances.at(-1);
  }

  const footer = () => table.element.querySelector(".tabulator-footer");

  afterEach(() => {
    unmount(application);
    instances.length = 0;
  });

  it("hides the footer while the rows fit on one page", async () => {
    await mount();
    table.render(1);

    expect(footer().classList).toContain("d-none");
  });

  it("shows the footer when the rows run to a second page", async () => {
    await mount();
    table.render(2);

    expect(footer().classList).not.toContain("d-none");
  });

  it("shows the footer again when a render grows the table past one page", async () => {
    await mount();
    table.render(1);
    table.render(3);

    expect(footer().classList).not.toContain("d-none");
  });

  // An unpaginated table's footer holds no page buttons, so it is left alone
  it("leaves the footer of an unpaginated table as it is", async () => {
    await mount({ pagination: false });
    table.render(1);

    expect(footer().classList).not.toContain("d-none");
  });
});

describe("datatable CSV download", () => {
  let application, table;

  async function mount(attributes) {
    application = await mountControllers(fixture({}, attributes), {
      datatable: DatatableController,
    });
    table = instances.at(-1);
  }

  afterEach(() => {
    unmount(application);
    instances.length = 0;
  });

  it("names the file as the page asks", async () => {
    await mount('data-datatable-filename-value="9X-Sc pupils.csv"');
    document.querySelector("button").click();

    expect(table.download).toHaveBeenCalledWith("csv", "9X-Sc pupils.csv");
  });

  it("falls back to data.csv when the page names no file", async () => {
    await mount();
    document.querySelector("button").click();

    expect(table.download).toHaveBeenCalledWith("csv", "data.csv");
  });
});
