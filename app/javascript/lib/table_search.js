// Reads a datatable row as the text its cells show, for the search box and exports

// Tabulator stores each cell's innerHTML as its value. An inert DOMParser
// document reads the text without loading images or running handlers.
export const stripHtml = (value) => {
  if (typeof value !== "string") return value;
  const doc = new DOMParser().parseFromString(value, "text/html");
  return (doc.body.textContent || "").trim();
};

// The lowercased text of the named fields, or of every field when none are
// named; a newline between fields keeps a search from matching across two
export function searchableText(row, fields) {
  const values = fields
    ? fields.map((field) => row[field])
    : Object.values(row);
  return values
    .filter((value) => typeof value === "string")
    .map((value) => stripHtml(value).toLowerCase())
    .join("\n");
}
