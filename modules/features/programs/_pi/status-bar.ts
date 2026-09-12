import type {
  ExtensionAPI,
  Theme,
  ThemeColor,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { createRequire } from "node:module";

const native = createRequire("@NODE_CORE@")("@NODE_CORE@");
function call(operation: string, ...args: unknown[]): any {
  const reply = JSON.parse(
    native.evaluate(
      JSON.stringify({ operation: `pi.${operation}`, arguments: args }),
    ),
  );
  if (!reply.ok) throw new Error(reply.error);
  return reply.value;
}
const numeric = (value: number | null | undefined) =>
  value == null || Number.isFinite(value) ? value : String(value);
interface Pill {
  color: ThemeColor;
  priority: number | null;
  text: string;
}
interface JjState {
  revision: string;
}
const JJ = "@JJ@";
const JJ_READER = "@JJ_READER@";
function renderPill(theme: Theme, pill: Pill): string {
  const edge = (text: string) => theme.fg(pill.color, text);
  const body = theme.inverse(
    theme.fg(pill.color, theme.bold(` ${pill.text} `)),
  );
  return edge("") + body + edge("");
}
async function readJj(
  pi: ExtensionAPI,
  cwd: string,
  mode: "detect" | "revision",
  signal: AbortSignal,
): Promise<JjState | null> {
  const result = await pi.exec(JJ_READER, [JJ, mode], {
    cwd,
    timeout: 5000,
    signal,
  });
  if (result.code !== 0) return mode === "detect" ? null : { revision: "?" };
  const metadata = JSON.parse(result.stdout);
  return metadata.repository
    ? { revision: call("sanitize", metadata.revision) || "?" }
    : null;
}
export default function (pi: ExtensionAPI) {
  let refreshJj: (() => Promise<void>) | undefined;
  let generation = 0;
  let pending: AbortController | undefined;
  pi.on("session_start", async (_event, ctx) => {
    const current = ++generation;
    pending?.abort();
    const controller = new AbortController();
    pending = controller;
    refreshJj = undefined;
    if (ctx.mode !== "tui") return;
    const cwd = ctx.sessionManager.getCwd();
    let jjState = await readJj(pi, cwd, "detect", controller.signal);
    if (generation !== current) return;
    let requestRender = () => {};
    let disposed = false;
    let refreshing = false;
    let refreshPending = false;
    refreshJj = async () => {
      if (!jjState || disposed || generation !== current) return;
      if (refreshing) {
        refreshPending = true;
        return;
      }
      refreshing = true;
      try {
        do {
          refreshPending = false;
          const revision =
            (await readJj(pi, cwd, "revision", controller.signal))?.revision ??
            "?";
          if (disposed || generation !== current) return;
          if (revision !== jjState.revision) {
            jjState = { revision };
            requestRender();
          }
        } while (refreshPending);
      } finally {
        refreshing = false;
      }
    };
    ctx.ui.setFooter((tui, theme, footerData) => {
      requestRender = () => tui.requestRender();
      let tokenSessionId: string | undefined;
      let tokenLeafId: string | null | undefined;
      let usage = { input: 0, output: 0 };
      let renderedKey: string | undefined;
      let renderedLine = "";
      const unsubscribe = footerData.onBranchChange(() => {
        if (jjState) void refreshJj?.();
        else tui.requestRender();
      });
      return {
        dispose() {
          disposed = true;
          controller.abort();
          unsubscribe();
        },
        invalidate() {
          tokenSessionId = undefined;
          renderedKey = undefined;
        },
        render(width: number): string[] {
          // Only metadata crosses the in-process ABI; completed branch identity
          // controls usage collection, so streaming redraws never scan history.
          const sessionId = ctx.sessionManager.getSessionId();
          const leafId = ctx.sessionManager.getLeafId();
          if (sessionId !== tokenSessionId || leafId !== tokenLeafId) {
            usage = call(
              "usage",
              ctx.sessionManager.getBranch().map((entry: any) => ({
                type: entry.type,
                role: entry.message?.role,
                input: numeric(entry.message?.usage?.input),
                output: numeric(entry.message?.usage?.output),
              })),
            );
            tokenSessionId = sessionId;
            tokenLeafId = leafId;
          }
          const snapshot = {
            cwd: ctx.sessionManager.getCwd(),
            home: process.env.HOME ?? process.env.USERPROFILE,
            jj: jjState?.revision ?? null,
            branch: footerData.getGitBranch(),
            sessionName: ctx.sessionManager.getSessionName(),
            statuses: [...footerData.getExtensionStatuses().values()],
            inputTokens: usage.input,
            outputTokens: usage.output,
            contextPercent: numeric(ctx.getContextUsage()?.percent),
            reasoning: ctx.model?.reasoning,
            thinkingLevel: ctx.thinkingLevel,
            modelId: ctx.model?.id,
          };
          // The host owns invalidation of opaque theme rendering. Keep one
          // completed line so unchanged streaming redraws do no native/layout work.
          const key = JSON.stringify([width, snapshot]);
          if (key === renderedKey) return [renderedLine];
          let { left, right }: { left: Pill[]; right: Pill[] } = call(
            "pills",
            snapshot,
          );
          // Pi owns terminal-cell measurement and truncation. Rust requests at
          // most two truncations and receives actual resulting widths each time.
          let stage = 0;
          let padding = 0;
          for (;;) {
            const measured = (pills: Pill[]) =>
              pills.map((pill) => ({
                priority: pill.priority,
                width: visibleWidth(pill.text),
              }));
            const layout = call(
              "layout",
              measured(left),
              measured(right),
              width,
              stage,
            );
            left = layout.left.map((index: number) => left[index]!);
            right = layout.right.map((index: number) => right[index]!);
            if (!layout.shrink) {
              padding = layout.padding;
              break;
            }
            const group = layout.shrink.side === "left" ? left : right;
            const pill = group[layout.shrink.index]!;
            pill.text = truncateToWidth(pill.text, layout.shrink.width, "…");
            stage = layout.nextStage;
          }
          const line =
            left.map((pill) => renderPill(theme, pill)).join(" ") +
            " ".repeat(padding) +
            right.map((pill) => renderPill(theme, pill)).join(" ");
          renderedLine = truncateToWidth(line, width, "");
          renderedKey = key;
          return [renderedLine];
        },
      };
    });
  });
  pi.on("agent_settled", async () => {
    await refreshJj?.();
  });
}
