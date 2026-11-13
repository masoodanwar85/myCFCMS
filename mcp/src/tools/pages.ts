/**
 * The page tools: list, read, create, update, set SEO fields, publish.
 *
 * `create_page` saves a **draft**, always — that is the CMS's own default for a
 * new page, so nothing here has to enforce it. Publishing is a separate tool
 * with a separate permission and a confirmation gate.
 *
 * There is deliberately **no delete and no unpublish tool**. `pages.delete` is
 * withheld from the `agent` role so a delete tool could not work anyway, and
 * unpublishing was never asked for: the agent can put content up with a
 * human's confirmation and can never take it down. A human does that in the
 * admin, in two clicks.
 */

import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { Config } from "../config.js";
import { guardPageWrite, guardPublish, type PageState } from "../guards.js";
import {
	confirmFlag,
	given,
	json,
	optionalSite,
	pageContentFields,
	requiredSite,
	run,
	seoFields,
	text,
	readClient,
	writeClient,
} from "./shared.js";

const CONTENT_KEYS = Object.keys(pageContentFields);
const SEO_KEYS = Object.keys(seoFields);

export function registerPageTools(server: McpServer, config: Config): void {
	server.registerTool(
		"list_pages",
		{
			title: "List pages",
			description:
				"Every page on a site, as a flat list with paths, parent ids and draft/published status. " +
				"Bodies are left out; use get_page for one page's content.",
			inputSchema: { site: optionalSite },
		},
		async ({ site }) =>
			run(async () => {
				const client = readClient(config, site);
				const { data, meta } = await client.get<unknown[]>("/api/v1/pages");

				return json({ site: client.site.name, total: meta?.total ?? data.length, pages: data });
			}),
	);

	server.registerTool(
		"get_page",
		{
			title: "Get a page",
			description:
				"One page in full: body, SEO fields, template, featured image, schedule. " +
				"Read this before editing, so an update sends only what is actually changing.",
			inputSchema: { site: optionalSite, id: z.number().int().describe("The page id.") },
		},
		async ({ site, id }) =>
			run(async () => {
				const client = readClient(config, site);
				const { data } = await client.get<unknown>(`/api/v1/pages/${id}`);

				return json({ site: client.site.name, page: data });
			}),
	);

	server.registerTool(
		"create_page",
		{
			title: "Create a page (draft)",
			description:
				"Create a page. It is saved as a DRAFT and is not publicly visible — publish_page does that, " +
				"and needs confirmation. Content is sanitised by the CMS, so script is removed.",
			inputSchema: { site: requiredSite, ...pageContentFields, title: z.string().describe("The page title.") },
		},
		async (args) =>
			run(async () => {
				const client = writeClient(config, args.site);
				const { data } = await client.post<PageState>("/api/v1/pages", given(args, CONTENT_KEYS));

				return json({
					site: client.site.name,
					created: data,
					note: "Saved as a draft. Nothing is publicly visible until publish_page is called with confirm: true.",
				});
			}),
	);

	server.registerTool(
		"update_page",
		{
			title: "Update a page",
			description:
				"Change a page's title, slug, content, meta or position. Only the fields you pass are touched. " +
				"If the page is already published — or scheduled to publish — this refuses unless confirm is true, " +
				"because the edit would change what the public sees.",
			inputSchema: {
				site: requiredSite,
				id: z.number().int().describe("The page id."),
				...pageContentFields,
				confirm: confirmFlag,
			},
		},
		async (args) =>
			run(async () => {
				const client = writeClient(config, args.site);
				const changes = given(args, CONTENT_KEYS);

				if (!Object.keys(changes).length) {
					return text("Nothing to do: no fields were given to change.");
				}

				// Re-read, never trust a status from the caller: otherwise an
				// agent can assert "it's a draft" and be believed.
				const { data: before } = await client.get<PageState>(`/api/v1/pages/${args.id}`);
				guardPageWrite(before, client.site.name, args.confirm);

				const { data } = await client.patch<PageState>(`/api/v1/pages/${args.id}`, changes);

				return json({ site: client.site.name, changed: Object.keys(changes), page: data });
			}),
	);

	server.registerTool(
		"set_seo_fields",
		{
			title: "Set SEO fields",
			description:
				"Set canonical URL, robots, Open Graph, sitemap hints, featured image and meta fields on a page. " +
				"Gated the same way as update_page: a live page needs confirm: true. A wrong canonical URL " +
				"removes a page from search results while the page itself still looks fine.",
			inputSchema: {
				site: requiredSite,
				id: z.number().int().describe("The page id."),
				...seoFields,
				confirm: confirmFlag,
			},
		},
		async (args) =>
			run(async () => {
				const client = writeClient(config, args.site);
				const changes = given(args, SEO_KEYS);

				if (!Object.keys(changes).length) {
					return text("Nothing to do: no SEO fields were given.");
				}

				const { data: before } = await client.get<PageState>(`/api/v1/pages/${args.id}`);
				guardPageWrite(before, client.site.name, args.confirm);

				const { data } = await client.patch<Record<string, unknown>>(`/api/v1/pages/${args.id}`, changes);

				// Read back what was *stored*, not what was sent: the CMS
				// validates and corrects these — an unknown ogType becomes
				// "website", a priority is clamped, a canonical is normalised —
				// so echoing the request would misreport the result.
				const stored: Record<string, unknown> = {};
				for (const key of Object.keys(changes)) stored[key] = data[key];

				return json({ site: client.site.name, requested: changes, stored });
			}),
	);

	server.registerTool(
		"publish_page",
		{
			title: "Publish a page",
			description:
				"Make a page publicly visible. ALWAYS requires confirm: true — including for a page created " +
				"moments ago, because create-then-publish would otherwise be an unguarded way to publish. " +
				"There is no unpublish tool; a human does that in the admin.",
			inputSchema: {
				site: requiredSite,
				id: z.number().int().describe("The page id."),
				confirm: confirmFlag,
			},
		},
		async ({ site, id, confirm }) =>
			run(async () => {
				const client = writeClient(config, site);
				const { data: before } = await client.get<PageState>(`/api/v1/pages/${id}`);

				if ((before.status ?? "").toLowerCase() === "published") {
					// Idempotent, not an error. Re-publishing changes nothing a
					// human needs to approve.
					return json({
						site: client.site.name,
						alreadyPublished: true,
						page: before,
					});
				}

				guardPublish(before, client.site.name, confirm);

				const { data } = await client.post<PageState>(`/api/v1/pages/${id}/publish`);

				return json({ site: client.site.name, published: data });
			}),
	);
}
