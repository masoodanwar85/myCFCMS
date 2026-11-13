/**
 * The HTTP client. The only thing in this server that talks to the CMS.
 *
 * **Nothing here touches the database**, by design and not by accident: every
 * capability goes through `/api/v1`, so the server cannot do anything an
 * operator could not also do with a token and `curl`, and every write it makes
 * lands in the CMS's own `api_change_log` with a before-and-after snapshot.
 */

import type { Config, SiteConfig } from "./config.js";

export interface CmsFailure {
	readonly status: number;
	readonly code: string;
	readonly message: string;
}

export class CmsError extends Error {
	/** The API's own wording, without the prefix added below. */
	readonly apiMessage: string;

	constructor(
		readonly status: number,
		readonly code: string,
		apiMessage: string,
		readonly site: string,
	) {
		// The site is part of the **message**, not of a custom `toString()`:
		// anything that logs an error reads `.message`, and with two sites
		// configured "404 not found" on its own does not say which client's
		// website was asked.
		super(`[${site}] ${status} ${code}: ${apiMessage}`);
		this.name = "CmsError";
		this.apiMessage = apiMessage;
	}
}

export interface Envelope<T> {
	readonly data: T;
	readonly meta?: Record<string, unknown>;
}

export class CmsClient {
	constructor(
		readonly site: SiteConfig,
		private readonly timeoutMs: number,
	) {}

	get<T>(path: string, query?: Record<string, string | number | boolean | undefined>): Promise<Envelope<T>> {
		return this.send<T>("GET", path, { query });
	}

	post<T>(path: string, body?: unknown): Promise<Envelope<T>> {
		return this.send<T>("POST", path, { body });
	}

	patch<T>(path: string, body: unknown): Promise<Envelope<T>> {
		return this.send<T>("PATCH", path, { body });
	}

	/**
	 * A `multipart/form-data` upload. The CMS takes the file this way because
	 * `MediaService.upload()` hands the part to `fileUpload()`, which lands it
	 * in staging before anything looks at it — the extension allow-list, the
	 * size cap and the magic-byte check all sit downstream of that.
	 */
	upload<T>(path: string, form: FormData): Promise<Envelope<T>> {
		return this.send<T>("POST", path, { form });
	}

	private async send<T>(
		method: string,
		path: string,
		options: {
			body?: unknown;
			form?: FormData;
			query?: Record<string, string | number | boolean | undefined>;
		},
	): Promise<Envelope<T>> {
		const url = new URL(path, this.site.url);

		for (const [key, value] of Object.entries(options.query ?? {})) {
			if (value !== undefined) url.searchParams.set(key, String(value));
		}

		const headers: Record<string, string> = {
			Authorization: `Bearer ${this.site.token}`,
			Accept: "application/json",
		};

		// Not `BodyInit`: @types/node declares the value types but not that
		// alias, so naming it would tie this file to the DOM lib.
		let body: FormData | string | undefined;

		if (options.form) {
			// Deliberately no Content-Type: fetch sets it with the multipart
			// boundary, and setting it by hand produces a body the server
			// cannot parse.
			body = options.form;
		} else if (options.body !== undefined) {
			headers["Content-Type"] = "application/json";
			body = JSON.stringify(options.body);
		}

		const timeout = AbortSignal.timeout(this.timeoutMs);
		let response: Response;

		try {
			response = await fetch(url, { method, headers, body, signal: timeout, redirect: "manual" });
		} catch (cause) {
			const reason = cause instanceof Error ? cause.message : String(cause);
			// A connection failure is not an API error and must not be reported
			// as one — "the site is unreachable" and "the site refused this"
			// lead somewhere completely different.
			throw new CmsError(0, "unreachable", `Could not reach ${url.origin}: ${reason}`, this.site.name);
		}

		const text = await response.text();
		const parsed = text.length ? safeJson(text) : undefined;

		if (!response.ok) {
			const failure = (parsed as { error?: Partial<CmsFailure> } | undefined)?.error;

			throw new CmsError(
				response.status,
				failure?.code ?? "http_error",
				failure?.message ?? `${response.status} ${response.statusText}`.trim(),
				this.site.name,
			);
		}

		if (parsed === undefined || typeof parsed !== "object" || parsed === null) {
			throw new CmsError(
				response.status,
				"malformed_response",
				`Expected a JSON envelope from ${url.pathname}, got ${text.slice(0, 120) || "an empty body"}`,
				this.site.name,
			);
		}

		return parsed as Envelope<T>;
	}
}

export function clientFor(config: Config, site: SiteConfig): CmsClient {
	return new CmsClient(site, config.timeoutMs);
}

function safeJson(text: string): unknown {
	try {
		return JSON.parse(text);
	} catch {
		return undefined;
	}
}
