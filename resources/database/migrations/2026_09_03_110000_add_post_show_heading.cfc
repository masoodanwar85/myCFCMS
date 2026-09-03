/**
 * Whether a post renders its own title as a heading.
 *
 * The same switch `pages` gained in the previous migration, for the same
 * reason: a post whose content opens with its own headline had that headline
 * printed twice, once by the theme and once by the author.
 *
 * ## Its own column, not a shared table
 *
 * Following the precedent the SEO migration set out: `blog_posts` already keeps
 * its own `meta_title` and `meta_description` rather than sharing Pages'. A
 * join on every post render to avoid one `ALTER TABLE` is the wrong trade. If a
 * third content type wants this, that is the moment to generalise.
 *
 * ## Default 1
 *
 * Every existing post keeps rendering its heading, so this changes nothing on a
 * live site until somebody turns it off.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `blog_posts`
				ADD COLUMN `show_heading` TINYINT(1) NOT NULL DEFAULT 1 AFTER `content`
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "ALTER TABLE `blog_posts` DROP COLUMN `show_heading`", {}, options );
	}

}
