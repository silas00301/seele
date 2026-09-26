const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const colors = {};
let poll;
let id = "catppuccin-mocha";
let palette = Object.fromEntries(
  Array.from({ length: 16 }, (_, index) => [`base${index.toString(16).toUpperCase().padStart(2, "0")}`, "#112233"]),
);
const context = {
  document: { documentElement: { style: { setProperty(key, value) { colors[key] = value; } } } },
  fetch: async () => ({ ok: true, json: async () => ({ id, palette }) }),
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
  console.log("Spicetify follows valid palette changes");
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
