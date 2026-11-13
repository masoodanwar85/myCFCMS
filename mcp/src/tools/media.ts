/**
 * The media tools: list the library, and upload a file to it.
 *
 * No update and no delete, matching the API: `media.update` and `media.delete`
 * are both withheld from the `agent` role, so an agent labels what it uploads
 * and never relabels or removes somebody else's files.
 *
 * ## Why an upload is confined to a directory
 *
 * `upload_media` takes a path on the machine this server runs on, and the file
 * it sends ends up in a **publicly reachable** media library. An agent that can
 * be talked into uploading `~/.ssh/id_rsa` has published it, and the CMS's
 * extension allow-list would not stop a `.txt` or a `.csv`.
 *
 * So the path must resolve inside `CMS_UPLOAD_ROOT`, which defaults to the
 * working directory rather than to "anywhere". Symlinks are resolved before the
 * check, because a link inside the root pointing outside it is the obvious way
 * around a prefix test.
 */

import { basename, resolve, sep } from "node:path";
import { realpath, stat, readFile } from "node:fs/promises";
import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { Config } from "../config.js";
import { ToolError, json, optionalSite, requiredSite, run, readClient, writeClient } from "./shared.js";

export function registerMediaTools(server: McpServer, config: Config): void {
	server.registerTool(
		"list_media",
		{
			title: "List media",
			description:
				"The site's media library, newest first and paged. Each item carries the /media/... url " +
				"to reference from a page's content, featuredImage or ogImage.",
			inputSchema: {
				site: optionalSite,
				kind: z.enum(["image", "document"]).optional().describe("Narrow to one kind."),
				page: z.number().int().min(1).optional(),
				perPage: z.number().int().min(1).max(100).optional(),
			},
		},
		async ({ site, kind, page, perPage }) =>
			run(async () => {
				const client = readClient(config, site);
				const { data, meta } = await client.get<unknown[]>("/api/v1/media", { kind, page, perPage });

				return json({ site: client.site.name, page: meta, items: data });
			}),
	);

	server.registerTool(
		"upload_media",
		{
			title: "Upload a file to the media library",
			description:
				"Upload an image or document from a local path. Send altText for an image — it is the only thing " +
				"that stops the SEO audit reporting it, and there is no second call that can add it later. " +
				"Accepted: jpg, jpeg, png, gif, webp, pdf, docx, xlsx, pptx, csv, txt. SVG is refused on purpose.",
			inputSchema: {
				site: requiredSite,
				path: z.string().describe("Path to the file, inside the configured upload root."),
				altText: z.string().optional().describe("What a screen reader should say. Images only."),
				title: z.string().optional().describe("Label used when a [file] link gives none."),
			},
		},
		async ({ site, path, altText, title }) =>
			run(async () => {
				const client = writeClient(config, site);
				const file = await safePath(path, config.uploadRoot);
				const bytes = await readFile(file);

				const form = new FormData();
				form.append("file", new Blob([bytes]), basename(file));
				if (altText !== undefined) form.append("altText", altText);
				if (title !== undefined) form.append("title", title);

				const { data } = await client.upload<Record<string, unknown>>("/api/v1/media", form);

				return json({ site: client.site.name, uploaded: data });
			}),
	);
}

/**
 * The real path of a file inside the upload root, or a refusal.
 *
 * `realpath` first, then a separator-terminated prefix test — `/srv/mediafoo`
 * must not pass a test for `/srv/media`.
 */
async function safePath(given: string, root: string): Promise<string> {
	const realRoot = await realpath(resolve(root)).catch(() => resolve(root));
	let candidate: string;

	try {
		candidate = await realpath(resolve(given));
	} catch {
		throw new ToolError(`No such file: ${given}`);
	}

	if (candidate !== realRoot && !candidate.startsWith(realRoot + sep)) {
		throw new ToolError(
			`Refused: ${given} is outside the upload root (${realRoot}). ` +
				`Uploads become publicly reachable, so this server only sends files from inside that directory. ` +
				`Move the file there, or set CMS_UPLOAD_ROOT.`,
		);
	}

	const info = await stat(candidate);

	if (!info.isFile()) throw new ToolError(`Not a file: ${given}`);
	if (info.size === 0) throw new ToolError(`Refused: ${given} is empty.`);

	return candidate;
}
