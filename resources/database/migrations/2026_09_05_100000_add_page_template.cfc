/**
 * Which theme template a page renders through.
 *
 * Every page has rendered through the theme's one `page` view, which is right
 * for a page of prose and useless for a page that needs logic — a fee
 * calculator, a directory, anything assembled at request time. The only ways
 * out were a shortcode, which suits a fragment rather than a whole page, or a
 * module with its own routes, which is a lot of machinery for one page.
 *
 * ## Why a name and not the code
 *
 * The obvious alternative is a column holding CFML that the CMS executes. That
 * would be arbitrary code execution for anyone with `pages.update`: the code
 * runs as the ColdFusion user, with the application's datasource, so an editor
 * on one client's site could read the credentials and with them every other
 * client's data. `content.unfiltered` gates raw HTML because HTML runs in the
 * visitor's browser; CFML would run on the server, inside the boundary the
 * permissions exist to protect rather than behind it.
 *
 * A template *name* costs nothing. The code lives in the theme, deployed by
 * whoever deploys code, and the author chooses from what is installed. Theme
 * files already execute on every request, so this adds no new surface at all.
 *
 * NULL means the theme's ordinary `page` view, which is what every existing row
 * means.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `pages`
				ADD COLUMN `template` VARCHAR(100) NULL AFTER `show_heading`
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "ALTER TABLE `pages` DROP COLUMN `template`", {}, options );
	}

}
