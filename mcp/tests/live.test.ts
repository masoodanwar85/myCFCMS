/**
 * The tools against a real CMS.
 *
 * **Skipped unless you opt in**, because there is no way to test these without
 * a live site and a real token, and a test suite that quietly writes to
 * whatever is configured is a test suite that will one day create pages on a
 * client's website.
 *
 * Two switches, deliberately separate:
 *
 *     MCP_LIVE_SITE=willcreator          # read-only checks run
 *     MCP_LIVE_ALLOW_WRITES=true         # the draft lifecycle runs too
 *
 * Writes are confined to pages slugged `zzt-mcp-...` and the test deletes
 * nothing — there is no delete tool — so a failed run leaves a draft behind for
 * you to look at. That is the right trade: an orphan draft is visible and
 * harmless, and the alternative would be a delete path this server refuses to
 * have.
 *
 *     npm run build && MCP_LIVE_SITE=local MCP_LIVE_ALLOW_WRITES=true npx vitest run live
 */

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const site = process.env.MCP_LIVE_SITE?.trim();
const allowWrites = process.env.MCP_LIVE_ALLOW_WRITES?.trim() === "true";
const entry = resolve(dirname(fileURLToPath(import.meta.url)), "../dist/index.js");

const live = site ? describe : describe.skip;
const writing = site && allowWrites ? describe : describe.skip;

let client: Client;

/** The tool's text payload, parsed when it is JSON. */
async function call(name: string, args: Record<string, unknown> = {}) {
	const result = (await client.callTool({ name, arguments: args })) as {
		isError?: boolean;
		content: { type: string; text: string }[];
	};

	const text = result.content.map((part) => part.text).join("\n");

	let parsed: unknown;
	try {
		parsed = JSON.parse(text);
	} catch {
		parsed = undefined;
	}

	return { isError: result.isError === true, text, data: parsed as Record<string, unknown> | undefined };
}

beforeAll(async () => {
	if (!site) return;

	// The server's own process env, so the CMS_SITE_* variables the operator
	// configured are what it uses — no credential is duplicated into this file.
	const transport = new StdioClientTransport({
		command: process.execPath,
		args: [entry],
		env: process.env as Record<string, string>,
		stderr: "pipe",
	});

	client = new Client({ name: "live-spec", version: "1.0.0" });
	await client.connect(transport);
}, 60_000);

afterAll(async () => {
	await client?.close();
});

live("reading a real site", () => {
	it("lists pages", async () => {
		const { isError, data } = await call("list_pages", { site });

		expect(isError, JSON.stringify(data)).toBe(false);
		expect(data?.site).toBe(site);
		expect(Array.isArray(data?.pages)).toBe(true);
	}, 60_000);

	it("lists layouts and marks the active theme", async () => {
		const { isError, data } = await call("list_layouts", { site });

		expect(isError).toBe(false);
		expect(data?.activeTheme).toBeTruthy();
	}, 60_000);

	it("audits the home page and returns findings", async () => {
		// `checkLinks: false` so one slow page cannot make this the longest test
		// in the suite; the link probe is covered by the CMS's own specs.
		const { isError, data } = await call("audit_page_seo", { site, path: "", checkLinks: false });

		expect(isError, JSON.stringify(data)).toBe(false);

		const result = data?.result as { statusCode?: number; findings?: unknown[] } | undefined;

		expect(result?.statusCode).toBeDefined();
		expect(Array.isArray(result?.findings)).toBe(true);
	}, 120_000);

	it("reports an unknown page as a tool error, not a crash", async () => {
		const { isError, text } = await call("get_page", { site, id: 999_999_999 });

		expect(isError).toBe(true);
		expect(text).toMatch(/not_found|404/);
	}, 60_000);

	it("refuses an unknown site by name", async () => {
		const { isError, text } = await call("list_pages", { site: "definitely-not-configured" });

		expect(isError).toBe(true);
		expect(text).toMatch(/Unknown site/);
	}, 60_000);
});

writing("the draft lifecycle", () => {
	let pageId: number | undefined;
	const slug = `zzt-mcp-${Date.now().toString(36)}`;

	it("creates a draft, not a published page", async () => {
		const { isError, data } = await call("create_page", {
			site,
			title: "An MCP server test draft",
			slug,
			content: "<p>Written by the live test. Safe to delete.</p>",
		});

		expect(isError, JSON.stringify(data)).toBe(false);

		const created = data?.created as { id: number; status: string };

		expect(created.status).toBe("draft");
		pageId = created.id;
	}, 60_000);

	it("updates the draft with no confirmation needed", async () => {
		// The whole point of gating on "is it live" rather than "is it a write":
		// drafts are the agent's to edit freely.
		const { isError, data } = await call("update_page", {
			site,
			id: pageId,
			metaDescription: "A description written by the live test, long enough to be realistic.",
		});

		expect(isError, JSON.stringify(data)).toBe(false);
		expect(data?.changed).toEqual(["metaDescription"]);
	}, 60_000);

	it("refuses to publish without confirmation, and says what it would publish", async () => {
		const { isError, text } = await call("publish_page", { site, id: pageId });

		expect(isError).toBe(true);
		expect(text).toMatch(/confirm: true/);
		expect(text).toContain("An MCP server test draft");
		expect(text).toContain(site!);
	}, 60_000);

	it("still has the page as a draft after the refusal", async () => {
		// A refusal must change nothing. If the gate ran after the write it
		// would read as a refusal and behave as a publish.
		const { data } = await call("get_page", { site, id: pageId });

		expect((data?.page as { status: string }).status).toBe("draft");
	}, 60_000);

	it("refuses an unknown layout instead of storing it", async () => {
		// The API would answer 200 and then silently ignore the template, so
		// this check is the only thing between the agent and a false success.
		const { isError, text } = await call("apply_layout", {
			site,
			id: pageId,
			layout: "definitely-not-a-real-template",
		});

		expect(isError).toBe(true);
		expect(text).toMatch(/has no layout/);
	}, 60_000);

	it("publishes once confirmed, then reports a repeat as a no-op", async () => {
		const first = await call("publish_page", { site, id: pageId, confirm: true });

		expect(first.isError, first.text).toBe(false);
		expect((first.data?.published as { status: string }).status).toBe("published");

		const again = await call("publish_page", { site, id: pageId, confirm: true });

		expect(again.isError).toBe(false);
		expect(again.data?.alreadyPublished).toBe(true);
	}, 90_000);

	it("now requires confirmation to edit, because the page is live", async () => {
		const { isError, text } = await call("update_page", { site, id: pageId, title: "Renamed while live" });

		expect(isError).toBe(true);
		expect(text).toMatch(/is published/);
	}, 60_000);

	it("edits the live page once confirmed", async () => {
		const { isError, data } = await call("update_page", {
			site,
			id: pageId,
			title: "Renamed with confirmation",
			confirm: true,
		});

		expect(isError, JSON.stringify(data)).toBe(false);
		expect((data?.page as { title: string }).title).toBe("Renamed with confirmation");
	}, 60_000);
});
