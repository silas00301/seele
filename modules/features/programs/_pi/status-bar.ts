import type { ExtensionAPI, Theme, ThemeColor } from "@earendil-works/pi-coding-agent";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

interface Pill {
  color: ThemeColor;
  priority: number;
  text: string;
}

const REQUIRED = Number.POSITIVE_INFINITY;
const ANSI_ESCAPE = /\x1b\[[0-?]*[ -/]*[@-~]/g;
const JJ = "@JJ@";
const JJ_REVISION_TEMPLATE = 'if(self.local_bookmarks(), self.local_bookmarks().join(","), change_id.shortest(8))';

interface JjState {
  revision: string;
}

function formatTokens(count: number): string {
  if (count < 1000) return `${count}`;
  if (count < 1_000_000) return `${(count / 1000).toFixed(count < 10_000 ? 1 : 0)}k`;
  return `${(count / 1_000_000).toFixed(count < 10_000_000 ? 1 : 0)}M`;
}

function formatPath(path: string): string {
  const home = process.env.HOME ?? process.env.USERPROFILE;
  if (!home) return path;
  if (path === home) return "~";
  return path.startsWith(`${home}/`) ? `~/${path.slice(home.length + 1)}` : path;
}

function sanitize(text: string): string {
  return text.replace(ANSI_ESCAPE, "").replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

function pillWidth(pill: Pill): number {
  return visibleWidth(pill.text) + 4;
}

function renderPill(theme: Theme, pill: Pill): string {
  const edge = (text: string) => theme.fg(pill.color, text);
  const body = theme.inverse(theme.fg(pill.color, theme.bold(` ${pill.text} `)));
  return edge("") + body + edge("");
}

function groupWidth(pills: Pill[]): number {
  return pills.reduce((width, pill, index) => width + pillWidth(pill) + (index === 0 ? 0 : 1), 0);
}

function totalWidth(left: Pill[], right: Pill[]): number {
  const gap = left.length > 0 && right.length > 0 ? 1 : 0;
  return groupWidth(left) + gap + groupWidth(right);
}

function removeLowestPriority(left: Pill[], right: Pill[]): boolean {
  const removable = [...left, ...right]
    .filter((pill) => pill.priority !== REQUIRED)
    .sort((a, b) => a.priority - b.priority)[0];

  if (!removable) return false;
  const group = left.includes(removable) ? left : right;
  group.splice(group.indexOf(removable), 1);
  return true;
}

function shrinkPill(pill: Pill, columns: number): void {
  const current = visibleWidth(pill.text);
  const target = Math.max(4, current - columns);
  pill.text = truncateToWidth(pill.text, target, "…");
}

async function readJjRevision(pi: ExtensionAPI, cwd: string): Promise<string> {
  const result = await pi.exec(
    JJ,
    ["log", "--no-graph", "--no-pager", "--color=never", "-r", "@", "-T", JJ_REVISION_TEMPLATE],
    { cwd, timeout: 2000 },
  );
  return result.code === 0 ? sanitize(result.stdout) || "?" : "?";
}

async function detectJj(pi: ExtensionAPI, cwd: string): Promise<JjState | null> {
  const result = await pi.exec(JJ, ["root"], { cwd, timeout: 2000 });
  if (result.code !== 0) return null;
  return { revision: await readJjRevision(pi, cwd) };
}

export default function (pi: ExtensionAPI) {
  let refreshJj: (() => Promise<void>) | undefined;

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    const cwd = ctx.sessionManager.getCwd();
    let jjState = await detectJj(pi, cwd);
    let requestRender = () => {};

    refreshJj = async () => {
      if (!jjState) return;
      const revision = await readJjRevision(pi, cwd);
      if (revision === jjState.revision) return;
      jjState = { revision };
      requestRender();
    };

    ctx.ui.setFooter((tui, theme, footerData) => {
      requestRender = () => tui.requestRender();
      let tokenSessionId: string | undefined;
      let tokenLeafId: string | null | undefined;
      let inputTokens = 0;
      let outputTokens = 0;
      const unsubscribe = footerData.onBranchChange(() => {
        if (jjState) void refreshJj?.();
        else tui.requestRender();
      });

      return {
        dispose: unsubscribe,
        invalidate() { tokenSessionId = undefined; },
        render(width: number): string[] {
          // Pi persists completed messages as append-only session entries.
          // Streaming redraws do not change that branch; switches, appends and
          // compaction move its leaf or replace the session.
          const sessionId = ctx.sessionManager.getSessionId();
          const leafId = ctx.sessionManager.getLeafId();
          if (sessionId !== tokenSessionId || leafId !== tokenLeafId) {
            inputTokens = 0;
            outputTokens = 0;
            for (const entry of ctx.sessionManager.getBranch()) {
              if (entry.type === "message" && entry.message.role === "assistant") {
                const usage = (entry.message as AssistantMessage).usage;
                inputTokens += usage.input;
                outputTokens += usage.output;
              }
            }
            tokenSessionId = sessionId;
            tokenLeafId = leafId;
          }

          const context = ctx.getContextUsage();
          const contextPercent = context?.percent;
          const contextColor: ThemeColor =
            contextPercent !== null && contextPercent !== undefined && contextPercent > 90
              ? "error"
              : contextPercent !== null && contextPercent !== undefined && contextPercent > 70
                ? "warning"
                : "success";
          const contextText = contextPercent === null || contextPercent === undefined ? "󰍛 ?" : `󰍛 ${contextPercent.toFixed(0)}%`;

          const left: Pill[] = [
            { color: "accent", priority: REQUIRED, text: ` ${formatPath(ctx.sessionManager.getCwd())}` },
          ];

          if (jjState) {
            left.push({ color: "success", priority: 2, text: `jj ${jjState.revision}` });
          } else {
            const branch = footerData.getGitBranch();
            if (branch) left.push({ color: "success", priority: 2, text: ` ${branch}` });
          }

          const sessionName = ctx.sessionManager.getSessionName();
          if (sessionName) left.push({ color: "syntaxString", priority: 0, text: sessionName });

          for (const status of footerData.getExtensionStatuses().values()) {
            const text = sanitize(status);
            if (text) left.push({ color: "muted", priority: 0, text });
          }

          const right: Pill[] = [];
          if (inputTokens > 0 || outputTokens > 0) {
            right.push({
              color: "muted",
              priority: 0,
              text: `↑${formatTokens(inputTokens)} ↓${formatTokens(outputTokens)}`,
            });
          }
          right.push({ color: contextColor, priority: REQUIRED, text: contextText });

          if (ctx.model?.reasoning) {
            const thinkingLevel = ctx.thinkingLevel ?? "off";
            const thinkingColor = `thinking${thinkingLevel[0]!.toUpperCase()}${thinkingLevel.slice(1)}` as ThemeColor;
            right.push({ color: thinkingColor, priority: 1, text: `󰔛 ${thinkingLevel}` });
          }

          right.push({
            color: "mdHeading",
            priority: REQUIRED,
            text: `󰚩 ${ctx.model?.id ?? "no model"}`,
          });

          while (totalWidth(left, right) > width && removeLowestPriority(left, right)) {
            // Drop optional pills before shortening the primary status.
          }

          if (totalWidth(left, right) > width) {
            shrinkPill(left[0]!, totalWidth(left, right) - width);
          }
          if (totalWidth(left, right) > width) {
            shrinkPill(right[right.length - 1]!, totalWidth(left, right) - width);
          }

          const leftLine = left.map((item) => renderPill(theme, item)).join(" ");
          const rightLine = right.map((item) => renderPill(theme, item)).join(" ");
          const padding = " ".repeat(Math.max(left.length > 0 && right.length > 0 ? 1 : 0, width - groupWidth(left) - groupWidth(right)));

          return [truncateToWidth(leftLine + padding + rightLine, width, "")];
        },
      };
    });
  });

  pi.on("agent_settled", async () => {
    await refreshJj?.();
  });
}
