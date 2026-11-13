/**
 * The confirmation gates.
 *
 * The one piece of this server that exists purely to stop something, so it is
 * tested on what it must *refuse* as much as on what it must allow — a gate
 * that lets the wrong call through is worse than no gate, because the operator
 * believes there is one.
 */

import { describe, expect, it } from "vitest";
import { ConfirmationRequired, guardPageWrite, guardPublish, isLive } from "../src/guards.js";

const draft = { id: 1, title: "A draft", path: "a-draft", status: "draft" };
const published = { id: 2, title: "Live page", path: "live-page", status: "published" };
const scheduled = { id: 3, title: "Scheduled", path: "scheduled", status: "draft", publishFrom: "2026-11-01T09:00:00Z" };

describe("isLive", () => {
	it("is false for a plain draft", () => {
		expect(isLive(draft)).toBe(false);
	});

	it("is true for a published page", () => {
		expect(isLive(published)).toBe(true);
	});

	it("is true for a scheduled page, which is a draft today and public on Thursday", () => {
		expect(isLive(scheduled)).toBe(true);
	});

	it("ignores an empty publishFrom", () => {
		// The API returns "" rather than null for an unset date, so a truthiness
		// test on the raw value would make every draft look scheduled.
		expect(isLive({ id: 4, status: "draft", publishFrom: "" })).toBe(false);
		expect(isLive({ id: 5, status: "draft", publishFrom: "   " })).toBe(false);
	});

	it("does not care about the case of the status", () => {
		expect(isLive({ id: 6, status: "Published" })).toBe(true);
	});

	it("treats a missing status as not live", () => {
		expect(isLive({ id: 7 })).toBe(false);
	});
});

describe("guardPageWrite", () => {
	it("lets a draft through untouched", () => {
		expect(() => guardPageWrite(draft, "willcreator", undefined)).not.toThrow();
	});

	it("refuses an edit to a published page", () => {
		expect(() => guardPageWrite(published, "willcreator", undefined)).toThrow(ConfirmationRequired);
	});

	it("refuses an edit to a scheduled page and says when it goes live", () => {
		expect(() => guardPageWrite(scheduled, "willcreator", undefined)).toThrow(/2026-11-01/);
	});

	it("names the page and the site in the refusal", () => {
		// With two sites configured, "page 2 is published" does not say which
		// client's website is about to change.
		expect(() => guardPageWrite(published, "cleverminds", undefined)).toThrow(/Live page.*cleverminds/s);
	});

	it("allows the edit once confirmed", () => {
		expect(() => guardPageWrite(published, "willcreator", true)).not.toThrow();
	});

	it("treats false as not confirmed", () => {
		expect(() => guardPageWrite(published, "willcreator", false)).toThrow(ConfirmationRequired);
	});
});

describe("guardPublish", () => {
	it("refuses without confirmation even for a draft", () => {
		// Publishing is the act being gated, not the page's current state —
		// otherwise create_page followed by publish_page is an unguarded way to
		// publish.
		expect(() => guardPublish(draft, "willcreator", undefined)).toThrow(ConfirmationRequired);
	});

	it("says what is about to become public", () => {
		expect(() => guardPublish(draft, "willcreator", undefined)).toThrow(/A draft.*willcreator/s);
	});

	it("allows it once confirmed", () => {
		expect(() => guardPublish(draft, "willcreator", true)).not.toThrow();
	});
});
