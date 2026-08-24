/**
 * Per-page SEO, social, sitemap and scheduling controls.
 *
 * Until now a page carried a meta title and description; everything else about
 * how it presented itself to a crawler was worked out by Core from site-level
 * defaults. That is the right default and a poor ceiling — an editor could not
 * mark one page `noindex`, keep a legal notice out of the sitemap, give a post
 * its own social image, or schedule an announcement for a date.
 *
 * ## Columns on `pages`, not a shared table
 *
 * A generic `content_seo` table keyed by `(content_type, content_id)` would let
 * Blog adopt the same fields without a migration. It is not what this does,
 * because the precedent here already runs the other way: `posts` has its own
 * `meta_title` and `meta_description` columns rather than sharing Pages'. One
 * join per page render, on every page, to avoid a migration nobody has asked
 * for yet is the wrong trade. When Blog wants these, it gets the same columns —
 * and if a third content type follows, that is the moment to generalise.
 *
 * ## Defaults are the behaviour that already existed
 *
 * Every column defaults to what Core was doing before: indexable, followable,
 * in the sitemap at 0.5, `og:type` of `website`. An existing row therefore
 * renders identically after this migration, which is the property that makes it
 * safe to run on a live site.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `pages`
				-- Ignored by every major search engine since around 2009, and
				-- included because a CMS that silently drops a field an author
				-- filled in is worse than one that keeps a harmless one.
				ADD COLUMN `meta_keywords`      VARCHAR(255)  NULL AFTER `meta_description`,
				-- Blank means 'work it out from the primary domain', which is
				-- what SeoService already does.
				ADD COLUMN `canonical_url`      VARCHAR(500)  NULL AFTER `meta_keywords`,
				ADD COLUMN `robots_index`       TINYINT(1)    NOT NULL DEFAULT 1 AFTER `canonical_url`,
				ADD COLUMN `robots_follow`      TINYINT(1)    NOT NULL DEFAULT 1 AFTER `robots_index`,
				ADD COLUMN `og_title`           VARCHAR(255)  NULL AFTER `robots_follow`,
				ADD COLUMN `og_description`     VARCHAR(500)  NULL AFTER `og_title`,
				ADD COLUMN `og_image`           VARCHAR(500)  NULL AFTER `og_description`,
				ADD COLUMN `og_type`            VARCHAR(40)   NOT NULL DEFAULT 'website' AFTER `og_image`,
				ADD COLUMN `twitter_card`       VARCHAR(40)   NOT NULL DEFAULT 'summary_large_image' AFTER `og_type`,
				ADD COLUMN `sitemap_include`    TINYINT(1)    NOT NULL DEFAULT 1 AFTER `twitter_card`,
				ADD COLUMN `sitemap_priority`   DECIMAL(2,1)  NOT NULL DEFAULT 0.5 AFTER `sitemap_include`,
				ADD COLUMN `sitemap_changefreq` VARCHAR(20)   NOT NULL DEFAULT 'weekly' AFTER `sitemap_priority`,
				-- Scheduling. Null at both ends means 'as soon as it is
				-- published, forever', which is what every existing row means.
				ADD COLUMN `publish_from`       DATETIME      NULL AFTER `published_at`,
				ADD COLUMN `publish_until`      DATETIME      NULL AFTER `publish_from`,
				-- Raw markup. Guarded by the `content.unfiltered` permission in
				-- the service, because anything written here is emitted into
				-- every visitor's page without sanitising.
				ADD COLUMN `head_markup`        TEXT          NULL AFTER `publish_until`,
				ADD COLUMN `body_markup`        TEXT          NULL AFTER `head_markup`,
				ADD COLUMN `json_ld`            TEXT          NULL AFTER `body_markup`
			",
			{},
			options
		);

		// The window lookup runs on every public page request, so it gets an
		// index rather than relying on the row count staying small.
		queryExecute(
			"
			ALTER TABLE `pages`
				ADD KEY `idx_pages_schedule` (`site_id`, `status`, `publish_from`, `publish_until`)
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "ALTER TABLE `pages` DROP KEY `idx_pages_schedule`", {}, options );

		queryExecute(
			"
			ALTER TABLE `pages`
				DROP COLUMN `meta_keywords`,
				DROP COLUMN `canonical_url`,
				DROP COLUMN `robots_index`,
				DROP COLUMN `robots_follow`,
				DROP COLUMN `og_title`,
				DROP COLUMN `og_description`,
				DROP COLUMN `og_image`,
				DROP COLUMN `og_type`,
				DROP COLUMN `twitter_card`,
				DROP COLUMN `sitemap_include`,
				DROP COLUMN `sitemap_priority`,
				DROP COLUMN `sitemap_changefreq`,
				DROP COLUMN `publish_from`,
				DROP COLUMN `publish_until`,
				DROP COLUMN `head_markup`,
				DROP COLUMN `body_markup`,
				DROP COLUMN `json_ld`
			",
			{},
			options
		);
	}

}
