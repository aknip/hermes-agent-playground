export type RawCsv = {
  headers: string[];
  rows: string[][];
};

export class CsvValidationError extends Error {
  readonly problems: string[];

  constructor(problems: string[]) {
    super(problems.join(" "));
    this.name = "CsvValidationError";
    this.problems = problems;
  }
}

// The canonical columns recognised by this importer (spec §3.1). Any other
// column is rejected because silently dropping a column would lose data.
export const CANONICAL_COLUMNS = [
  "title",
  "description",
  "column",
  "priority",
  "due_date",
  "assignee_email",
  "labels",
  "comment",
];

export function parseCsv(text: string): RawCsv {
  const records = parseRecords(text).filter(
    (record) => !record.every((field) => field.length === 0),
  );

  if (records.length === 0) return { headers: [], rows: [] };

  const [headers, ...rows] = records;
  return { headers: headers ?? [], rows: rows ?? [] };
}

export function validateCsv(raw: RawCsv): void {
  const problems: string[] = [];

  if (raw.rows.length === 0) {
    problems.push("The CSV file has no data rows (header only or empty).");
  }

  const headers = raw.headers.map((header) => header.trim());

  if (headers.length === 0 || headers.every((header) => header === "")) {
    problems.push("The CSV is missing a header line.");
  } else {
    const unknown = headers.filter(
      (header) => !CANONICAL_COLUMNS.includes(header),
    );
    if (unknown.length > 0) {
      problems.push(
        `Unknown CSV column(s): ${unknown.join(", ")} (allowed: ${CANONICAL_COLUMNS.join(", ")}).`,
      );
    }

    if (!headers.includes("title")) {
      problems.push(`The CSV is missing the required "title" column.`);
    } else {
      const titleIndex = headers.indexOf("title");
      for (let row = 0; row < raw.rows.length; row++) {
        const value = raw.rows[row]?.[titleIndex]?.trim() ?? "";
        if (!value) problems.push(`Row ${row + 2} has no title.`);
      }
    }
  }

  if (problems.length > 0) throw new CsvValidationError(problems);
}

function parseRecords(text: string): string[][] {
  const records: string[][] = [];
  let record: string[] = [];
  let field = "";
  let inQuotes = false;
  let index = 0;
  const length = text.length;

  while (index < length) {
    const char = text[index] as string;

    if (inQuotes) {
      if (char === '"') {
        if (text[index + 1] === '"') {
          field += '"';
          index += 2;
        } else {
          inQuotes = false;
          index += 1;
        }
      } else {
        field += char;
        index += 1;
      }
    } else if (char === '"') {
      inQuotes = true;
      index += 1;
    } else if (char === ",") {
      record.push(field);
      field = "";
      index += 1;
    } else if (char === "\n") {
      record.push(field);
      records.push(record);
      record = [];
      field = "";
      index += 1;
    } else if (char === "\r") {
      index += 1;
    } else {
      field += char;
      index += 1;
    }
  }

  if (field.length > 0 || record.length > 0) {
    record.push(field);
    records.push(record);
  }

  return records;
}
