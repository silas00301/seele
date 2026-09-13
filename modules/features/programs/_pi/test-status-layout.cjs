// Compare a saved reference bundle with the production native adapter using the
// same actual Pi terminal engine. No reference policy ships with the extension.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const { pathToFileURL } = require("node:url");
const [reference, production, addon, tuiPath] = process.argv.slice(2);
async function footer(bundle, data, tui) {
  const loaded = { exports: {} };
  vm.runInNewContext(fs.readFileSync(bundle, "utf8"), {
    AbortController,
    module: loaded,
    exports: loaded.exports,
    process: { env: { HOME: data.home, USERPROFILE: data.profile } },
    require(name) {
      if (name === "node:module")
        return { createRequire: () => () => require(addon) };
      if (name === "@earendil-works/pi-tui") return tui;
      throw Error(name);
    },
  });
  const events = new Map();
  loaded.exports.default({
    on: (name, fn) => events.set(name, fn),
    exec: async () => ({ code: 1, stdout: "" }),
  });
  let result;
  const palette = new Map(
    [
      "accent",
      "success",
      "syntaxString",
      "muted",
      "error",
      "warning",
      "thinkingOff",
      "thinkingMinimal",
      "thinkingLow",
      "thinkingMedium",
      "thinkingHigh",
      "thinkingXhigh",
      "mdHeading",
    ].map((v, i) => [v, 20 + i]),
  );
  await events.get("session_start")(
    {},
    {
      mode: "tui",
      model: data.model,
      thinkingLevel: data.thinking,
      getContextUsage: () => ({ percent: data.percent }),
      sessionManager: {
        getCwd: () => data.cwd,
        getSessionId: () => "one",
        getLeafId: () => "leaf",
        getSessionName: () => data.name,
        getBranch: () => [
          {
            type: "message",
            message: {
              role: "assistant",
              usage: { input: data.input, output: data.output },
            },
          },
          { type: "compaction" },
        ],
      },
      ui: {
        setFooter(factory) {
          result = factory(
            { requestRender() {} },
            {
              fg: (color, text) => {
                assert(palette.has(color), color);
                return `\x1b[38;5;${palette.get(color)}m${text}\x1b[39m`;
              },
              inverse: (text) => `\x1b[7m${text}\x1b[27m`,
              bold: (text) => `\x1b[1m${text}\x1b[22m`,
            },
            {
              onBranchChange: () => () => {},
              getGitBranch: () => data.branch,
              getExtensionStatuses: () =>
                new Map(data.statuses.map((v, i) => [i, v])),
            },
          );
        },
      },
    },
  );
  return result;
}
(async () => {
  const tui = await import(pathToFileURL(tuiPath));
  const counts = [
    0,
    10,
    999,
    1000,
    1150,
    2250,
    9999,
    10000,
    999999,
    1000000,
    10000000,
    Number.NaN,
    Infinity,
  ];
  const percentages = [
    undefined,
    null,
    0,
    12.5,
    70,
    70.5,
    90,
    90.5,
    100,
    NaN,
    Infinity,
  ];
  const names = [
    "session",
    "emoji 👩‍💻 🌸 漢字 e\u0301",
    "session\x1bPSECRET\x1b\\name",
    "invisible\u202ename",
    "unfinished\x1b]52;c;SECRET",
  ];
  let comparisons = 0;
  for (let i = 0; i < counts.length * percentages.length; i++) {
    const data = {
      home: i % 3 ? "/home/fixture" : "",
      profile: "/fallback",
      cwd:
        i % 2
          ? "/home/fixture/🦀/working tree"
          : "/elsewhere/long project name",
      input: counts[i % counts.length],
      output: counts[(i + 4) % counts.length],
      percent: percentages[i % percentages.length],
      name: names[i % names.length],
      branch: i % 4 ? "main" : "branch\x1b]52;c;SECRET\x07safe",
      statuses: ["extension one", "extension two\tactive", "x\u202ey"],
      model: {
        id: i % 2 ? "model-123" : "a very long model identifier",
        reasoning: i % 3 !== 0,
      },
      thinking: ["off", "minimal", "low", "medium", "high", "xhigh"][i % 6],
    };
    const old = await footer(reference, data, tui),
      next = await footer(production, data, tui);
    for (const width of [
      0, 1, 4, 8, 12, 20, 30, 40, 60, 80, 120, 160, 240, 500,
    ]) {
      assert.deepEqual(
        Array.from(next.render(width)),
        Array.from(old.render(width)),
        JSON.stringify({ i, width, data }),
      );
      comparisons++;
    }
    old.dispose();
    next.dispose();
  }
  console.log(
    `Pi native differential: ${comparisons} exact ANSI/Unicode/layout comparisons passed`,
  );
  if (process.env.SEELE_PI_BENCH) {
    const data = {
      home: "/home/fixture",
      cwd: "/home/fixture/project",
      input: 2250,
      output: 300,
      percent: 20,
      name: "session",
      branch: "main",
      statuses: ["ready"],
      model: { id: "model", reasoning: true },
      thinking: "high",
    };
    for (const [label, bundle] of [
      ["reference", reference],
      ["native", production],
    ]) {
      const renderer = await footer(bundle, data, tui);
      renderer.render(120);
      const start = process.hrtime.bigint();
      for (let i = 0; i < 10000; i++) renderer.render(120);
      console.log(
        `${label} unchanged footer redraw: ${Number(process.hrtime.bigint() - start) / 10000 / 1000} microseconds/call`,
      );
      renderer.dispose();
    }
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
