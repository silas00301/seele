// Run against an esbuild CommonJS bundle with pi-tui kept external.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const loaded = { exports: {} };
let nativeCalls = 0;
vm.runInNewContext(fs.readFileSync(process.argv[2], "utf8"), {
  AbortController,
  module: loaded,
  exports: loaded.exports,
  process: { env: {} },
  require(name) {
    if (name === "node:module")
      return {
        createRequire: () => () => ({
          evaluate(value) {
            nativeCalls++;
            return require(process.argv[3]).evaluate(value);
          },
        }),
      };
    assert.equal(name, "@earendil-works/pi-tui");
    return {
      visibleWidth: (text) => Array.from(text).length,
      truncateToWidth: (text, width) =>
        Array.from(text).slice(0, width).join(""),
    };
  },
});

const handlers = new Map();
let execute = async () => ({ code: 1, stdout: "" });
loaded.exports.default({
  on: (name, handler) => handlers.set(name, handler),
  exec: (...args) => execute(...args),
});
const message = (input, output) => ({
  type: "message",
  message: { role: "assistant", usage: { input, output } },
});
let sessionId = "one";
let leafId = "first";
let branch = [message(10, 5)];
let scans = 0;
let footer;
let cwd = "/fixture";
let sessionName;
let gitBranch = "";
let statuses = new Map();
const context = {
  mode: "tui",
  sessionManager: {
    getCwd: () => cwd,
    getSessionId: () => sessionId,
    getLeafId: () => leafId,
    getSessionName: () => sessionName,
    getBranch: () => {
      scans++;
      return branch;
    },
  },
  getContextUsage: () => ({ percent: 20 }),
  ui: {
    setFooter(factory) {
      footer = factory(
        { requestRender() {} },
        {
          fg: (_, text) => text,
          inverse: (text) => text,
          bold: (text) => text,
        },
        {
          onBranchChange: () => () => {},
          getGitBranch: () => gitBranch,
          getExtensionStatuses: () => statuses,
        },
      );
    },
  },
};

(async () => {
  await handlers.get("session_start")({}, context);
  for (let i = 0; i < 100; i++) assert.match(footer.render(200)[0], /↑10 ↓5/);
  assert.equal(scans, 1, "unchanged redraws must not traverse history");
  assert.equal(
    nativeCalls,
    3,
    "unchanged redraws reuse native preparation and host layout",
  );

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
  cwd = "/fixture/\x1b]52;c;PAYLOAD\x07visible";
  sessionName = "session\x1bPSECRET\x1b\\name";
  gitBranch = "main\u202e\x1b[31m-clean";
  statuses = new Map([["hostile", "safe\x9d52;c;SECRET\x9cstatus"]]);
  context.model = { id: "model\x00\u2066-safe" };
  const safe = footer.render(500)[0];
  assert.doesNotMatch(safe, /[\x00-\x1f\x7f-\x9f\u202e\u2066]/);
  assert.doesNotMatch(safe, /PAYLOAD|SECRET/);
  for (const text of [
    "/fixture/visible",
    "sessionname",
    "main-clean",
    "safestatus",
    "model-safe",
  ])
    assert.ok(safe.includes(text));
  sessionName = "title\x1b]52;c;INCOMPLETE";
  assert.doesNotMatch(footer.render(500)[0], /INCOMPLETE/);
  footer.dispose();
  const probes = [];
  execute = (file, args, options) =>
    new Promise((resolve) => {
      assert.equal(file, "@JJ_READER@");
      assert.deepEqual(Array.from(args), ["@JJ@", "detect"]);
      assert.equal(options.timeout, 5000);
      probes.push({ resolve, signal: options.signal });
    });
  const previousFooter = footer;
  const oldSession = handlers.get("session_start")({}, context);
  const newSession = handlers.get("session_start")({}, context);
  assert.equal(
    probes[0].signal.aborted,
    true,
    "new session aborts previous query",
  );
  probes[0].resolve({
    code: 0,
    stdout: JSON.stringify({ repository: true, revision: "stale" }),
  });
  await oldSession;
  assert.equal(footer, previousFooter, "stale query cannot install its footer");
  probes[1].resolve({
    code: 0,
    stdout: JSON.stringify({ repository: true, revision: "current" }),
  });
  await newSession;
  assert.notEqual(footer, previousFooter);
  assert.match(footer.render(500)[0], /jj current/);
  const revisions = [];
  execute = (_file, args) =>
    new Promise((resolve) => {
      assert.equal(args[1], "revision");
      revisions.push(resolve);
    });
  const refresh = handlers.get("agent_settled")();
  for (let i = 0; i < 100; i++) void handlers.get("agent_settled")();
  assert.equal(revisions.length, 1, "refresh callbacks share one active probe");
  revisions[0]({
    code: 0,
    stdout: JSON.stringify({ repository: true, revision: "during" }),
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(
    revisions.length,
    2,
    "one later probe retains a concurrent update",
  );
  revisions[1]({
    code: 0,
    stdout: JSON.stringify({ repository: true, revision: "latest" }),
  });
  await refresh;
  assert.match(footer.render(500)[0], /jj latest/);
  footer.dispose();
  assert.equal(
    probes[1].signal.aborted,
    true,
    "disposal aborts outstanding query",
  );
  console.log(
    "Pi footer cache, stale lifecycle and terminal-safety checks passed",
  );
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
