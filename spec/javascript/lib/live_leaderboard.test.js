// The liveLeaderboard component's wiring and state: what it loads, what it does
// with a broadcast, and how its toggles and filters reach the rendered rows.
// Ranking, filtering, windowing and row markup are pure modules with their own
// tests under leaderboard/. The fetch → JSON → rows and cable → received → DOM
// wiring is proven once in the browser by
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

const jsonResponse = (result) => ({ ok: true, json: async () => result });

// Each load takes the next result in turn; further loads repeat the last
function stubFetch(...results) {
  const fetch = jest.fn();
  results.forEach((result) =>
    fetch.mockResolvedValueOnce(jsonResponse(result)),
  );
  fetch.mockResolvedValue(jsonResponse(results.at(-1)));
  global.fetch = fetch;
  return fetch;
}

// Lets a load the component started, and did not await, apply its result
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

// A component subscribed and past its first load, as init() leaves it, with the
// cable callbacks it registered and the results its later loads will receive
async function mount({
  topicId = null,
  entries = tenEntries(),
  load = {},
  then = [],
} = {}) {
  const fetch = stubFetch(loadResult(entries, load), ...then);
  const component = liveLeaderboard({
    subjectId: 1,
    topicId,
    canSeeLiveToggle: false,
  });
  component.listenToLeaderboard();
  await component.loadLeaderboard();
  const { received } = consumer.subscriptions.create.mock.lastCall[1];
  return { component, received, fetch };
}

// The tbody the page fills through x-html, so assertions keep the browser's selectors
function render(component) {
  const tbody = document.createElement("tbody");
  tbody.innerHTML = component.sortedEntriesHtml();
  return tbody;
}

const rowIds = (tbody) => [...tbody.querySelectorAll("tr")].map((tr) => tr.id);

afterEach(() => {
  delete global.fetch;
  jest.clearAllMocks();
});

