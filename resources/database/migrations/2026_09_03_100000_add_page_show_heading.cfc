/**
 * Whether a page renders its own title as a heading.
 *
 * The theme has always emitted `<h1>#page.getTitle()#</h1>` above the content,
 * which is right for most pages and wrong for the ones that carry their own
 * headline: a landing page whose first element is a hero, or a page whose body
 * opens with its own styled title. Those ended up with the heading twice, and
 * the only fix was to name the page something blank-looking.
 *
 * A page's title is not only its heading — it is the browser tab, the menu
 * label, the breadcrumb and the `<title>` tag. So this is a *display* switch,
 * not a way to have a page without a title, and nothing else changes when it is
 * off.
 *
 * ## Default 1
 *
 * Every existing row keeps rendering its heading, so this migration changes
 * nothing on a live site until somebody turns it off. Same property the SEO
 * migration was built around, for the same reason.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `pages`
				ADD COLUMN `show_heading` TINYINT(1) NOT NULL DEFAULT 1 AFTER `content`
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "ALTER TABLE `pages` DROP COLUMN `show_heading`", {}, options );
	}

}
