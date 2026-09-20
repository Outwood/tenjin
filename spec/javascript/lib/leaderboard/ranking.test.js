// Ranking, filtering and windowing of leaderboard entries, pure and unmocked

import {
  mergeAllTime,
  passesFilters,
  rank,
  windowAround,
} from "../../../../app/javascript/lib/leaderboard/ranking";

const SCHOOL = "Hill School";
const OTHER_SCHOOL = "Rival High";

function entry(id, score, overrides = {}) {
  return {
    id,
    score,
    school_name: SCHOOL,
    classroom_names: ["10A"],
    ...overrides,
  };
}

// Twenty others on 200..10 in steps of ten, ranked with the viewer (id 1) on the given score
function crowd(viewerScore) {
  return rank(
    [
      entry(1, viewerScore),
      ...Array.from({ length: 20 }, (_, i) => entry(i + 2, (i + 1) * 10)),
    ],
    [],
    SCHOOL,
  );
}

const ids = (entries) => entries.map((e) => e.id);
const positions = (entries) => entries.map((e) => e.position);

describe("rank", () => {
  it("orders by descending score and numbers the positions", () => {
    const ranked = rank([entry(1, 5), entry(2, 20), entry(3, 10)], [], SCHOOL);

    expect(ids(ranked)).toEqual([2, 3, 1]);
    expect(positions(ranked)).toEqual([1, 2, 3]);
  });
});

describe("passesFilters", () => {
  const rival = entry(2, 9, { school_name: OTHER_SCHOOL });

  it("admits only the viewer's school with no school filter", () => {
    expect(passesFilters(entry(1, 10), [], SCHOOL)).toBe(true);
    expect(passesFilters(rival, [], SCHOOL)).toBe(false);
  });

  it("admits every school under All", () => {
    expect(
      passesFilters(rival, [{ name: "Schools", option: "All" }], SCHOOL),
    ).toBe(true);
  });

  it("admits only the chosen school", () => {
    const filters = [{ name: "Schools", option: OTHER_SCHOOL }];

    expect(passesFilters(rival, filters, SCHOOL)).toBe(true);
    expect(passesFilters(entry(1, 10), filters, SCHOOL)).toBe(false);
  });

  it("admits only the chosen class within the viewer's school", () => {
    const filters = [{ name: "Class", option: "10B" }];

    expect(
      passesFilters(
        entry(1, 10, { classroom_names: ["10B"] }),
        filters,
        SCHOOL,
      ),
    ).toBe(true);
    expect(passesFilters(entry(1, 10), filters, SCHOOL)).toBe(false);
    expect(
      passesFilters(entry(1, 10, { classroom_names: null }), filters, SCHOOL),
    ).toBe(false);
    expect(
      passesFilters(
        entry(2, 9, { school_name: OTHER_SCHOOL, classroom_names: ["10B"] }),
        filters,
        SCHOOL,
      ),
    ).toBe(false);
  });

  it("admits every class under All", () => {
    expect(
      passesFilters(
        entry(1, 10, { classroom_names: [] }),
        [{ name: "Class", option: "All" }],
        SCHOOL,
      ),
    ).toBe(true);
  });
});

describe("windowAround", () => {
  it("keeps a board smaller than the window whole", () => {
    const small = rank([entry(1, 10), entry(2, 9), entry(3, 8)], [], SCHOOL);

    expect(ids(windowAround(small, 1))).toEqual([1, 2, 3]);
  });

  it("shows the top ten when the viewer is in it", () => {
    const window = windowAround(crowd(500), 1);

    expect(ids(window)[0]).toBe(1);
    expect(positions(window)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  });

  it("shows the ten around a mid-table viewer", () => {
    const window = windowAround(crowd(85), 1);

    expect(positions(window)).toEqual([9, 10, 11, 12, 13, 14, 15, 16, 17, 18]);
    expect(ids(window)[4]).toBe(1);
  });

  it("shows the bottom ten when the viewer is last", () => {
    const window = windowAround(crowd(0), 1);

    expect(positions(window)).toEqual([12, 13, 14, 15, 16, 17, 18, 19, 20, 21]);
    expect(ids(window)[9]).toBe(1);
  });

  it("shows the top ten when the viewer is not on the board", () => {
    const others = crowd(500).filter((e) => e.id !== 1);

    expect(positions(windowAround(others, 1))).toEqual([
      2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
    ]);
  });
});

describe("mergeAllTime", () => {
  it("sums a student's weekly and all-time scores", () => {
    const merged = mergeAllTime({ 1: entry(1, 30) }, { 1: entry(1, 500) });

    expect(merged[1].score).toBe(530);
  });

  it("keeps a student with only one kind of score", () => {
    const merged = mergeAllTime({ 2: entry(2, 40) }, { 1: entry(1, 500) });

    expect(merged[1].score).toBe(500);
    expect(merged[2].score).toBe(40);
  });
});
