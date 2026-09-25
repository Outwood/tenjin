import { Controller } from "@hotwired/stimulus";
import { TabulatorFull as Tabulator } from "tabulator-tables";
import * as namedSorters from "../lib/table_sorters";
import { searchableText, stripHtml } from "../lib/table_search";

// Field name Tabulator will use to store each row's original source-DOM
// position. Tabulator's HTML importer assigns `item[options.index] = i`
// for rows that don't already carry a value for the configured index
// field, which gives us a per-row source index that survives sort/filter.
const SRC_INDEX_FIELD = "__tabulatorSrcIdx__";

// Named "datatable" (rather than "tabulator") so existing
// `data-controller="datatable"` markup keeps working.
export default class extends Controller {
  static targets = ["table", "search"];
  static values = {
    options: { type: Object, default: {} },
    filename: { type: String, default: "data.csv" },
  };

  connect() {
    // Snapshot source <tr> id/class/data-* before Tabulator regenerates rows.
    this.sourceRowAttrs = Array.from(
      this.tableTarget.querySelectorAll("tbody tr"),
    ).map((tr) => ({
      id: tr.id || null,
      className: tr.className || null,
      dataset: { ...tr.dataset },
    }));

    // searchFields is ours rather than Tabulator's, which warns on options it does not know
    const { searchFields, ...opts } = this.optionsValue;
    this.searchFields = searchFields;
    this.searchText = new WeakMap();
    // Tabulator shows its placeholder whenever no rows show, and asks for it
    // afresh each time, so a search that finds nothing says so rather than
    // repeating the page's message for an empty table
    if (opts.placeholder) {
      const { placeholder } = opts;
      opts.placeholder = () =>
        this.searching ? "Nothing matches your search." : placeholder;
    }
    if (Array.isArray(opts.columns)) {
      opts.columns = opts.columns.map((col) =>
        typeof col.sorter === "string" && namedSorters[col.sorter]
          ? { ...col, sorter: namedSorters[col.sorter] }
          : col,
      );
    }

    this.tabulator = new Tabulator(this.tableTarget, {
      layout: "fitColumns",
      autoColumns: true,
      pagination: true,
      paginationSize: 10,
      // Tabulator's clipboard module is opt-in; without this `copyToClipboard()` is a no-op.
      clipboard: true,
      columnDefaults: {
        formatter: "html",
        accessorClipboard: stripHtml,
        accessorDownload: stripHtml,
      },
      index: SRC_INDEX_FIELD,
      ...opts,
      rowFormatter: (row) => this.reapplyRowAttrs(row),
    });

    // autoColumns may surface a visible column for the synthetic index
    // field. Hide it once the table is built (only present on autoColumns
    // tables; check the columns list first to avoid a noisy "Find Error"
    // warning when explicit `columns` was supplied).
    this.tabulator.on("tableBuilt", () => {
      const hasIdxColumn = this.tabulator
        .getColumns()
        .some((c) => c.getField() === SRC_INDEX_FIELD);
      if (hasIdxColumn) {
        this.tabulator.getColumn(SRC_INDEX_FIELD).hide();
      }
      this.#sortFromKeyboard();
    });

    // Page buttons for a single page offer nothing, and a search can shrink
    // or grow the page count, so the footer is rechecked after every render
    this.tabulator.on("renderComplete", () => this.#toggleFooter());
  }

  // Tabulator sorts on a click on the heading alone, so a sortable heading
  // also takes focus and sorts on Enter or Space by clicking itself
  #sortFromKeyboard() {
    this.tabulator.element
      .querySelectorAll(".tabulator-col.tabulator-sortable")
      .forEach((heading) => {
        heading.tabIndex = 0;
        heading.addEventListener("keydown", (event) => {
          if (event.key !== "Enter" && event.key !== " ") return;
          event.preventDefault();
          heading.click();
        });
      });
  }

  #toggleFooter() {
    if (!this.tabulator.options.pagination) return;
    const footer = this.tabulator.element.querySelector(".tabulator-footer");
    footer?.classList.toggle("d-none", this.tabulator.getPageMax() <= 1);
  }

  disconnect() {
    if (this.tabulator) this.tabulator.destroy();
  }

  filter(event) {
    const needle = event.target.value.toLowerCase();
    this.searching = Boolean(needle);
    if (needle) {
      this.tabulator.setFilter((row) => this.#textOf(row).includes(needle));
    } else {
      this.tabulator.clearFilter();
    }
  }

  // Rows never change after import, so each is parsed once, not per keystroke
  #textOf(row) {
    if (!this.searchText.has(row)) {
      this.searchText.set(row, searchableText(row, this.searchFields));
    }
    return this.searchText.get(row);
  }

  copy() {
    this.tabulator.copyToClipboard("active");
  }

  downloadCsv() {
    this.tabulator.download("csv", this.filenameValue);
  }

  reapplyRowAttrs(row) {
    const idx = row.getData()[SRC_INDEX_FIELD];
    if (idx == null) return;
    const src = this.sourceRowAttrs[idx];
    if (!src) return;
    const el = row.getElement();
    if (src.id) el.id = src.id;
    if (src.className) {
      src.className
        .split(/\s+/)
        .filter(Boolean)
        .forEach((c) => el.classList.add(c));
    }
    Object.entries(src.dataset).forEach(([k, v]) => {
      el.dataset[k] = v;
    });
  }
}
