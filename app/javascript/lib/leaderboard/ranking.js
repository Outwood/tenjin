// Ranks, filters and windows leaderboard entries for the live leaderboard component

export const MAX_USERS_TO_DISPLAY = 10;

// A chosen school, or the viewer's own by default; a chosen class only within the viewer's school
export function passesFilters(entry, filters, viewerSchool) {
  let schoolFilterSet = false;

  for (const f of filters) {
    if (
      f.name === "Schools" &&
      f.option !== "All" &&
      entry.school_name !== f.option
    ) {
      return false;
    }
    if (f.name === "Class" && f.option !== "All") {
      if (
        entry.classroom_names == null ||
        !entry.classroom_names.includes(f.option) ||
        entry.school_name !== viewerSchool
      ) {
        return false;
      }
    }
    if (f.name === "Schools") schoolFilterSet = true;
  }

  return schoolFilterSet || entry.school_name === viewerSchool;
}

// The admitted entries by descending score, each carrying its position
export function rank(entries, filters, viewerSchool) {
  return entries
    .filter((entry) => passesFilters(entry, filters, viewerSchool))
    .sort((a, b) => b.score - a.score)
    .map((entry, i) => ({ ...entry, position: i + 1 }));
}

// The ten rows around the viewer: the top when they are in it, the bottom when they are near it
export function windowAround(entries, viewerId, max = MAX_USERS_TO_DISPLAY) {
  const size = entries.length;
  const viewerIndex = entries.findIndex((entry) => entry.id === viewerId);

  if (size < max - 1) return entries;
  if (viewerIndex < max) return entries.slice(0, max);
  if (viewerIndex + max / 2 >= size) return entries.slice(size - max);
  const lower = Math.max(0, viewerIndex - max / 2 + 1);
  return entries.slice(lower, Math.min(size, lower + max));
}

// Weekly and all-time scores summed per student, keyed by id
export function mergeAllTime(weekly, allTime) {
  const merged = {};
  const ids = new Set([...Object.keys(weekly), ...Object.keys(allTime)]);

  for (const id of ids) {
    const weeklyEntry = weekly[id];
    const allTimeEntry = allTime[id];
    merged[id] =
      weeklyEntry && allTimeEntry
        ? {
            ...weeklyEntry,
            score: parseInt(weeklyEntry.score) + parseInt(allTimeEntry.score),
          }
        : { ...(allTimeEntry ?? weeklyEntry) };
  }

  return merged;
}
