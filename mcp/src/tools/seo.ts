/**
 * The SEO tools: audit one page, audit the site, find broken links.
 *
 * All three read **rendered HTML**, because that is what the CMS's audit module
 * does and it is the whole point: two `<h1>` on a page, a shortcode that became
 * an `<img>` with no alt, an inherited featured image, a module landing page
 * with no row in `pages` at all — none of those are visible in the database.
 *
 * ## One page blocks; the whole site does not
 *
 * `audit_page_seo` is one fetch and a handful of checks, so it answers in the
 * call. `audit_site_seo` is one HTTP request per URL — minutes on a large site —
 * so the CMS runs it on a background thread and this polls the run. That is why
 * starting one answers 202 and the findings arrive later.
 */

import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { CmsClient } from "../cms.js";
import type { Config } from "../config.js";
import { ToolError, json, optionalSite, run, readClient } from "./shared.js";

interface Finding {
	path: string;
	url: string;
	pageId: number;
	checkId: string;
	severity: string;
	message: string;
	detail: string;
}

interface Run {
	id: number;
	status: string;
	urlCount: number;
	queuedCount: number;
	errorCount: number;
	warningCount: number;
	noticeCount: number;
	issueCount: number;
	note: string;
	startedAt: string;
	finishedAt: string;
	findings?: Finding[];
	byCheck?: { checkId: string; severity: string; total: number }[];
	byPath?: Record<string, unknown>[];
}

const waitSeconds = z
	.number()
	.int()
	.min(0)
	.max(600)
	.optional()
	.describe("How long to wait for the crawl, in seconds. Default 180. 0 returns the run id immediately.");

export function registerSeoTools(server: McpServer, config: Config): void {
	server.registerTool(
		"audit_page_seo",
		{
			title: "Audit one page",
			description:
				"Fetch one live URL and check it: title and meta description length, a single h1, heading order, " +
				"missing image alt text, canonical tag, noindex, structured data, and — unless you turn it off — " +
				"every internal link on the page. Nothing is stored. Answers in this call.",
			inputSchema: {
				site: optionalSite,
				path: z
					.string()
					.optional()
					.describe("Site-relative path, with or without a leading slash. Omit or pass \"\" for the home page."),
				checkLinks: z
					.boolean()
					.optional()
					.describe("Probe the page's own internal links for 404s and redirects. Default true; one fetch per link."),
			},
		},
		async ({ site, path, checkLinks }) =>
			run(async () => {
				const client = readClient(config, site);
				const body: Record<string, unknown> = { path: path ?? "" };

				// Sent only when the caller said something, so the CMS's own
				// default stands otherwise.
				if (checkLinks !== undefined) body.checkLinks = checkLinks;

				const { data, meta } = await client.post<{
					path: string;
					url: string;
					statusCode: number;
					elapsedMs: number;
					error: string;
					checkedLinks: number;
					findings: Omit<Finding, "path" | "url" | "pageId">[];
				}>("/api/v1/seo-audits/page", body);

				return json({ site: client.site.name, counts: meta, result: data });
			}),
	);

	server.registerTool(
		"audit_site_seo",
		{
			title: "Audit the whole site",
			description:
				"Crawl every public URL and report what is wrong, grouped by problem and by page. " +
				"Takes one HTTP request per URL, so it runs in the background and this waits for it. " +
				"Refuses if an audit is already running on that site.",
			inputSchema: { site: optionalSite, waitSeconds },
		},
		async ({ site, waitSeconds: wait }) =>
			run(async () => {
				const client = readClient(config, site);
				const { data: started, meta } = await client.post<Run>("/api/v1/seo-audits");
				const finished = await poll(client, started.id, wait ?? 180);

				if (!finished) {
					return json({
						site: client.site.name,
						runId: started.id,
						status: "running",
						maxUrls: meta?.maxUrls,
						note: `Still running after ${wait ?? 180}s. The run continues; read it later with audit_site_seo's run id.`,
					});
				}

				return json({ site: client.site.name, run: summarise(finished) });
			}),
	);

	server.registerTool(
		"find_broken_links",
		{
			title: "Find broken links",
			description:
				"Internal links across the site that answer 404, or that go through a redirect. " +
				"Reuses the most recent finished audit when there is one; otherwise it starts a crawl and waits. " +
				"Each finding names the page CONTAINING the link, which is the page to edit.",
			inputSchema: {
				site: optionalSite,
				waitSeconds,
				fresh: z
					.boolean()
					.optional()
					.describe("Ignore the last audit and crawl again. Slower, but reflects edits made since."),
			},
		},
		async ({ site, waitSeconds: wait, fresh }) =>
			run(async () => {
				const client = readClient(config, site);
				const budget = wait ?? 180;
				let runId: number | undefined;
				let reused = false;

				if (!fresh) {
					const { data: runs } = await client.get<Run[]>("/api/v1/seo-audits");
					const latest = runs.find((entry) => entry.status === "finished");

					if (latest) {
						runId = latest.id;
						reused = true;
					}
				}

				if (runId === undefined) {
					const { data: started } = await client.post<Run>("/api/v1/seo-audits");
					const done = await poll(client, started.id, budget);

					if (!done) {
						return json({
							site: client.site.name,
							runId: started.id,
							status: "running",
							note: `Still crawling after ${budget}s; no link report yet.`,
						});
					}
					runId = done.id;
				}

				const { data: report } = await client.get<Run>(`/api/v1/seo-audits/${runId}`);
				const links = (report.findings ?? []).filter(
					(finding) => finding.checkId === "link.broken" || finding.checkId === "link.redirect",
				);

				return json({
					site: client.site.name,
					runId,
					reusedExistingAudit: reused,
					auditFinishedAt: report.finishedAt,
					urlsCrawled: report.urlCount,
					broken: links.filter((f) => f.checkId === "link.broken"),
					redirects: links.filter((f) => f.checkId === "link.redirect"),
				});
			}),
	);
}

