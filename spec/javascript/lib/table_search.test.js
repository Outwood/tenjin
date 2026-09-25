// How the datatable search box reads a row

import {
  searchableText,
  stripHtml,
} from "../../../app/javascript/lib/table_search";

const row = {
  question:
    '<a href="/questions/7/edit"><div class="trix-content">What is a CPU?</div></a>',
  times_asked: "0",
  percent_correct: "Not asked yet",
  __tabulatorSrcIdx__: 3,
};

describe("searchableText", () => {
  it("reads a cell's text rather than its markup", () => {
    const text = searchableText(row, ["question"]);

    expect(text).toContain("what is a cpu?");
    expect(text).not.toContain("href");
    expect(text).not.toContain("edit");
  });

  it("reads only the named fields", () => {
    expect(searchableText(row, ["question"])).not.toContain("not asked yet");
  });

  it("reads every text field when none are named", () => {
    expect(searchableText(row)).toBe("what is a cpu?\n0\nnot asked yet");
  });

  it("skips a named field the row lacks", () => {
    expect(searchableText(row, ["question", "lesson"])).toBe("what is a cpu?");
  });
});

describe("stripHtml", () => {
  it("passes a value that is not a string through", () => {
    expect(stripHtml(3)).toBe(3);
  });
});
