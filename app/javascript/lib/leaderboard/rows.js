// Renders leaderboard entries as the table rows the live leaderboard component paints

export function escapeHtml(value) {
  if (value == null) return "";
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// A gold star per five wins, silver per three, red per one
export function awardStarsHtml(awardsCount) {
  let html = "";
  let remaining = awardsCount || 0;
  while (remaining >= 5) {
    html +=
      '<i class="fas fa-star" style="color: gold;" title="Five wins!"></i>';
    remaining -= 5;
  }
  while (remaining >= 3) {
    html +=
      '<i class="fas fa-star" style="color: silver;" title="Three wins!"></i>';
    remaining -= 3;
  }
  while (remaining >= 1) {
    html +=
      '<i class="fas fa-star" style="color: red;" title="Came top of the leaderboard once!"></i>';
    remaining -= 1;
  }
  return html;
}

export function iconHtml(entry) {
  if (!entry.icon) return "";
  const [color, name] = entry.icon.split(",");
  return `<i class="fas fa-${escapeHtml(name)}" style="color: ${escapeHtml(color)};"></i>`;
}

export function rowClass(entry, viewerId) {
  const classes = [];
  if (entry.lastChanged) classes.push("score-changed");
  if (entry.id === viewerId) classes.push("font-weight-bold", "current-user");
  return classes.join(" ");
}

// The school under a school filter, otherwise the entry's classes
export function contextualCell(entry, schoolView) {
  if (schoolView) return entry.school_name || "";
  return (entry.classroom_names || []).join(", ");
}

export function rowHtml(entry, { viewerId, schoolView }) {
  const classAttr = rowClass(entry, viewerId);
  return `<tr id="row-${entry.id}"${classAttr ? ` class="${classAttr}"` : ""}>
          <td id="pos-${entry.id}">${entry.position}</td>
          <td id="icon-${entry.id}">${iconHtml(entry)}</td>
          <td id="name-${entry.id}">${escapeHtml(entry.name)}</td>
          <td id="awards-${entry.id}">${awardStarsHtml(entry.awards)}</td>
          <td class="d-none d-lg-block" id="${entry.id}-contextual">${escapeHtml(contextualCell(entry, schoolView))}</td>
          <td id="score-${entry.id}">${entry.score}</td>
        </tr>`;
}

export function rowsHtml(entries, options) {
  return entries.map((entry) => rowHtml(entry, options)).join("");
}
