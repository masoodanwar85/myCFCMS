/**
 * The layout tools.
 *
 * A "layout" in this CMS is a theme **template**: a `.cfm` file under the
 * theme's `templates/` directory, which a page opts into through its
 * `template` field. Themes themselves are code deployed with the application,
 * so nothing here creates or changes one.
 *
 * ## apply_layout validates the name first, and has to
 *
 * `PageService.safeTemplateName()` only strips characters — it does not check
 * the template exists. The front controller checks at render time and silently
 * falls back to the default page view. So this:
 *
 *     PATCH /api/v1/pages/12 { "template": "does-not-exist" }
 *
 * answers **200 with the value stored** and renders nothing different. A tool
 * that reported that as success would be lying to the agent, which would then
 * not look again. So the name is checked against the active theme's own list
 * before the write.
 */

import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { CmsClient } from "../cms.js";
import type { Config } from "../config.js";
import { guardPageWrite, type PageState } from "../guards.js";
import { ToolError, confirmFlag, json, optionalSite, requiredSite, run, readClient, writeClient } from "./shared.js";

interface Theme {
	slug: string;
	title: string;
	version?: string;
	description?: string;
	active: boolean;
	templates: string[];
}

export function registerLayoutTools(server: McpServer, config: Config): void {
	server.registerTool(
		"list_layouts",
		{
			title: "List layouts",
			description:
				"The templates a page can be given, per installed theme, with the site's active theme marked. " +
				"Only templates from the ACTIVE theme can be applied — apply_layout refuses the others.",
			inputSchema: { site: optionalSite },
		},
		async ({ site }) =>
			run(async () => {
				const client = readClient(config, site);
				const { data, meta } = await client.get<Theme[]>("/api/v1/themes");

				return json({
					site: client.site.name,
					activeTheme: meta?.active,
					themes: data.map((theme) => ({
						slug: theme.slug,
						title: theme.title,
						active: theme.active,
						layouts: theme.templates,
					})),
				});
			}),
	);

	server.registerTool(
		"get_layout",
		{
			title: "Get a layout",
			description:
				"Find one layout by name and say which theme offers it and whether that theme is the active one.",
			inputSchema: {
				site: optionalSite,
				name: z.string().describe("The layout (template) name, e.g. \"example\"."),
			},
		},
		async ({ site, name }) =>
			run(async () => {
				const client = readClient(config, site);
				const { data } = await client.get<Theme[]>("/api/v1/themes");
				const wanted = name.trim().toLowerCase();

				const offeredBy = data.filter((theme) =>
					theme.templates.some((template) => template.toLowerCase() === wanted),
				);

				if (!offeredBy.length) {
					return json({
						site: client.site.name,
						name,
						found: false,
						available: availableIn(data),
					});
				}

				return json({
					site: client.site.name,
					name,
					found: true,
					offeredBy: offeredBy.map((theme) => ({ theme: theme.slug, active: theme.active })),
					applicable: offeredBy.some((theme) => theme.active),
				});
			}),
	);

	server.registerTool(
		"apply_layout",
		{
			title: "Apply a layout to a page",
			description:
				"Set a page's template. The name is checked against the active theme first, because the API " +
				"accepts an unknown template with a 200 and then renders without it. " +
				"A live page needs confirm: true, as with any other edit.",
			inputSchema: {
				site: requiredSite,
				id: z.number().int().describe("The page id."),
				layout: z
					.string()
					.describe("The template name, or an empty string to clear it and use the theme's default page view."),
				confirm: confirmFlag,
			},
		},
		async ({ site, id, layout, confirm }) =>
			run(async () => {
				const client = writeClient(config, site);
				const wanted = layout.trim();

				if (wanted) await assertApplicable(client, wanted);

				const { data: before } = await client.get<PageState>(`/api/v1/pages/${id}`);
				guardPageWrite(before, client.site.name, confirm);

				const { data } = await client.patch<{ template?: string }>(`/api/v1/pages/${id}`, {
					template: wanted,
				});

				// The CMS strips anything that could climb out of the templates
				// directory, so the stored value can legitimately differ from
				// what was sent. Report what is actually on the page.
				return json({
					site: client.site.name,
					pageId: id,
					requested: wanted,
					stored: data.template ?? "",
					cleared: wanted === "",
				});
			}),
	);
}

async function assertApplicable(client: CmsClient, layout: string): Promise<void> {
	const { data } = await client.get<Theme[]>("/api/v1/themes");
	const active = data.find((theme) => theme.active);

	if (!active) {
		throw new ToolError(`No active theme on ${client.site.name}, so no layout can be applied.`);
	}

	const match = active.templates.find((template) => template.toLowerCase() === layout.toLowerCase());

	if (!match) {
		throw new ToolError(
			`The active theme "${active.slug}" on ${client.site.name} has no layout "${layout}". ` +
				`It offers: ${active.templates.join(", ") || "none"}. ` +
				`Applying an unknown layout would be accepted by the API and then silently ignored when the page renders.`,
		);
	}
}

function availableIn(themes: Theme[]): Record<string, string[]> {
	const out: Record<string, string[]> = {};
	for (const theme of themes) out[theme.slug] = theme.templates;
	return out;
}
