import { type ExtensionAPI, type ExtensionContext, type Theme } from "@earendil-works/pi-coding-agent";
import { backgroundAnsi, foregroundAnsi, isAppleTerminalSession, rgbColor, truncateToWidth } from "@earendil-works/pi-tui";
import { homedir, userInfo } from "node:os";

// Same pixels, brand colors, and Apple Terminal fallback as Pi's built-in logo.
function defaultLogo(theme: Theme): string[] {
	const mode = theme.getColorMode();
	const coral = foregroundAnsi(rgbColor(228, 138, 122), mode);
	const blue = foregroundAnsi(rgbColor(79, 142, 179), mode);
	const yellow = foregroundAnsi(rgbColor(234, 182, 93), mode);
	const reset = "\x1b[0m";
	if (isAppleTerminalSession()) return [`${coral}P${reset}${yellow}i${reset}  `, "    "];
	return [
		`${coral}${backgroundAnsi(rgbColor(79, 142, 179), mode)}▀${reset}${coral}▀█${reset} `,
		`${blue}█▀${reset} ${yellow}█${reset}`,
	];
}

function compactPath(path: string): string {
	const home = homedir();
	return path === home ? "~" : path.startsWith(`${home}/`) ? `~${path.slice(home.length)}` : path;
}

export default function (pi: ExtensionAPI) {
	const user = userInfo().username;

	function install(ctx: ExtensionContext) {
		if (ctx.mode !== "tui") return;
		ctx.ui.setHeader((_tui, theme) => ({
			invalidate() {},
			render(width: number): string[] {
				const logo = defaultLogo(theme);
				const details = [
					["usr", user],
					["dir", compactPath(ctx.cwd)],
				];
				return details.map(([label, value], index) => truncateToWidth(
					` ${logo[index] ?? "    "}  ${theme.fg("dim", label.padEnd(8))} ${theme.fg("text", value)}`,
					width,
				));
			},
		}));
	}

	pi.on("session_start", (_event, ctx) => install(ctx));
}