describe("liveLeaderboard", () => {
  describe("on load", () => {
    it("requests the page's scores as XHR, narrowed to the topic when one is shown", async () => {
      const subject = await mount();
      const topic = await mount({ topicId: TOPIC_ID });

      expect(subject.fetch.mock.calls[0][0]).toBe("/.json?");
      expect(subject.fetch.mock.calls[0][1].headers["X-Requested-With"]).toBe(
        "XMLHttpRequest",
      );
      expect(topic.fetch.mock.calls[0][0]).toBe(`/.json?topic=${TOPIC_ID}`);
    });

    it("renders the loaded rows without a flash and stops loading", async () => {
      const { component } = await mount();
      const tbody = render(component);

      expect(component.loading).toBe(false);
      expect(component.name).toBe("Maths");
      expect(rowIds(tbody)).toHaveLength(10);
      expect(tbody.querySelector("tr.score-changed")).toBeNull();
    });

    it("shows every row only while show all is on", async () => {
      const others = Array.from({ length: 11 }, (_, i) => entry(i + 2, i + 1));
      const { component } = await mount({
        entries: [entry(VIEWER.id, 20), ...others],
      });

      expect(rowIds(render(component))).toHaveLength(10);

      component.showAll = true;
      expect(rowIds(render(component))).toHaveLength(12);
    });
  });

  describe("when a score arrives", () => {
    beforeEach(() => jest.useFakeTimers());
    afterEach(() => jest.useRealTimers());

    it("flashes each updated row with its new score", async () => {
      const { component, received } = await mount();

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

    it("clears the flash after a second", async () => {
      const { component, received } = await mount();

      received(point(1));
      expect(
        render(component).querySelector("tr#row-1.score-changed"),
      ).not.toBeNull();

      jest.advanceTimersByTime(1000);
      expect(render(component).querySelector("tr.score-changed")).toBeNull();
    });

    it("adds a row for a student not yet on the board, from the broadcast", async () => {
      const { component, received } = await mount();

      received(point(11, { name: "Newcomer N" }));

      expect(
        render(component).querySelector("tr#row-11.score-changed td#name-11")
          .textContent,
      ).toBe("Newcomer N");
    });
  });

  describe("filters", () => {
    it("offers a school filter only for a school group", async () => {
      const single = (await mount()).component;
      const grouped = (
        await mount({ load: { schools: [SCHOOL, OTHER_SCHOOL] } })
      ).component;

      expect(single.schoolFilterOptions()).toEqual([]);
      expect(grouped.schoolFilterOptions()).toEqual([
        "All",
        SCHOOL,
        OTHER_SCHOOL,
      ]);
      expect(single.classroomFilterOptions()).toEqual(["All", "10A"]);
    });

    it("loads the school group once when all schools are first selected", async () => {
      const { component, fetch } = await mount({
        load: { schools: [SCHOOL, OTHER_SCHOOL] },
      });

      component.setFilter("Schools", "All");
      await flush();
      component.setFilter("Schools", "All");
      await flush();

      expect(fetch).toHaveBeenCalledTimes(2);
      expect(fetch.mock.calls[1][0]).toBe("/.json?school_group=true");
      expect(component.selectedFilterText("Schools", "Select School")).toBe(
        "All",
      );
    });

    it("shows another school's update once all schools are selected", async () => {
      const group = { schools: [SCHOOL, OTHER_SCHOOL] };
      const { component, received } = await mount({
        load: group,
        then: [loadResult(tenEntries(), group)],
      });

      received(point(11, { school_name: OTHER_SCHOOL }));
      expect(rowIds(render(component))).not.toContain("row-11");

      component.setFilter("Schools", "All");
      await flush();
      received(point(11, { school_name: OTHER_SCHOOL }));
      expect(
        render(component).querySelector("tr#row-11.score-changed"),
      ).not.toBeNull();
    });

    it("narrows the rows to the chosen classroom", async () => {
      const { component } = await mount({
        entries: [entry(1, 10), entry(2, 9, { classroom_names: ["10B"] })],
        load: { classrooms: ["10A", "10B"] },
      });

      component.setFilter("Class", "10B");

      expect(rowIds(render(component))).toEqual(["row-2"]);
    });

    it("shows the school column under a school filter, until a classroom is chosen", async () => {
      const group = { schools: [SCHOOL, OTHER_SCHOOL] };
      const { component } = await mount({
        load: group,
        then: [loadResult(tenEntries(), group)],
      });
      const contextual = () =>
        render(component).querySelector("td[id='1-contextual']").textContent;

      component.setFilter("Schools", "All");
      await flush();
      expect(component.selectedFilterText("Schools", "Select School")).toBe(
        "All",
      );
      expect(component.contextualHeader()).toBe("School");
      expect(contextual()).toBe(SCHOOL);

      component.setFilter("Class", "10A");
      expect(component.selectedFilterText("Schools", "Select School")).toBe(
        "Select School",
      );
      expect(component.contextualHeader()).toBe("Class");
      expect(contextual()).toBe("10A");
    });
  });

  describe("all time scores", () => {
    it("requests them once, when the toggle is first switched on", async () => {
      const { component, fetch } = await mount({
        then: [loadResult([entry(1, 500)])],
      });

      component.allTime = true;
      component.onAllTimeToggle();
      await flush();
      component.onAllTimeToggle();
      await flush();

      expect(fetch).toHaveBeenCalledTimes(2);
      expect(fetch.mock.calls[1][0]).toBe("/.json?all_time=true");
    });

    it("adds them to the weekly score while the toggle is on", async () => {
      const { component } = await mount({
        entries: [entry(1, 30)],
        then: [loadResult([entry(1, 500)])],
      });

      component.allTime = true;
      component.onAllTimeToggle();
      await flush();
      expect(render(component).querySelector("td#score-1").textContent).toBe(
        "530",
      );

      component.allTime = false;
      component.onAllTimeToggle();
      expect(render(component).querySelector("td#score-1").textContent).toBe(
        "30",
      );
    });
  });

  describe("live mode", () => {
    it("clears the table until it is switched off", async () => {
      const { component } = await mount();

      component.live = true;
      component.toggleLive();
      expect(rowIds(render(component))).toEqual([]);

      component.live = false;
      component.toggleLive();
      expect(rowIds(render(component))).toHaveLength(10);
    });

    it("shows the points scored since it was switched on", async () => {
      const { component, received } = await mount();
      component.live = true;
      component.toggleLive();

      received(point(1, { subject_score: 510 }));

      expect(
        render(component).querySelector("tr#row-1.score-changed td#score-1")
          .textContent,
      ).toBe("500");
    });

    it("selects every school in the group when switched on", async () => {
      const group = { schools: [SCHOOL, OTHER_SCHOOL] };
      const { component, received, fetch } = await mount({
        load: group,
        then: [loadResult(tenEntries(), group)],
      });

      component.live = true;
      component.toggleLive();
      await flush();
      received(point(1));
      received(point(11, { school_name: OTHER_SCHOOL }));

      expect(fetch.mock.calls[1][0]).toBe("/.json?school_group=true");
      expect(rowIds(render(component))).toEqual(["row-11", "row-1"]);
    });
  });

  describe("on a topic leaderboard", () => {
    it("applies a point for the topic and ignores other topics", async () => {
      const { component, received } = await mount({ topicId: TOPIC_ID });

      received(point(2, { topic: TOPIC_ID + 1, subject_score: 99 }));
      received(point(1, { topic: TOPIC_ID }));
      const tbody = render(component);

      expect(tbody.querySelector("tr#row-1.score-changed")).not.toBeNull();
      expect(tbody.querySelector("tr#row-2.score-changed")).toBeNull();
      expect(tbody.querySelector("td#score-2").textContent).toBe("1");
    });

    // Applies the subject total on a topic leaderboard too, see #220
    test.failing(
      "shows the topic score rather than the subject total",
      async () => {
        const { component, received } = await mount({ topicId: TOPIC_ID });

        received(
          point(1, { topic: TOPIC_ID, topic_score: 12, subject_score: 30 }),
        );

        expect(render(component).querySelector("td#score-1").textContent).toBe(
          "12",
        );
      },
    );
  });

  describe("weekly winners", () => {
    it("names last week's winner for the chosen classroom", async () => {
      const { component } = await mount({
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
