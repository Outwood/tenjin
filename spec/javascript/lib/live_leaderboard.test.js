// Branches of the liveLeaderboard Alpine component, driven with author-written
// load results and broadcasts. The wiring jest cannot see (fetch → JSON → rows,
// cable → received → DOM, the filter buttons) is proven once in the browser by
// spec/system/leaderboard/user_views_an_updating_leaderboard_spec.rb.

jest.mock("alpinejs", () => ({
  __esModule: true,
  default: { data: jest.fn() },
}));
// The real consumer opens a socket on the first subscription.
jest.mock("../../../app/javascript/channels/consumer", () => ({
  __esModule: true,
  default: { subscriptions: { create: jest.fn() } },
}));

import Alpine from "alpinejs";
import consumer from "../../../app/javascript/channels/consumer";
import "../../../app/javascript/lib/live_leaderboard";

const liveLeaderboard = Alpine.data.mock.calls[0][1];

const SCHOOL = "Hill School";
const OTHER_SCHOOL = "Rival High";
const TOPIC_ID = 7;
const VIEWER = { id: 1, role: "student", school: SCHOOL, classrooms: ["10A"] };

// One row of the JSON's "leaderboard" array
function entry(id, score, overrides = {}) {
  return {
    id,
    name: `Student ${id}`,
    school_name: SCHOOL,
    score,
    icon: null,
    classroom_names: ["10A"],
    awards: 0,
    ...overrides,
  };
}

// The viewer on 10 and nine others on 1..9: exactly one ten-row window
function tenEntries() {
  return [
    entry(VIEWER.id, 10),
    ...[2, 3, 4, 5, 6, 7, 8, 9, 10].map((id) => entry(id, id - 1)),
  ];
}

// Twenty others on 200..10 in steps of ten, plus the viewer on the given score
function crowd(viewerScore) {
  return [
    entry(VIEWER.id, viewerScore),
    ...Array.from({ length: 20 }, (_, i) => entry(i + 2, (i + 1) * 10)),
  ];
}

function loadResult(entries, overrides = {}) {
  return {
    leaderboard: entries,
    awards: {},
    name: "Maths",
    schools: [SCHOOL],
    classrooms: ["10A"],
    user: VIEWER,
    winners: [],
    ...overrides,
  };
}

// The payload Leaderboard::BroadcastLeaderboardPoint sends
function point(id, overrides = {}) {
  return {
    id,
    name: `Student ${id}`,
    school_name: SCHOOL,
    topic: TOPIC_ID,
    topic_score: 11,
    subject_score: 11,
    classroom_names: ["10A"],
    ...overrides,
  };
}

// A component past its first load, with the cable callbacks it registered
function mount({ topicId = null, entries = tenEntries(), load = {} } = {}) {
  const component = liveLeaderboard({
    subjectId: 1,
    topicId,
    canSeeLiveToggle: false,
  });
  component.listenToLeaderboard();
  const handlers = consumer.subscriptions.create.mock.lastCall[1];
  component._applyLoadResult(loadResult(entries, load), { allTime: false });
  return { component, received: handlers.received };
}

function stubFetch(result) {
  global.fetch = jest
    .fn()
    .mockResolvedValue({ ok: true, json: async () => result });
  return global.fetch;
}

// The tbody the page fills through x-html, so assertions keep the browser's selectors
function render(component) {
  const tbody = document.createElement("tbody");
  tbody.innerHTML = component.sortedEntriesHtml();
  return tbody;
}

const rowIds = (tbody) => [...tbody.querySelectorAll("tr")].map((tr) => tr.id);
const positions = (tbody) =>
  [...tbody.querySelectorAll("tr td:first-child")].map((td) => td.textContent);

afterEach(() => {
  delete global.fetch;
});

