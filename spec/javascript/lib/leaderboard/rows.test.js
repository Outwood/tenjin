// The table rows the live leaderboard paints, rendered from author-written entries

import {
  awardStarsHtml,
  contextualCell,
  escapeHtml,
  iconHtml,
  rowClass,
  rowHtml,
  rowsHtml,
} from "../../../../app/javascript/lib/leaderboard/rows";

function entry(id, overrides = {}) {
  return {
    id,
    name: `Student ${id}`,
    school_name: "Hill School",
    score: 10,
    position: 1,
    icon: null,
    classroom_names: ["10A"],
    awards: 0,
    ...overrides,
  };
}

function render(html) {
  const tbody = document.createElement("tbody");
  tbody.innerHTML = html;
  return tbody;
}

const starColours = (html) =>
  [...render(`<tr><td>${html}</td></tr>`).querySelectorAll("i.fa-star")].map(
    (i) => i.getAttribute("style"),
  );

describe("iconHtml", () => {
  it("draws the icon in its colour", () => {
    expect(iconHtml(entry(1, { icon: "blue,star" }))).toBe(
      '<i class="fas fa-star" style="color: blue;"></i>',
    );
  });

  it("draws nothing for a student without one", () => {
    expect(iconHtml(entry(1))).toBe("");
  });
});

describe("awardStarsHtml", () => {
  it("stars each win in red, three in silver and five in gold", () => {
    expect(starColours(awardStarsHtml(0))).toEqual([]);
    expect(starColours(awardStarsHtml(1))).toEqual(["color: red;"]);
    expect(starColours(awardStarsHtml(3))).toEqual(["color: silver;"]);
    expect(starColours(awardStarsHtml(6))).toEqual([
      "color: gold;",
      "color: red;",
    ]);
  });
});

describe("rowClass", () => {
  it("marks the viewer's row and a row whose score just changed", () => {
    expect(rowClass(entry(1), 1)).toBe("font-weight-bold current-user");
    expect(rowClass(entry(2, { lastChanged: true }), 1)).toBe("score-changed");
    expect(rowClass(entry(2), 1)).toBe("");
  });
});

describe("contextualCell", () => {
  it("lists the classes, or the school under a school filter", () => {
    const e = entry(1, { classroom_names: ["10A", "10B"] });

    expect(contextualCell(e, false)).toBe("10A, 10B");
    expect(contextualCell(e, true)).toBe("Hill School");
    expect(contextualCell(entry(1, { classroom_names: null }), false)).toBe("");
  });
});

describe("rowHtml", () => {
  it("gives every cell an id keyed by the entry", () => {
    const tbody = render(
      rowHtml(entry(7, { score: 42, position: 3 }), {
        viewerId: 1,
        schoolView: false,
      }),
    );

    expect(tbody.querySelector("tr#row-7 td#pos-7").textContent).toBe("3");
    expect(tbody.querySelector("td#name-7").textContent).toBe("Student 7");
    expect(tbody.querySelector("td#score-7").textContent).toBe("42");
    expect(tbody.querySelector("td#icon-7")).not.toBeNull();
    expect(tbody.querySelector("td#awards-7")).not.toBeNull();
    expect(tbody.querySelector("td[id='7-contextual']").textContent).toBe(
      "10A",
    );
  });

  it("escapes the name", () => {
    const tbody = render(
      rowHtml(entry(1, { name: "<b>x</b>" }), {
        viewerId: 1,
        schoolView: false,
      }),
    );

    expect(tbody.querySelector("td#name-1 b")).toBeNull();
    expect(tbody.querySelector("td#name-1").textContent).toBe("<b>x</b>");
  });
});

describe("rowsHtml", () => {
  it("joins one row per entry in order", () => {
    const tbody = render(
      rowsHtml([entry(2), entry(1)], { viewerId: 1, schoolView: false }),
    );

    expect([...tbody.querySelectorAll("tr")].map((tr) => tr.id)).toEqual([
      "row-2",
      "row-1",
    ]);
  });
});

describe("escapeHtml", () => {
  it("escapes markup characters and renders nothing for null", () => {
    expect(escapeHtml(`<a href="x">&'</a>`)).toBe(
      "&lt;a href=&quot;x&quot;&gt;&amp;&#39;&lt;/a&gt;",
    );
    expect(escapeHtml(null)).toBe("");
  });
});
