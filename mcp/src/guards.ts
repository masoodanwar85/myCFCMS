/**
 * The confirmation gates.
 *
 * The operator's rule: drafts may be written freely; nothing becomes public,
 * and nothing already public is changed, without `confirm: true` in the call.
 *
 * ## Why this is one guard and not one per tool
 *
 * Three tools write to a page — `update_page`, `set_seo_fields` and
 * `apply_layout` — and all three are a `PATCH /api/v1/pages/:id`. Gating only
 * the obvious one would leave a hole worth driving through: changing a live
 * page's **canonical URL** removes it from search results and nothing about the
 * page looks broken, which is worse than a rewritten paragraph.
 *
 * ## Why it is client-side, and what covers that
 *
 * `pages.update` and `pages.publish` are ordinary API permissions, so anyone
 * holding the token can `curl` straight past everything here. These gates stop
 * an *agent* acting without a human, they do not stop a human. What covers the
 * gap is the CMS's own `api_change_log`: every write is recorded with a before
 * and after snapshot whichever route it took, so the question is "who did
 * this" rather than "did anyone".
 */

export interface PageState {
	readonly id: number;
	readonly title?: string;
	readonly path?: string;
	readonly status?: string;
	readonly publishFrom?: string;
}

export class ConfirmationRequired extends Error {
	constructor(message: string) {
		super(message);
		this.name = "ConfirmationRequired";
	}
}

/**
 * Is this page public, or going to be?
 *
 * `publishFrom` matters as much as `status`. A scheduled page is a draft today
 * and public on Thursday with nobody touching it, so editing it is editing
 * something that will be live — and the API returns both fields on the
 * single-page projection, which makes this free to check.
 */
export function isLive(page: PageState): boolean {
	return (page.status ?? "").toLowerCase() === "published" || Boolean(page.publishFrom?.trim());
}

export function describe(page: PageState, site: string): string {
	const title = page.title?.trim() || `page ${page.id}`;
	const path = page.path !== undefined ? `/${page.path}` : "";

	return `"${title}"${path ? ` (${path})` : ""} on ${site}`;
}

/**
 * Refuse a write to a live page unless the call confirmed it.
 *
 * `page` must be **re-read from the API immediately before this**, never taken
 * from an argument: a status the caller supplied would let the agent assert
 * "it's a draft" and be believed. There is a small race between the read and
 * the write if somebody publishes in between; that is a comment, not a locking
 * scheme.
 */
export function guardPageWrite(page: PageState, site: string, confirm: boolean | undefined): void {
	if (confirm === true || !isLive(page)) return;

	const why =
		(page.status ?? "").toLowerCase() === "published"
			? "is published"
			: `is scheduled to publish at ${page.publishFrom}`;

	throw new ConfirmationRequired(
		`${describe(page, site)} ${why}, so this edit changes what the public sees. ` +
			`Pass confirm: true to go ahead.`,
	);
}

/**
 * Publishing always needs confirmation — including for a page this agent
 * created a moment ago. Without that exception closed, `create_page` followed
 * by `publish_page` is an unguarded path to publishing, which is the whole
 * thing the gate exists to prevent.
 */
export function guardPublish(page: PageState, site: string, confirm: boolean | undefined): void {
	if (confirm === true) return;

	throw new ConfirmationRequired(
		`About to make ${describe(page, site)} publicly visible. Pass confirm: true to publish it.`,
	);
}
