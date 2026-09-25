// The named sorters a datatable column can ask for

import { percent, ukDateTime } from "../../../app/javascript/lib/table_sorters";

describe("ukDateTime", () => {
  const sorted = (values) => [...values].sort(ukDateTime);

  it("orders across a year boundary", () => {
    expect(sorted(["02/01/26 09:00", "31/12/25 09:00"])).toEqual([
      "31/12/25 09:00",
      "02/01/26 09:00",
    ]);
  });

  it("orders across a month boundary", () => {
    expect(sorted(["01/10/26 09:00", "30/09/26 09:00"])).toEqual([
      "30/09/26 09:00",
      "01/10/26 09:00",
    ]);
  });

  it("puts a value it cannot parse below every date", () => {
    expect(sorted(["01/01/00 00:00", "no date"])).toEqual([
      "no date",
      "01/01/00 00:00",
    ]);
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
