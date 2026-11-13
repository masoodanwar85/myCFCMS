/**
 * Where the sites are, and the credential for each.
 *
 * Everything comes from the environment. Nothing is read from a file in the
 * repository and no credential is ever a tool argument — an agent cannot name a
 * token it was not configured with, which is what keeps "which site am I
 * allowed to touch" a deployment decision rather than a prompt.
 *
 * ## One token per site, because the API insists
 *
 * A myCFCMS token is bound to the site it was issued for: present it against
 * another tenant's domain and the API answers 403 `wrong_site` even though the
 * token is perfectly good. So a server that can reach two sites holds two
 * tokens, and every tool call names which site it means.
 *
 * ## Why a URL per site and not one base URL plus a Host header
 *
 * Tenancy is resolved from the `Host` header, so the obvious design is one
 * origin and a per-site `Host` override. Node's `fetch` will not do it: `Host`
 * is a forbidden header in undici and is dropped silently — the request would
 * reach whichever tenant answers on that address, with no error to say so.
 *
 * A URL per site avoids the whole problem, because the URL *is* the host. In
 * production that is each site's own domain. Locally, add hosts entries
 * pointing the domains at loopback and keep the port:
 *
 *     127.0.0.1  willcreator.test  cleverminds.test
 *
 *     CMS_SITE_WILLCREATOR_URL=http://willcreator.test:58988
 *     CMS_SITE_CLEVERMINDS_URL=http://cleverminds.test:58988
 */

export interface SiteConfig {
	/** The key an agent names, e.g. `willcreator`. */
	readonly name: string;
	/** Origin for this site, e.g. `https://willcreator.com.au`. */
	readonly url: string;
	readonly token: string;
}

export interface Config {
	readonly sites: ReadonlyMap<string, SiteConfig>;
	/** Used by read tools when a call does not name a site. Writes never default. */
	readonly defaultSite: string | undefined;
	readonly timeoutMs: number;
	/** Uploads must resolve inside this directory. */
	readonly uploadRoot: string;
}

export class ConfigError extends Error {}

/**
 * Site keys are compared with `-` and `_` treated as the same character and
 * case ignored, because an environment variable cannot hold a hyphen in the
 * middle of a name and a site slug very often does. `CMS_SITE_MY_SITE_URL` and
 * a prompt saying "my-site" have to mean the same thing.
 */
export function normaliseSiteName(value: string): string {
	return value.trim().toLowerCase().replace(/-/g, "_");
}

const SITE_VAR = /^CMS_SITE_(.+)_(URL|TOKEN)$/;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
	const parts = new Map<string, { url?: string; token?: string }>();

	for (const [key, value] of Object.entries(env)) {
		const match = SITE_VAR.exec(key);
		if (!match || !value || !value.trim()) continue;

		const name = normaliseSiteName(match[1]!);
		const field = match[2]!;
		const entry = parts.get(name) ?? {};

		if (field === "URL") entry.url = value.trim().replace(/\/+$/, "");
		else entry.token = value.trim();

		parts.set(name, entry);
	}

	const sites = new Map<string, SiteConfig>();
	const incomplete: string[] = [];

	for (const [name, entry] of parts) {
		// Both or neither. A site with a URL and no token would fail on its
		// first call with a 401 that reads like a server problem; saying so at
		// startup costs nothing and names the variable that is missing.
		if (!entry.url || !entry.token) {
			incomplete.push(
				`${name} (missing CMS_SITE_${name.toUpperCase()}_${entry.url ? "TOKEN" : "URL"})`,
			);
			continue;
		}
		sites.set(name, { name, url: entry.url, token: entry.token });
	}

	if (incomplete.length) {
		throw new ConfigError(`Incompletely configured site(s): ${incomplete.join(", ")}`);
	}

	if (!sites.size) {
		throw new ConfigError(
			"No sites configured. Set CMS_SITE_<NAME>_URL and CMS_SITE_<NAME>_TOKEN " +
				"for at least one site — see mcp/.env.example.",
		);
	}

	const requestedDefault = env.CMS_DEFAULT_SITE?.trim();
	let defaultSite: string | undefined;

	if (requestedDefault) {
		defaultSite = normaliseSiteName(requestedDefault);
		if (!sites.has(defaultSite)) {
			throw new ConfigError(
				`CMS_DEFAULT_SITE is "${requestedDefault}", which is not configured. ` +
					`Configured: ${[...sites.keys()].join(", ")}`,
			);
		}
	} else if (sites.size === 1) {
		// One site needs no ceremony; naming it on every read would be noise.
		defaultSite = [...sites.keys()][0];
	}

	return {
		sites,
		defaultSite,
		timeoutMs: positiveInt(env.CMS_TIMEOUT_MS, 30_000),
		// Defaults to the working directory rather than to "anywhere". An agent
		// that can be talked into uploading `~/.ssh/id_rsa` has published it to
		// a public media library, and the server's extension allow-list would
		// not stop a `.txt` or a `.csv`.
		uploadRoot: env.CMS_UPLOAD_ROOT?.trim() || process.cwd(),
	};
}

/**
 * Resolve the site a call means.
 *
 * @param required when true there is no falling back to the default, which is
 *        how every write tool is called: "publish the home page" with an
 *        implicit site is how an agent publishes to the wrong client's website.
 */
export function resolveSite(config: Config, requested: string | undefined, required: boolean): SiteConfig {
	const known = [...config.sites.keys()].join(", ");

	if (!requested || !requested.trim()) {
		if (required) {
			throw new ConfigError(
				`This tool changes content, so it needs an explicit site. Configured: ${known}`,
			);
		}
		if (!config.defaultSite) {
			throw new ConfigError(
				`More than one site is configured and no default is set, so this call needs a site. Configured: ${known}`,
			);
		}
		return config.sites.get(config.defaultSite)!;
	}

	const site = config.sites.get(normaliseSiteName(requested));

	if (!site) {
		throw new ConfigError(`Unknown site "${requested}". Configured: ${known}`);
	}

	return site;
}

function positiveInt(raw: string | undefined, fallback: number): number {
	const parsed = Number.parseInt(raw ?? "", 10);
	return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
