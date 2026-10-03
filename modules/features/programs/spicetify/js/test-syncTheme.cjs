const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const colors = {};
let poll;
let requestCount = 0;
let responseMode = "ok";
const deadlines = new Map();
let nextDeadline = 0;
function stalled(signal) {
  return new Promise((_, reject) => {
    signal.addEventListener("abort", () => reject(new Error("aborted")), { once: true });
  });
}
let id = "catppuccin-mocha";
let palette = Object.fromEntries(
  Array.from({ length: 16 }, (_, index) => [`base${index.toString(16).toUpperCase().padStart(2, "0")}`, "#112233"]),
);
const context = {
  document: { documentElement: { style: { setProperty(key, value) { colors[key] = value; } } } },
  AbortController,
  setTimeout(fn, delay) {
    assert.equal(delay, 3000);
    const key = ++nextDeadline;
    deadlines.set(key, fn);
    return key;
  },
  clearTimeout(key) { deadlines.delete(key); },
  fetch: async (_, { signal }) => {
    requestCount++;
    if (responseMode === "fetch") return stalled(signal);
    return { ok: true, json: () => responseMode === "body" ? stalled(signal) : Promise.resolve({ id, palette }) };
  },
  setInterval(fn, delay) {
    assert.equal(delay, 750);
    poll = fn;
  },
};

vm.runInNewContext(fs.readFileSync(process.argv[2], "utf8"), context);
const settle = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  await settle();
  assert.equal(colors["--spice-main"], "#112233");
  assert.equal(colors["--spice-rgb-main"], "17,34,51");
  id = "flexoki-light";
  palette = { ...palette, base00: "#abcdef", base0D: "#445566" };
  await poll();
  assert.equal(colors["--spice-main"], "#abcdef");
  assert.equal(colors["--spice-rgb-main"], "171,205,239");
  assert.equal(colors["--spice-button"], "#112233");
  palette = { ...palette, base00: "#010203" };
  await poll();
  assert.equal(colors["--spice-main"], "#010203", "a rebuilt preset updates without changing its ID");
  id = "invalid";
  palette = { ...palette, base00: "red; background: black" };
  await poll();
  assert.equal(colors["--spice-main"], "#010203");
  assert.equal(deadlines.size, 0, "completed reads release deadlines");
  for (const mode of ["fetch", "body"]) {
    responseMode = mode;
    const pending = poll();
    await settle();
    const count = requestCount;
    await poll();
    assert.equal(requestCount, count, "polls cannot overlap a read");
    assert.equal(deadlines.size, 1);
    [...deadlines.values()][0]();
    await pending;
    assert.equal(deadlines.size, 0, "aborted reads release deadlines");
    assert.equal(colors["--spice-main"], "#010203", "timeouts preserve the palette");
    responseMode = "ok";
    palette = { ...palette, base00: mode === "fetch" ? "#224466" : "#6688aa" };
    await poll();
    assert.equal(colors["--spice-main"], palette.base00, "polling recovers after timeout");
    palette = { ...palette, base00: "#010203" };
    await poll();
  }
  assert.equal(deadlines.size, 0);
  console.log("Spicetify follows valid palettes and recovers from stalled requests");
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
