#!/usr/bin/env node
/**
 * An MCP server for managing myCFCMS sites.
 *
 * Talks to the CMS **only over its REST API** at `/api/v1` — it opens no
 * database connection and never will. Two consequences worth stating: it can
 * do nothing an operator could not do with a token and `curl`, and every write
 * it makes is recorded in the CMS's own `api_change_log` with a before and
 * after snapshot.
 *
 * ## Which site
 *
 * A myCFCMS token is bound to one site, so a server that manages two sites
 * holds two tokens and every call names the site it means. Reads may fall back
 * to a default; **writes never do** — "publish the home page" with an implicit
 * site is how an agent publishes to the wrong client's website.
 *
 * ## What it will not do
 *
 * No delete, of anything. No unpublish. Nothing becomes public without
 * `confirm: true` in the call, and neither does an edit to something already
 * public. `src/guards.ts` says why, including what those gates do *not* cover.
 *
 * Configuration is environment only — see `.env.example`. Nothing reads a
 * credential from a tool argument, so an agent cannot name a token it was not
 * configured with.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { ConfigError, loadConfig } from "./config.js";
import { registerLayoutTools } from "./tools/layouts.js";
import { registerMediaTools } from "./tools/media.js";
import { registerPageTools } from "./tools/pages.js";
import { registerSeoTools } from "./tools/seo.js";

async function main(): Promise<void> {
	const config = loadConfig();

	const server = new McpServer({
		name: "mycfcms",
		version: "1.0.0",
	});

	registerPageTools(server, config);
	registerLayoutTools(server, config);
	registerMediaTools(server, config);
	registerSeoTools(server, config);

	// stderr, never stdout: stdout *is* the protocol stream, and one stray
	// line on it makes the server unparseable to the client.
	console.error(
		`mycfcms MCP server ready. Sites: ${[...config.sites.keys()].join(", ")}` +
			`${config.defaultSite ? ` (default for reads: ${config.defaultSite})` : " (no default — every call must name a site)"}`,
	);

	await server.connect(new StdioServerTransport());
}

main().catch((error: unknown) => {
	// A configuration mistake is the overwhelmingly likely failure here, and it
	// deserves its message rather than a stack trace the user has to read past.
	if (error instanceof ConfigError) {
		console.error(`Configuration error: ${error.message}`);
		process.exit(2);
	}

	console.error(error);
	process.exit(1);
});
