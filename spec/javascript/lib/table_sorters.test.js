// The named sorters a datatable column can ask for

import { percent } from "../../../app/javascript/lib/table_sorters";

describe("percent", () => {
  const sorted = (values) => [...values].sort(percent);

  it("orders percentages by value rather than by character", () => {
    expect(sorted(["5%", "100%", "75%"])).toEqual(["5%", "75%", "100%"]);
  });

  it("puts a value with no percentage below every percentage", () => {
    expect(sorted(["0%", "Not asked yet", "50%"])).toEqual([
      "Not asked yet",
      "0%",
      "50%",
    ]);
  });
});
