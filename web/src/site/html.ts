// A tiny HTML template helper: values interpolated into html`...` are escaped
// unless they are already SafeHtml (another html`` result, raw() or jsonLd()).

const ESCAPES: Record<string, string> = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
};

export class SafeHtml {
  readonly value: string;

  constructor(value: string) {
    this.value = value;
  }

  toString() {
    return this.value;
  }
}

export type HtmlValue = string | number | SafeHtml | null | undefined | false | HtmlValue[];

export function escapeHtml(text: string) {
  return text.replace(/[&<>"']/g, (char) => ESCAPES[char] ?? char);
}

function render(value: HtmlValue): string {
  if (value === null || value === undefined || value === false) {
    return "";
  }
  if (Array.isArray(value)) {
    return value.map(render).join("");
  }
  if (value instanceof SafeHtml) {
    return value.value;
  }
  return escapeHtml(String(value));
}

export function html(strings: TemplateStringsArray, ...values: HtmlValue[]) {
  let out = strings[0] ?? "";
  values.forEach((value, index) => {
    out += render(value) + (strings[index + 1] ?? "");
  });
  return new SafeHtml(out);
}

export function raw(markup: string) {
  return new SafeHtml(markup);
}

// Structured data for search engines. "<" is escaped so the JSON can never
// close the script element early.
export function jsonLd(data: unknown) {
  return raw(`<script type="application/ld+json">${JSON.stringify(data).replace(/</g, "\\u003c")}</script>`);
}

// A JSON data block read by page scripts (not executed).
export function jsonData(id: string, data: unknown) {
  return raw(`<script type="application/json" id="${escapeHtml(id)}">${JSON.stringify(data).replace(/</g, "\\u003c")}</script>`);
}
