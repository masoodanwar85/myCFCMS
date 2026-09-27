/**
 * A page's featured image, and whether it falls back to its ancestors'.
 *
 * ## Not the same thing as `og_image`
 *
 * `og_image` is the picture a social network shows when somebody shares the
 * page — seen on Facebook or LinkedIn, never on the site, and usually a wide
 * 1200x630 card. A featured image is shown *on* the page: a banner, or a
 * thumbnail in a listing. Different purpose, often a different shape, and
 * neither is automatically a good substitute for the other, so they are
 * separate columns.
 *
 * They are related in one direction only: a page with no `og_image` makes a
 * better share card from its own featured image than from the site-wide
 * default, which is the same picture on every page. `SeoService` uses it as a
 * fallback; nothing else about the two fields is shared.
 *
 * ## Why inheritance defaults to on
 *
 * `inherit_featured_image` defaults to 1, and the deliberate consequence is
 * that every existing page immediately inherits. On a tree like Will Creator's
 * — 82 of 100 pages are stubs under a handful of parents — the alternative is
 * opening 82 pages to tick a box for the behaviour almost all of them want.
 * The exceptions get it unticked, and there are usually two or three.
 *
 * The flag only means anything when `featured_image` is empty; a page with its
 * own image ignores it.
 *
 * ## A URL, not a media id
 *
 * Matching `og_image` in this same table, and the branding logo. It keeps Pages
 * from depending on the Media module, and the library's picker already hands
 * back a URL.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `pages`
				ADD COLUMN `featured_image`         VARCHAR(500) NULL     AFTER `template`,
				ADD COLUMN `inherit_featured_image` TINYINT(1)   NOT NULL DEFAULT 1 AFTER `featured_image`
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `pages`
				DROP COLUMN `featured_image`,
				DROP COLUMN `inherit_featured_image`
			",
			{},
			options
		);
	}

}
