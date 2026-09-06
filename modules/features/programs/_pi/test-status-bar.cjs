// Run against an esbuild CommonJS bundle with pi-tui kept external.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const loaded = { exports: {} };
vm.runInNewContext(fs.readFileSync(process.argv[2], "utf8"), {
  module: loaded,
  exports: loaded.exports,
  process: { env: {} },
  require(name) {
    assert.equal(name, "@earendil-works/pi-tui");
    return {
      visibleWidth: (text) => Array.from(text).length,
      truncateToWidth: (text, width) => Array.from(text).slice(0, width).join(""),
    };
  },
});

const handlers = new Map();
loaded.exports.default({
  on: (name, handler) => handlers.set(name, handler),
  exec: async () => ({ code: 1, stdout: "" }),
});
const message = (input, output) => ({ type: "message", message: { role: "assistant", usage: { input, output } } });
let sessionId = "one";
let leafId = "first";
let branch = [message(10, 5)];
let scans = 0;
let footer;
const context = {
  mode: "tui",
  sessionManager: {
    getCwd: () => "/fixture",
    getSessionId: () => sessionId,
    getLeafId: () => leafId,
    getSessionName: () => undefined,
    getBranch: () => { scans++; return branch; },
  },
  getContextUsage: () => ({ percent: 20 }),
  ui: {
    setFooter(factory) {
      footer = factory({ requestRender() {} }, {
        fg: (_, text) => text,
        inverse: (text) => text,
        bold: (text) => text,
      }, {
        onBranchChange: () => () => {},
        getGitBranch: () => "",
        getExtensionStatuses: () => new Map(),
      });
    },
  },
};

(async () => {
  await handlers.get("session_start")({}, context);
  for (let i = 0; i < 100; i++) assert.match(footer.render(200)[0], /↑10 ↓5/);
  assert.equal(scans, 1, "unchanged redraws must not traverse history");

  branch = [...branch, message(20, 7)];
  leafId = "second";
  assert.match(footer.render(200)[0], /↑30 ↓12/);
  assert.equal(scans, 2);

  sessionId = "two"; // The new session deliberately reuses a leaf ID.
  branch = [message(3, 4)];
  assert.match(footer.render(200)[0], /↑3 ↓4/);
  assert.equal(scans, 3);

  leafId = "compaction";
  branch = [...branch, { type: "compaction" }];
  assert.match(footer.render(200)[0], /↑3 ↓4/);
  assert.equal(scans, 4);

  leafId = null;
  branch = [];
  assert.doesNotMatch(footer.render(200)[0], /↑/);
  assert.equal(scans, 5);
  footer.invalidate();
  footer.render(200);
  assert.equal(scans, 6, "explicit invalidation must refresh the cache");
  footer.dispose();
  console.log("Pi footer cache checks passed");
})().catch((error) => { console.error(error); process.exitCode = 1; });
