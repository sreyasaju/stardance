import { Controller } from "@hotwired/stimulus";

// Records the user's visited URLs in localStorage so the in-app back arrow
// can travel through their actual nav history (independent of the browser's
// back stack, which can be polluted by Turbo prefetching, frame loads, etc.).
//
// Mount on a long-lived element — the sidebar is `data-turbo-permanent`, so
// this controller's connect() runs once and the listener it installs catches
// every subsequent Turbo navigation.

export const HISTORY_KEY = "stardance.nav-history";
const MAX_ENTRIES = 50;

export default class extends Controller {
  connect() {
    this._record = this._record.bind(this);
    this._record();
    document.addEventListener("turbo:load", this._record);
  }

  disconnect() {
    document.removeEventListener("turbo:load", this._record);
  }

  _record() {
    const url = window.location.pathname + window.location.search;
    const stack = readStack();
    const top = stack[stack.length - 1];

    if (top === url) return; // exact dedupe

    // Same pathname (e.g. profile tab switches: /users/42?tab=feed →
    // /users/42?tab=devlogs) → replace the top entry so we remember the most
    // recent tab without growing the stack with every tab click.
    if (top && pathOnly(top) === pathOnly(url)) {
      stack[stack.length - 1] = url;
    } else {
      stack.push(url);
      while (stack.length > MAX_ENTRIES) stack.shift();
    }

    writeStack(stack);
  }
}

function pathOnly(url) {
  const q = url.indexOf("?");
  return q === -1 ? url : url.slice(0, q);
}

export function readStack() {
  try {
    return JSON.parse(localStorage.getItem(HISTORY_KEY)) || [];
  } catch {
    return [];
  }
}

export function writeStack(stack) {
  try {
    localStorage.setItem(HISTORY_KEY, JSON.stringify(stack));
  } catch {
    /* localStorage unavailable; navigation will fall back to the link href */
  }
}
