// Sorters a datatable column names in its options, for values Tabulator's string sort misorders

// Cells holding a <time datetime="…">, ordered by that datetime rather than by
// the words shown; a cell without one sorts below every date
export const timeDatetime = (a, b) => {
  const parse = (html) => {
    const m = /datetime="([^"]+)"/.exec(html || "");
    const time = m ? Date.parse(m[1]) : NaN;
    return Number.isNaN(time) ? -Infinity : time;
  };
  const [x, y] = [parse(a), parse(b)];
  return x === y ? 0 : x < y ? -1 : 1;
};

// Values that open with a percentage, like "75%" or "75% (3 of 4)", which a
// string sort puts "100%" before "5%"; text with no number, such as "No
// pupils", sorts below every percentage
export const percent = (a, b) => {
  const parse = (s) => {
    const n = parseFloat(s);
    return Number.isNaN(n) ? -1 : n;
  };
  return parse(a) - parse(b);
};