/**
 * Wait for a run to stop being `running`.
 *
 * Returns undefined when the budget runs out — which is not a failure: the run
 * is still going on the server, and reporting "still running" with the id is
 * more useful than an error.
 *
 * The interval grows to 5s because the first few seconds are the only ones
 * likely to matter for a small site, and a two-hundred-URL crawl does not need
 * to be asked forty times a minute.
 */
async function poll(client: CmsClient, id: number, budgetSeconds: number): Promise<Run | undefined> {
	const deadline = Date.now() + budgetSeconds * 1000;
	let interval = 1000;

	for (;;) {
		const { data } = await client.get<Run>(`/api/v1/seo-audits/${id}`);

		if (data.status !== "running") {
			if (data.status === "failed") {
				throw new ToolError(`The audit failed: ${data.note || "no reason recorded"}`);
			}
			return data;
		}

		if (Date.now() >= deadline) return undefined;

		await new Promise((done) => setTimeout(done, Math.min(interval, Math.max(0, deadline - Date.now()))));
		interval = Math.min(interval * 1.5, 5000);
	}
}

/**
 * The findings an agent can act on, worst first, without the whole report.
 *
 * `byCheck` answers "what is wrong with this site" and the error list answers
 * "what do I fix first". The full set stays available through the run id.
 */
function summarise(run: Run) {
	const findings = run.findings ?? [];

	return {
		id: run.id,
		status: run.status,
		urlsCrawled: run.urlCount,
		notCrawled: run.queuedCount,
		errors: run.errorCount,
		warnings: run.warningCount,
		notices: run.noticeCount,
		note: run.note,
		byCheck: run.byCheck ?? [],
		worstFirst: findings.filter((finding) => finding.severity === "error").slice(0, 50),
		totalFindings: findings.length,
	};
}
