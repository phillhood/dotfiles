import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

function readJson(path: string): Record<string, any> {
	try {
		return existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : {};
	} catch {
		return {};
	}
}

function getHideThinkingBlock(cwd: string, projectTrusted: boolean): boolean {
	const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(process.env.HOME ?? "", ".pi", "agent");
	const globalSettings = readJson(join(agentDir, "settings.json"));
	const projectSettings = projectTrusted ? readJson(join(cwd, ".pi", "settings.json")) : {};
	return Boolean(projectSettings.hideThinkingBlock ?? globalSettings.hideThinkingBlock);
}

const icons = {
	// Nerd Font / Font Awesome glyphs, plus plain Unicode state markers.
	input: "", // nf-fa-sign_in
	output: "", // nf-fa-sign_out
	reasoning: "", // nf-fa-brain
	cost: "", // nf-fa-usd
	context: "", // nf-fa-database
	speed: "", // nf-fa-tachometer
	model: "", // nf-oct-package
	think: "", // nf-fa-lightbulb_o
	tools: "", // nf-fa-wrench
	off: "✗",
	on: "✓",
};

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		const projectTrusted = ctx.isProjectTrusted();

		// Track tokens/sec for the most recent assistant response
		let lastSpeed: number | null = null;
		let assistantStartTime: number | null = null;

		pi.on("message_start", async (event) => {
			if (event.message.role === "assistant") {
				assistantStartTime = Date.now();
			}
		});

		pi.on("message_end", async (event) => {
			if (event.message.role === "assistant") {
				const m = event.message as AssistantMessage;
				const outputTokens = m.usage.output;
				const elapsed = assistantStartTime ? (Date.now() - assistantStartTime) / 1000 : 0;

				// Skip if elapsed is unreasonably small (e.g. restored from session)
				if (elapsed > 0.5 && outputTokens > 0) {
					lastSpeed = Math.round(outputTokens / elapsed);
				}
				assistantStartTime = null;
			}
		});

		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsub = footerData.onBranchChange(() => tui.requestRender());
			const unsubThinking = pi.on("thinking_level_select", () => tui.requestRender());

			return {
				dispose() {
					unsub();
					unsubThinking();
				},
				invalidate() {},
				render(width: number): string[] {
					let input = 0,
						output = 0,
						cost = 0,
						reasoning = 0;
					for (const e of ctx.sessionManager.getBranch()) {
						if (e.type === "message" && e.message.role === "assistant") {
							const m = e.message as AssistantMessage;
							input += m.usage.input;
							output += m.usage.output;
							cost += m.usage.cost.total;
							reasoning += m.usage.reasoningTokens ?? 0;
						}
					}

					const fmt = (n: number) => {
						if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
						if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
						return `${n}`;
					};
					const fmtThousands = (n: number) => n >= 1000 ? `${Math.round(n / 1000)}k` : `${n}`;

					// Separator
					const sep = " " + theme.fg("dim", "│") + " ";

					// Session context usage — model's context window
					const contextUsage = ctx.getContextUsage();
					const ctxLimit = contextUsage?.limit ?? ctx.model?.contextWindow ?? 0;
					const ctxTokens = contextUsage?.tokens ?? 0;
					let contextPct = "";
					if (ctxLimit > 0) {
						const pct = (ctxTokens / ctxLimit) * 100;
						const color = pct > 80 ? "error" : pct > 50 ? "warning" : "success";
						contextPct = theme.fg(color, icons.context + " " + `${pct.toFixed(1)}%`) + theme.fg("dim", "/" + fmtThousands(ctxLimit));
					}

					const branch = footerData.getGitBranch();

					// Colored stat labels — using valid theme token names only
					const arrowUp = theme.fg("success", icons.input + " ") + theme.fg("text", fmt(input));
					const arrowDown = theme.fg("error", icons.output + " ") + theme.fg("text", fmt(output));
					const reasoningStr = reasoning > 0
						? theme.fg("accent", icons.reasoning + " ") + theme.fg("text", fmt(reasoning))
						: "";
					const costStr = theme.fg("warning", icons.cost + " " + cost.toFixed(3));
					const speedStr = lastSpeed !== null
						? theme.fg("mdLink", icons.speed + " " + fmt(lastSpeed) + "t/s")
						: "";
					const thinkingHidden = getHideThinkingBlock(ctx.cwd, projectTrusted);
					const thinkingDisplayStr = theme.fg(
						thinkingHidden ? "muted" : "success",
						icons.think + " " + (thinkingHidden ? icons.off : icons.on),
					);
					const toolsExpanded = ctx.ui.getToolsExpanded();
					const toolsDisplayStr = theme.fg(
						toolsExpanded ? "success" : "muted",
						icons.tools + " " + (toolsExpanded ? icons.on : icons.off),
					);

					const thinkingLevel = pi.getThinkingLevel();
					// Thinking level dot colors — using valid tokens
					const levelColors: Record<string, string> = {
						off: "thinkingOff",
						minimal: "thinkingMinimal",
						low: "thinkingLow",
						medium: "thinkingMedium",
						high: "thinkingHigh",
						xhigh: "thinkingXhigh",
						"extra-high": "thinkingXhigh",
						max: "thinkingMax",
					};
					const levelColor = levelColors[thinkingLevel] || "accent";
					const levelDot = theme.fg(levelColor, "●");
					const modelStr = theme.fg("accent", icons.model + " " + (ctx.model?.id || "no-model"));
					const levelStr = theme.fg("muted", thinkingLevel);

					// Git branch — use success color
					const gitStr = branch ? theme.fg("toolDiffAdded", " " + branch) : "";

					// ===== LEFT: stats with │ separators between each =====
					const leftParts = [
						arrowUp,
						arrowDown,
						reasoningStr,
						costStr,
						contextPct,
						speedStr,
						thinkingDisplayStr,
						toolsDisplayStr,
					].filter(Boolean);

					const left = leftParts.join(sep);

					// ===== RIGHT: model info =====
					const rightParts = [
						modelStr,
						levelDot + " " + levelStr,
						gitStr,
					].filter(Boolean);

					const right = rightParts.join(" " + theme.fg("dim", "•") + " ");
					const midSep = right ? " " + theme.fg("dim", "│") + " " : "";

					// Pad left side so right side is right-aligned
					const leftContent = left + midSep;
					const padNeeded = Math.max(1, width - visibleWidth(leftContent) - visibleWidth(right));
					const pad = " ".repeat(padNeeded);

					return [truncateToWidth(leftContent + pad + right, width)];
				},
			};
		});
	});
}
