/**
 * The server, started for real over stdio and asked what it offers.
 *
 * No CMS is involved: the site config points at an address nothing answers on,
 * which is enough because nothing here calls a tool. What this does catch is
 * everything that goes wrong *before* a request — a zod schema the SDK cannot
 * turn into JSON Schema, a tool registered twice, a `console.log` polluting the
 * protocol stream — all of which otherwise show up as a client that silently
 * fails to connect.
 *
 * It also pins the two contracts an operator relies on: which tools exist, and
 * which of them demand an explicit site.
 */

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const entry = resolve(here, "../dist/index.js");

let client: Client;
let tools: { name: string; description?: string; inputSchema: { properties?: Record<string, unknown>; required?: string[] } }[];

beforeAll(async () => {
	const transport = new StdioClientTransport({
		command: process.execPath,
		args: [entry],
		// A deliberately unreachable site. Registration must not depend on the
		// CMS being up, and a server that only works against a live site is a
		// server nobody can diagnose.
		env: {
			PATH: process.env.PATH ?? "",
			CMS_SITE_TESTSITE_URL: "http://127.0.0.1:1",
			CMS_SITE_TESTSITE_TOKEN: "cms_not_a_real_token",
		},
		stderr: "pipe",
	});

	client = new Client({ name: "spec", version: "1.0.0" });
	await client.connect(transport);

	tools = (await client.listTools()).tools as typeof tools;
}, 30_000);

afterAll(async () => {
	await client?.close();
});

describe("the server", () => {
	it("connects over stdio with no CMS reachable", () => {
		expect(tools.length).toBeGreaterThan(0);
	});

	it("offers every tool the brief asked for", () => {
		const names = tools.map((tool) => tool.name).sort();

		expect(names).toEqual(
			[
				"apply_layout",
				"audit_page_seo",
				"audit_site_seo",
				"create_page",
				"find_broken_links",
				"get_layout",
				"get_page",
				"list_layouts",
				"list_media",
				"list_pages",
				"publish_page",
				"set_seo_fields",
				"update_page",
				"upload_media",
			].sort(),
		);
	});

	it("offers no tool that deletes or unpublishes anything", () => {
		// Deliberate, not an oversight: pages.delete and media.delete are
		// withheld from the agent role, and the agent can put content up but
		// never take it down.
		const names = tools.map((tool) => tool.name);

		for (const forbidden of ["delete_page", "remove_page", "unpublish_page", "delete_media"]) {
			expect(names).not.toContain(forbidden);
		}
	});

	it("requires an explicit site on every tool that writes", () => {
		// The rule the whole site-routing design exists for.
		for (const name of [
			"create_page",
			"update_page",
			"set_seo_fields",
			"publish_page",
			"apply_layout",
			"upload_media",
		]) {
			const tool = tools.find((candidate) => candidate.name === name);

			expect(tool, `${name} is missing`).toBeDefined();
			expect(tool!.inputSchema.required ?? [], `${name} must require site`).toContain("site");
		}
	});

	it("leaves site optional on every read-only tool", () => {
		for (const name of [
			"list_pages",
			"get_page",
			"list_layouts",
			"get_layout",
			"list_media",
			"audit_page_seo",
			"audit_site_seo",
			"find_broken_links",
		]) {
			const tool = tools.find((candidate) => candidate.name === name)!;

			expect(tool.inputSchema.required ?? [], `${name} should not require site`).not.toContain("site");
		}
	});

	it("exposes confirm on exactly the tools that can change what the public sees", () => {
		const withConfirm = tools
			.filter((tool) => Object.hasOwn(tool.inputSchema.properties ?? {}, "confirm"))
			.map((tool) => tool.name)
			.sort();

		expect(withConfirm).toEqual(["apply_layout", "publish_page", "set_seo_fields", "update_page"]);
	});

	it("describes each tool, because the description is how an agent picks one", () => {
		for (const tool of tools) {
			expect(tool.description?.length ?? 0, `${tool.name} has no description`).toBeGreaterThan(40);
		}
	});
});
