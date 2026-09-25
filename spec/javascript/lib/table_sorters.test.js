// The named sorters a datatable column can ask for

import {
  percent,
  timeDatetime,
} from "../../../app/javascript/lib/table_sorters";

describe("timeDatetime", () => {
  const sorted = (values) => [...values].sort(timeDatetime);
  const time = (datetime, text) =>
    `<time datetime="${datetime}">${text}</time>`;

  it("orders by the datetime rather than the words shown", () => {
    const october = time("2026-10-05T09:00", "5 Oct 2026, 09:00");
    const december = time("2026-12-01T09:00", "1 Dec 2026, 09:00");
    const january = time("2027-01-02T09:00", "2 Jan 2027, 09:00");

    expect(sorted([january, october, december])).toEqual([
      october,
      december,
      january,
    ]);
  });

  it("orders two times on one day", () => {
    const morning = time("2026-10-05T09:00", "5 Oct 2026, 09:00");
    const afternoon = time("2026-10-05T15:30", "5 Oct 2026, 15:30");

    expect(sorted([afternoon, morning])).toEqual([morning, afternoon]);
  });

  it("puts a value with no datetime below every date", () => {
    const dated = time("2000-01-01T00:00", "1 Jan 2000, 00:00");

    expect(sorted([dated, "no date"])).toEqual(["no date", dated]);
  });
});

describe("percent", () => {
  const sorted = (values) => [...values].sort(percent);

  it("orders percentages by value rather than by character", () => {
    expect(sorted(["5%", "100%", "75%"])).toEqual(["5%", "75%", "100%"]);
  });

  it("orders by the percentage a value opens with", () => {
    expect(sorted(["5% (1 of 20)", "100% (1 of 1)", "40% (2 of 5)"])).toEqual([
      "5% (1 of 20)",
      "40% (2 of 5)",
      "100% (1 of 1)",
    ]);
  });

  it("puts a value with no percentage below every percentage", () => {
    expect(sorted(["0%", "Not asked yet", "50%"])).toEqual([
      "Not asked yet",
      "0%",
      "50%",
    ]);
  });
});
