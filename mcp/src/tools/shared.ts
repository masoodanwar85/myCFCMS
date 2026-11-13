/**
 * Plumbing every tool shares: how a site is chosen, and how a result is shaped.
 */

import { z } from "zod";
import { CmsClient, CmsError, clientFor } from "../cms.js";
import { ConfigError, type Config, resolveSite } from "../config.js";
import { ConfirmationRequired } from "../guards.js";

export interface ToolResult {
	content: { type: "text"; text: string }[];
	isError?: boolean;
	// The SDK's result type carries an index signature for protocol extensions,
	// and a structural return type without one is not assignable to it.
	[key: string]: unknown;
}

/**
 * A refusal this server decided on, as opposed to one the CMS returned.
 *
 * Its own type so `run()` can report the message as written instead of
 * prefixing it with "Unexpected failure" — the text is the whole value of
 * these, because the agent reads it and chooses its next call from it.
 */
export class ToolError extends Error {
	constructor(message: string) {
		super(message);
		this.name = "ToolError";
	}
}

/**
 * `site` as an optional argument, for reads. Falls back to `CMS_DEFAULT_SITE`,
 * or to the only configured site when there is just one.
 */
export const optionalSite = z
	.string()
	.optional()
	.describe("Which configured site to read, e.g. \"willcreator\". Omit to use the default site.");

/**
 * `site` as a required argument, for writes. No default, ever: "publish the
 * home page" with an implicit site is how an agent publishes to the wrong
 * client's website.
 */
export const requiredSite = z
	.string()
	.describe("Which configured site to change, e.g. \"willcreator\". Required — writes never assume a site.");

export const confirmFlag = z
	.boolean()
	.optional()
	.describe(
		"Set true to go ahead with a change that affects what the public sees. " +
			"Without it the tool refuses and explains what it was about to do.",
	);

export function text(value: string): ToolResult {
	return { content: [{ type: "text", text: value }] };
}

export function json(value: unknown): ToolResult {
	return text(JSON.stringify(value, null, 2));
}

export function errorResult(message: string): ToolResult {
	return { content: [{ type: "text", text: message }], isError: true };
}

/**
 * Run a tool body, turning the three expected failures into a readable result
 * rather than a stack trace.
 *
 * A refusal is returned as an error **with the reason**, because the agent
 * reads it and retries — a bare "forbidden" produces a retry loop, while
 * "pass confirm: true" produces the right second call. Anything unrecognised
 * is reported as itself; swallowing it would hide a real bug behind a tidy
 * message.
 */
export async function run(body: () => Promise<ToolResult>): Promise<ToolResult> {
	try {
		return await body();
	} catch (error) {
		if (error instanceof ConfirmationRequired) return errorResult(`Not done. ${error.message}`);
		if (error instanceof ToolError) return errorResult(error.message);
		if (error instanceof ConfigError) return errorResult(error.message);
		if (error instanceof CmsError) return errorResult(error.message);

		return errorResult(`Unexpected failure: ${error instanceof Error ? error.message : String(error)}`);
	}
}

export function readClient(config: Config, site: string | undefined): CmsClient {
	return clientFor(config, resolveSite(config, site, false));
}

export function writeClient(config: Config, site: string): CmsClient {
	return clientFor(config, resolveSite(config, site, true));
}

/** The page fields an agent may set. Shared by create and update. */
export const pageContentFields = {
	title: z.string().optional().describe("The page title."),
	slug: z.string().optional().describe("URL segment. Derived from the title when omitted."),
	content: z.string().optional().describe("Body HTML. Sanitised by the CMS; script is removed."),
	metaTitle: z.string().optional().describe("<title> text, if it should differ from the page title."),
	metaDescription: z.string().optional().describe("Meta description. Aim for 70-160 characters."),
	parentId: z.number().int().optional().describe("Move under this page id, or 0 for the top level."),
	sortOrder: z.number().int().optional().describe("Position among its siblings."),
};

/** The SEO and display surface, for `set_seo_fields`. */
export const seoFields = {
	metaTitle: z.string().optional(),
	metaDescription: z.string().optional(),
	metaKeywords: z.string().optional(),
	canonicalUrl: z.string().optional().describe("Absolute or site-relative. Refused if it is neither."),
	robotsIndex: z.boolean().optional().describe("False adds noindex — the page leaves search results."),
	robotsFollow: z.boolean().optional(),
	ogTitle: z.string().optional(),
	ogDescription: z.string().optional(),
	ogImage: z.string().optional().describe("A /media/... URL from upload_media or list_media."),
	ogType: z.string().optional().describe("website or article; anything else falls back to website."),
	twitterCard: z.string().optional(),
	sitemapInclude: z.boolean().optional(),
	sitemapPriority: z.number().optional().describe("0.0 to 1.0, clamped by the CMS."),
	sitemapChangefreq: z.string().optional(),
	showHeading: z.boolean().optional().describe("Whether the theme draws its own h1."),
	featuredImage: z.string().optional(),
	inheritFeaturedImage: z.boolean().optional(),
};

/**
 * Drop the keys a call did not mention.
 *
 * What makes every write a PATCH. The CMS leaves an absent field alone, so
 * sending `undefined` for everything the agent did not name is the difference
 * between "fix the title" and "blank the canonical somebody else set".
 */
export function given<T extends Record<string, unknown>>(args: T, keys: readonly string[]): Record<string, unknown> {
	const body: Record<string, unknown> = {};

	for (const key of keys) {
		if (args[key] !== undefined) body[key] = args[key];
	}

	return body;
}
