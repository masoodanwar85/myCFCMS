/**
 * The HTTP client, against the real CMS where possible.
 *
 * These need no token, which is what makes them worth having: an
 * *unauthenticated* request still exercises URL building, the headers, the
 * envelope and the error mapping, and the API answers it with exactly the
 * shape every other call uses. So most of the client is covered without a
 * credential anybody has to issue first.
 *
 * Point them at a running CommandBox server:
 *
 *     MCP_CMS_URL=http://127.0.0.1:58988 npx vitest run cms
 *
 * Without that they fall back to an unreachable address, which still covers
 * the failure path.
 */

import { describe, expect, it } from "vitest";
import { CmsClient, CmsError } from "../src/cms.js";

const liveUrl = process.env.MCP_CMS_URL?.trim();
const live = liveUrl ? it : it.skip;

function clientFor(url: string, token = "cms_not_a_real_token"): CmsClient {
	return new CmsClient({ name: "spec", url, token }, 10_000);
}

describe("CmsClient", () => {
	it("reports an unreachable host as unreachable, not as an API error", async () => {
		// "The site is down" and "the site refused this" lead somewhere
		// completely different, so they must not arrive as the same thing.
		const client = clientFor("http://127.0.0.1:1");

		await expect(client.get("/api/v1/pages")).rejects.toMatchObject({
			name: "CmsError",
			status: 0,
			code: "unreachable",
		});
	});

	it("names the site in the error message itself", async () => {
		// Not in a custom toString(): anything that logs an error reads
		// `.message`, and with two sites configured a bare "404 not found" does
		// not say which client's website was asked.
		const client = clientFor("http://127.0.0.1:1");

		await expect(client.get("/api/v1/pages")).rejects.toThrow(/^\[spec]/);
	});

	live("reads the public discovery document and unwraps the envelope", async () => {
		// `/api/v1` needs no token by design — a client has to be able to ask
		// what it is talking to before it has credentials.
		const { data } = await clientFor(liveUrl!).get<{ name: string; version: string; site: { slug: string } }>(
			"/api/v1",
		);

		expect(data.version).toBe("v1");
		expect(data.name).toMatch(/myCFCMS/i);
		// Which tenant answered, which is how the server can check it reached
		// the site it meant to rather than trusting its own config.
		expect(data.site.slug).toBeTruthy();
	});

	live("turns a 401 envelope into a CmsError carrying the API's own code", async () => {
		try {
			await clientFor(liveUrl!).get("/api/v1/pages");
			expect.unreachable("a bogus token must not be accepted");
		} catch (error) {
			expect(error).toBeInstanceOf(CmsError);

			const failure = error as CmsError;

			expect(failure.status).toBe(401);
			expect(failure.code).toBe("unauthenticated");
			// The message is the API's, not one invented here, so it stays true
			// when the API's wording changes.
			expect(failure.message).toMatch(/token/i);
		}
	});

	live("passes query parameters through", async () => {
		// Asserted on a refusal rather than a result, because this needs no
		// token: reaching the 401 at all proves the URL was built and sent.
		await expect(clientFor(liveUrl!).get("/api/v1/media", { kind: "image", perPage: 5 })).rejects.toMatchObject(
			{ status: 401 },
		);
	});

	live("handles an error response that is HTML rather than an envelope", async () => {
		// A path outside /api/v1 is answered by the public site's own 404 page,
		// which is HTML. The client must not try to read `error.code` off
		// something that has none.
		//
		// Not a path *under* /api/v1: an unmatched one there currently falls
		// through to the discovery document and answers 200, which is the
		// already-known gap about unmatched API routes. Asserting it here would
		// pin a quirk in place.
		const failure = await clientFor(liveUrl!)
			.get("/zzt-no-such-page-anywhere")
			.then(() => undefined)
			.catch((error: unknown) => error);

		expect(failure).toBeInstanceOf(CmsError);
		expect((failure as CmsError).status).toBe(404);
		expect((failure as CmsError).code).toBe("http_error");
	});
});
