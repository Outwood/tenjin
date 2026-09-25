// Sorters a datatable column names in its options, for values Tabulator's string sort misorders

// UK datetime strings like "DD/MM/YY HH:MM", which a string sort breaks
// across year boundaries
export const ukDateTime = (a, b) => {
  const parse = (s) => {
    const m = /^(\d{2})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})$/.exec(s || "");
    if (!m) return 0;
    const [, d, mo, y, h, mi] = m;
    return Date.UTC(
      2000 + parseInt(y, 10),
      parseInt(mo, 10) - 1,
      parseInt(d, 10),
      parseInt(h, 10),
      parseInt(mi, 10),
    );
  };
  return parse(a) - parse(b);
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
