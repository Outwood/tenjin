import Alpine from "alpinejs";

import consumer from "../channels/consumer";
import { mergeAllTime, rank, windowAround } from "./leaderboard/ranking";
import { rowsHtml } from "./leaderboard/rows";

Alpine.data("liveLeaderboard", ({ subjectId, topicId, canSeeLiveToggle }) => ({
  // ── from x-data args ──
  subjectId,
  topicId,
  canSeeLiveToggle,

  // ── populated by load ──
  loading: true,
  name: "",
  user: {},
  schools: [],
  classrooms: [],
  winners: [],

  // ── leaderboard data ──
  weeklyLeaderboard: {},
  allTimeLeaderboard: {},
  initialLeaderboard: {},
  currentLeaderboard: {},

  // ── UI toggles ──
  live: false,
  showAll: false,
  allTime: false,

  // ── filters ──
  currentFilters: [],
  allSchoolsLoaded: false,

  // ── connection state ──
  connected: false,
  subscription: null,

  // ── lifecycle ──
  init() {
    this.listenToLeaderboard();
    this.loadLeaderboard();
  },

  destroy() {
    this.subscription?.unsubscribe();
  },

  // ── data ──
  async loadLeaderboard({ allTime = false, schoolGroup = false } = {}) {
    const params = new URLSearchParams();
    if (schoolGroup) params.set("school_group", "true");
    if (allTime) params.set("all_time", "true");

    const url = `${window.location.pathname}.json?${params.toString()}`;

    try {
      const response = await fetch(url, {
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest",
        },
      });
      if (!response.ok) {
        console.error(`Leaderboard load failed: ${response.status}`);
        return;
      }
      const result = await response.json();
      this._applyLoadResult(result, { allTime });
      this.loading = false;
    } catch (e) {
      console.error(e);
    }
  },

  _applyLoadResult(result, { allTime }) {
    const lb = {};
    for (const entry of result.leaderboard) lb[entry.id] = { ...entry };

    if (allTime) {
      this.allTimeLeaderboard = lb;
    } else {
      this.weeklyLeaderboard = lb;
      this.initialLeaderboard = lb;
    }

    this.name = result.name;
    this.user = result.user;
    this.winners = result.winners;
    this.schools = result.schools;
    this.classrooms = result.classrooms;

    this.processScores();
  },

  processScores() {
    if (this.allTime) {
      this.currentLeaderboard = mergeAllTime(
        this.weeklyLeaderboard,
        this.allTimeLeaderboard,
      );
    } else if (!this.live) {
      this.currentLeaderboard = JSON.parse(
        JSON.stringify(this.weeklyLeaderboard),
      );
    }
  },

  // ── ActionCable ──
  listenToLeaderboard() {
    this.subscription = consumer.subscriptions.create(
      {
        channel: "LeaderboardChannel",
        subject_id: this.subjectId,
      },
      {
        connected: () => {
          this.connected = true;
        },
        disconnected: () => {
          this.connected = false;
        },
        received: (data) => {
          if (this.topicId == null || data.topic === this.topicId) {
            this.leaderboardChange(data);
          }
        },
      },
    );
  },

  leaderboardChange(data) {
    if (Object.keys(this.weeklyLeaderboard).length === 0 && !this.live) {
      setTimeout(() => this.leaderboardChange(data), 1000);
      return;
    }

    const { id } = data;
    let score = data.subject_score;
    if (this.live && this.initialLeaderboard[id]) {
      score = score - this.initialLeaderboard[id].score;
    }

    this.currentLeaderboard[id] = {
      ...this.currentLeaderboard[id],
      ...data,
      score,
      lastChanged: true,
    };

    setTimeout(() => {
      if (this.currentLeaderboard[id]) {
        this.currentLeaderboard[id] = {
          ...this.currentLeaderboard[id],
          lastChanged: false,
        };
      }
    }, 1000);
  },

  // ── filters / toggles ──
  setFilter(name, option) {
    this.currentFilters = this.currentFilters.filter((f) => f.name !== name);
    this.currentFilters.push({ name, option });

    if (name === "Schools") {
      this.currentFilters = this.currentFilters.filter(
        (f) => f.name === "Schools",
      );
      if (!this.allSchoolsLoaded) {
        this.loadLeaderboard({ schoolGroup: true });
        this.allSchoolsLoaded = true;
      }
    }

    if (name === "Class") {
      this.currentFilters = this.currentFilters.filter(
        (f) => f.name === "Class",
      );
    }
  },

  toggleLive() {
    if (this.live) {
      // turning on
      this.showAll = true;
      this.allTime = false;
      this.currentLeaderboard = {};
      if (this.schools.length > 1) {
        this.setFilter("Schools", "All");
      } else {
        this.initialLeaderboard = this.weeklyLeaderboard;
      }
    } else {
      this.processScores();
    }
  },

  onAllTimeToggle() {
    if (this.allTime && Object.keys(this.allTimeLeaderboard).length === 0) {
      this.loadLeaderboard({ allTime: true });
    } else {
      this.processScores();
    }
  },

  // ── derived ──
  sortedEntries() {
    const ranked = rank(
      Object.values(this.currentLeaderboard),
      this.currentFilters,
      this.user.school,
    );
    return this.showAll ? ranked : windowAround(ranked, this.user.id);
  },

  sortedEntriesHtml() {
    return rowsHtml(this.sortedEntries(), {
      viewerId: this.user.id,
      schoolView: this.currentFilters.some((f) => f.name === "Schools"),
    });
  },

  classroomFilterOptions() {
    return ["All", ...this.classrooms];
  },

  schoolFilterOptions() {
    if (this.schools.length <= 1) return [];
    return ["All", ...this.schools];
  },

  selectedFilterText(name, fallback) {
    const filter = this.currentFilters.find((f) => f.name === name);
    return filter ? filter.option : fallback;
  },

  contextualHeader() {
    return this.currentFilters.some((f) => f.name === "Schools")
      ? "School"
      : "Class";
  },

  winnerClassroom() {
    const classFilter = this.currentFilters.find((f) => f.name === "Class");
    if (classFilter) {
      return classFilter.option === "All"
        ? this.user.classrooms?.[0]
        : classFilter.option;
    }
    return this.user.classrooms?.[0];
  },

  winnerLabel() {
    const classroom = this.winnerClassroom();
    return this.winners
      .filter((w) => w[0] === classroom)
      .map((w) => `${w[1]} - ${w[2]} points`)
      .join(", ");
  },
}));