describe("liveLeaderboard", () => {
  describe("on load", () => {
    it("renders the loaded rows without a flash", () => {
      const tbody = render(mount().component);

      expect(rowIds(tbody)).toHaveLength(10);
      expect(tbody.querySelector("tr.score-changed")).toBeNull();
    });

    it("highlights the viewer's row", () => {
      const tbody = render(mount().component);

      expect(
        tbody.querySelector("tr#row-1.current-user td#name-1").textContent,
      ).toBe("Student 1");
      expect(tbody.querySelector("tr#row-2.current-user")).toBeNull();
    });
  });

  describe("the ten-row window", () => {
    it("shows every row of a board smaller than the window", () => {
      const { component } = mount({
        entries: [entry(1, 10), entry(2, 9), entry(3, 8)],
      });

      expect(rowIds(render(component))).toEqual(["row-1", "row-2", "row-3"]);
    });

    it("shows the top ten when the viewer is in it", () => {
      const { component } = mount({ entries: crowd(500) });
      const tbody = render(component);

      expect(rowIds(tbody)).toHaveLength(10);
      expect(rowIds(tbody)[0]).toBe("row-1");
      expect(positions(tbody)).toEqual([
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "10",
      ]);
    });

    it("shows the ten around a mid-table viewer", () => {
      const { component } = mount({ entries: crowd(85) });
      const tbody = render(component);

      expect(rowIds(tbody)).toHaveLength(10);
      expect(positions(tbody)[0]).toBe("9");
      expect(rowIds(tbody)[4]).toBe("row-1");
      expect(positions(tbody)[4]).toBe("13");
    });

    it("shows the bottom ten when the viewer is last", () => {
      const { component } = mount({ entries: crowd(0) });
      const tbody = render(component);

      expect(rowIds(tbody)).toHaveLength(10);
      expect(positions(tbody)[0]).toBe("12");
      expect(rowIds(tbody)[9]).toBe("row-1");
      expect(positions(tbody)[9]).toBe("21");
      expect(tbody.querySelector("td#score-1").textContent).toBe("0");
    });

    it("shows every row while show all is on", () => {
      const { component } = mount({ entries: crowd(85) });

      component.showAll = true;
      expect(rowIds(render(component))).toHaveLength(21);

      component.showAll = false;
      expect(rowIds(render(component))).toHaveLength(10);
    });
  });

  describe("when a score arrives", () => {
    beforeEach(() => jest.useFakeTimers());
    afterEach(() => jest.useRealTimers());

    it("flashes each updated row with its new score", () => {
      const { component, received } = mount();

      received(point(1, { subject_score: 12 }));
      received(point(2, { subject_score: 11 }));
      const tbody = render(component);

      expect(
        tbody.querySelector("tr#row-1.score-changed td#score-1").textContent,
      ).toBe("12");
      expect(
        tbody.querySelector("tr#row-2.score-changed td#score-2").textContent,
      ).toBe("11");
      expect(tbody.querySelectorAll("tr.score-changed")).toHaveLength(2);
    });

    it("clears the flash after a second", () => {
      const { component, received } = mount();

      received(point(1));
      expect(
        render(component).querySelector("tr#row-1.score-changed"),
      ).not.toBeNull();

      jest.advanceTimersByTime(1000);
      expect(render(component).querySelector("tr.score-changed")).toBeNull();
    });

    it("adds a new entry ranked by score and keeps ten rows", () => {
      const { component, received } = mount();

      received(point(11, { name: "Newcomer N" }));
      const tbody = render(component);

      expect(rowIds(tbody)).toHaveLength(10);
      expect(rowIds(tbody).slice(0, 2)).toEqual(["row-11", "row-1"]);
      expect(
        tbody.querySelector("tr#row-11.score-changed td#name-11").textContent,
      ).toBe("Newcomer N");
    });

    it("hides another school's entry until all schools are selected", () => {
      const { component, received } = mount({
        load: { schools: [SCHOOL, OTHER_SCHOOL] },
      });
      component.allSchoolsLoaded = true;

      received(point(11, { school_name: OTHER_SCHOOL }));
      expect(rowIds(render(component))).not.toContain("row-11");

      component.setFilter("Schools", "All");
      expect(
        render(component).querySelector("tr#row-11.score-changed"),
      ).not.toBeNull();
    });
  });

  describe("filters", () => {
    it("offers a school filter only for a school group", () => {
      const single = mount().component;
      const grouped = mount({
        load: { schools: [SCHOOL, OTHER_SCHOOL] },
      }).component;

      expect(single.schoolFilterOptions()).toEqual([]);
      expect(grouped.schoolFilterOptions()).toEqual([
        "All",
        SCHOOL,
        OTHER_SCHOOL,
      ]);
      expect(single.classroomFilterOptions()).toEqual(["All", "10A"]);
    });

    it("loads the school group once when all schools are first selected", () => {
      const { component } = mount({
        load: { schools: [SCHOOL, OTHER_SCHOOL] },
      });
      const fetch = stubFetch(loadResult(tenEntries()));

      component.setFilter("Schools", "All");
      component.setFilter("Schools", "All");

      expect(fetch).toHaveBeenCalledTimes(1);
      expect(fetch.mock.calls[0][0]).toBe(
        `${window.location.pathname}.json?school_group=true`,
      );
      expect(component.selectedFilterText("Schools", "Select School")).toBe(
        "All",
      );
    });

    it("narrows to the chosen school", () => {
      const rival = entry(11, 50, { school_name: OTHER_SCHOOL });
      const { component } = mount({
        entries: [entry(1, 10), rival],
        load: { schools: [SCHOOL, OTHER_SCHOOL] },
      });
      component.allSchoolsLoaded = true;

      component.setFilter("Schools", "All");
      expect(rowIds(render(component))).toEqual(["row-11", "row-1"]);

      component.setFilter("Schools", SCHOOL);
      expect(rowIds(render(component))).toEqual(["row-1"]);
    });

    it("narrows to the chosen classroom", () => {
      const { component } = mount({
        entries: [entry(1, 10), entry(2, 9, { classroom_names: ["10B"] })],
        load: { classrooms: ["10A", "10B"] },
      });

      component.setFilter("Class", "10B");

      expect(rowIds(render(component))).toEqual(["row-2"]);
    });

    it("clears the school filter when a classroom is chosen", () => {
      const { component } = mount({
        load: { schools: [SCHOOL, OTHER_SCHOOL] },
      });
      component.allSchoolsLoaded = true;

      component.setFilter("Schools", OTHER_SCHOOL);
      expect(component.selectedFilterText("Schools", "Select School")).toBe(
        OTHER_SCHOOL,
      );
      expect(component.contextualHeader()).toBe("School");

      component.setFilter("Class", "10A");
      expect(component.selectedFilterText("Schools", "Select School")).toBe(
        "Select School",
      );
      expect(component.contextualHeader()).toBe("Class");
    });
  });

  describe("all time scores", () => {
    it("requests them once the toggle is on", () => {
      const { component } = mount();
      const fetch = stubFetch(loadResult([]));

      component.allTime = true;
      component.onAllTimeToggle();

      expect(fetch.mock.calls[0][0]).toBe(
        `${window.location.pathname}.json?all_time=true`,
      );
    });

    it("adds them to the weekly score while the toggle is on", async () => {
      const { component } = mount({ entries: [entry(1, 30)] });
      stubFetch(loadResult([entry(1, 500)]));

      component.allTime = true;
      await component.loadLeaderboard({ allTime: true });
      expect(render(component).querySelector("td#score-1").textContent).toBe(
        "530",
      );

      component.allTime = false;
      component.onAllTimeToggle();
      expect(render(component).querySelector("td#score-1").textContent).toBe(
        "30",
      );
    });

    it("lists all time-only and weekly-only students together", async () => {
      const { component } = mount({ entries: [entry(2, 40)] });
      stubFetch(loadResult([entry(1, 500)]));

      component.allTime = true;
      await component.loadLeaderboard({ allTime: true });
      const tbody = render(component);

      expect(tbody.querySelector("td#score-1").textContent).toBe("500");
      expect(tbody.querySelector("td#score-2").textContent).toBe("40");
    });
  });

  describe("live mode", () => {
    it("clears the table until it is switched off", () => {
      const { component } = mount();

      component.live = true;
      component.toggleLive();
      expect(rowIds(render(component))).toEqual([]);

      component.live = false;
      component.toggleLive();
      expect(rowIds(render(component))).toHaveLength(10);
    });

    it("shows the points scored since it was switched on", () => {
      const { component, received } = mount();
      component.live = true;
      component.toggleLive();

      received(point(1, { subject_score: 510 }));

      expect(
        render(component).querySelector("tr#row-1.score-changed td#score-1")
          .textContent,
      ).toBe("500");
    });

    it("shows updates from across the group and filters them by school", () => {
      const { component, received } = mount({
        load: { schools: [SCHOOL, OTHER_SCHOOL] },
      });
      const fetch = stubFetch(loadResult(tenEntries()));
      component.live = true;
      component.toggleLive();
      expect(fetch.mock.calls[0][0]).toBe(
        `${window.location.pathname}.json?school_group=true`,
      );

      received(point(1));
      received(point(11, { school_name: OTHER_SCHOOL }));
      expect(rowIds(render(component))).toEqual(["row-11", "row-1"]);

      component.setFilter("Schools", OTHER_SCHOOL);
      expect(rowIds(render(component))).toEqual(["row-11"]);
    });

    it("filters updates by class", () => {
      const { component, received } = mount({
        load: { classrooms: ["10A", "10B"] },
      });
      component.live = true;
      component.toggleLive();

      component.setFilter("Class", "10B");
      received(point(1));
      received(point(2, { classroom_names: ["10B"] }));

      expect(rowIds(render(component))).toEqual(["row-2"]);
      expect(
        render(component).querySelector("tr#row-2.score-changed"),
      ).not.toBeNull();
    });
  });

  describe("on a topic leaderboard", () => {
    it("applies a point for the topic and ignores other topics", () => {
      const { component, received } = mount({ topicId: TOPIC_ID });

      received(point(2, { topic: TOPIC_ID + 1, subject_score: 99 }));
      received(point(1, { topic: TOPIC_ID }));
      const tbody = render(component);

      expect(tbody.querySelector("tr#row-1.score-changed")).not.toBeNull();
      expect(tbody.querySelector("tr#row-2.score-changed")).toBeNull();
      expect(tbody.querySelector("td#score-2").textContent).toBe("1");
    });

    // Applies the subject total on a topic leaderboard too, see #220
    test.failing("shows the topic score rather than the subject total", () => {
      const { component, received } = mount({ topicId: TOPIC_ID });

      received(
        point(1, { topic: TOPIC_ID, topic_score: 12, subject_score: 30 }),
      );

      expect(render(component).querySelector("td#score-1").textContent).toBe(
        "12",
      );
    });
  });

  describe("icons and awards", () => {
    it("shows the icon in its colour, and none for a student without one", () => {
      const { component } = mount({
        entries: [entry(1, 10, { icon: "blue,star" }), entry(2, 9)],
      });
      const tbody = render(component);

      expect(
        tbody.querySelector("td#icon-1 i.fa-star").getAttribute("style"),
      ).toBe("color: blue;");
      expect(tbody.querySelector("td#icon-2 i")).toBeNull();
    });

    it("stars each win in red, three in silver and five in gold", () => {
      const { component } = mount({
        entries: [
          entry(1, 10),
          entry(2, 9, { awards: 1 }),
          entry(3, 8, { awards: 3 }),
          entry(4, 7, { awards: 6 }),
        ],
      });
      const tbody = render(component);
      const stars = (id) =>
        [...tbody.querySelectorAll(`td#awards-${id} i.fa-star`)].map((i) =>
          i.getAttribute("style"),
        );

      expect(stars(1)).toEqual([]);
      expect(stars(2)).toEqual(["color: red;"]);
      expect(stars(3)).toEqual(["color: silver;"]);
      expect(stars(4)).toEqual(["color: gold;", "color: red;"]);
    });
  });

  describe("weekly winners", () => {
    it("names last week's winner for the chosen classroom", () => {
      const { component } = mount({
        load: {
          classrooms: ["10A", "10B"],
          winners: [
            ["10A", "Student 1", 100],
            ["10B", "Student 2", 90],
          ],
        },
      });

      expect(component.winnerLabel()).toBe("Student 1 - 100 points");

      component.setFilter("Class", "10B");
      expect(component.winnerLabel()).toBe("Student 2 - 90 points");

      component.setFilter("Class", "All");
      expect(component.winnerLabel()).toBe("Student 1 - 100 points");
    });
  });
});
