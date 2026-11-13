/**
 * Configuration and site routing.
 *
 * Pure functions over an env struct, so these need no CMS and no network — and
 * they cover the rule that actually matters: a write never silently picks a
 * site.
 */

import { describe, expect, it } from "vitest";
import { ConfigError, loadConfig, normaliseSiteName, resolveSite } from "../src/config.js";

const twoSites = {
	CMS_SITE_WILLCREATOR_URL: "https://willcreator.com.au",
	CMS_SITE_WILLCREATOR_TOKEN: "cms_aaa",
	CMS_SITE_CLEVERMINDS_URL: "https://cleverminds.com.au/",
	CMS_SITE_CLEVERMINDS_TOKEN: "cms_bbb",
} as NodeJS.ProcessEnv;

describe("loadConfig", () => {
	it("reads a site per URL/TOKEN pair", () => {
		const config = loadConfig(twoSites);

		expect([...config.sites.keys()].sort()).toEqual(["cleverminds", "willcreator"]);
		expect(config.sites.get("willcreator")?.token).toBe("cms_aaa");
	});

	it("strips a trailing slash from the URL", () => {
		// Otherwise every request path doubles the slash.
		expect(loadConfig(twoSites).sites.get("cleverminds")?.url).toBe("https://cleverminds.com.au");
	});

	it("refuses a site with a URL and no token", () => {
		// It would otherwise fail on its first call with a 401 that reads like a
		// server problem rather than a missing variable.
		expect(() =>
			loadConfig({ CMS_SITE_ORPHAN_URL: "https://x.test" } as NodeJS.ProcessEnv),
		).toThrow(/CMS_SITE_ORPHAN_TOKEN/);
	});

	it("refuses a site with a token and no URL", () => {
		expect(() =>
			loadConfig({ CMS_SITE_ORPHAN_TOKEN: "cms_x" } as NodeJS.ProcessEnv),
		).toThrow(/CMS_SITE_ORPHAN_URL/);
	});

	it("refuses to start with no sites at all", () => {
		expect(() => loadConfig({} as NodeJS.ProcessEnv)).toThrow(ConfigError);
	});

	it("ignores a blank value rather than treating it as configured", () => {
		expect(() =>
			loadConfig({ ...twoSites, CMS_SITE_GHOST_URL: "   ", CMS_SITE_GHOST_TOKEN: "" } as NodeJS.ProcessEnv),
		).not.toThrow();
	});

	it("defaults to the only site when there is one", () => {
		const config = loadConfig({
			CMS_SITE_SOLO_URL: "https://solo.test",
			CMS_SITE_SOLO_TOKEN: "cms_c",
		} as NodeJS.ProcessEnv);

		expect(config.defaultSite).toBe("solo");
	});

	it("sets no default when several sites are configured", () => {
		// Guessing between two clients' websites is exactly what must not happen.
		expect(loadConfig(twoSites).defaultSite).toBeUndefined();
	});

	it("refuses a default naming a site that is not configured", () => {
		expect(() =>
			loadConfig({ ...twoSites, CMS_DEFAULT_SITE: "nosuchsite" } as NodeJS.ProcessEnv),
		).toThrow(/not configured/);
	});

	it("falls back to a sane timeout for a nonsense value", () => {
		expect(loadConfig({ ...twoSites, CMS_TIMEOUT_MS: "-5" } as NodeJS.ProcessEnv).timeoutMs).toBe(30_000);
		expect(loadConfig({ ...twoSites, CMS_TIMEOUT_MS: "banana" } as NodeJS.ProcessEnv).timeoutMs).toBe(30_000);
		expect(loadConfig({ ...twoSites, CMS_TIMEOUT_MS: "5000" } as NodeJS.ProcessEnv).timeoutMs).toBe(5000);
	});
});

describe("normaliseSiteName", () => {
	it("treats hyphens and underscores as the same", () => {
		// An env var cannot carry a hyphen mid-name but a site slug often does,
		// so "my-site" in a prompt has to find CMS_SITE_MY_SITE_URL.
		expect(normaliseSiteName("My-Site")).toBe(normaliseSiteName("my_site"));
	});
});

describe("resolveSite", () => {
	const config = loadConfig(twoSites);

	it("finds a site by name, ignoring case", () => {
		expect(resolveSite(config, "WillCreator", false).name).toBe("willcreator");
	});

	it("names the configured sites when asked for an unknown one", () => {
		// So the agent's next call can be right instead of another guess.
		expect(() => resolveSite(config, "nope", false)).toThrow(/willcreator/);
	});

	it("refuses a write with no site, even when a default exists", () => {
		const withDefault = loadConfig({ ...twoSites, CMS_DEFAULT_SITE: "willcreator" } as NodeJS.ProcessEnv);

		expect(resolveSite(withDefault, undefined, false).name).toBe("willcreator");
		expect(() => resolveSite(withDefault, undefined, true)).toThrow(/explicit site/);
	});

	it("refuses a read with no site when several are configured and none is default", () => {
		expect(() => resolveSite(config, undefined, false)).toThrow(/needs a site/);
	});

	it("treats whitespace as absent", () => {
		expect(() => resolveSite(config, "   ", true)).toThrow(/explicit site/);
	});
});
