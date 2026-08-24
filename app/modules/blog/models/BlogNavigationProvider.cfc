/**
 * Contributes a single "Blog" entry to a site's public navigation.
 *
 * Only when the site actually has something published: an empty archive in the
 * menu is a dead end for a reader.
 *
 * There is no menu management yet — Menus remains a postponed Core area — so a
 * module contributing its own landing link is how a blog becomes findable at
 * all. When menu editing arrives, this becomes a default an editor can remove.
 */
component singleton accessors="true" {

	property name="blogService" inject="BlogService@blog";
	property name="settings"    inject="coldbox:moduleSettings:blog";

	array function getNavigationItems( required numeric siteId ){
		if ( !blogService.countPublishedPosts( arguments.siteId ) ) {
			return [];
		}

		var base = reReplace( lCase( trim( settings.basePath ?: "blog" ) ), "^/+|/+$", "", "all" );

		return [
			{
				"label" : settings.archiveTitle ?: "Blog",
				"href"  : "/" & base,
				// After the site's own pages, which use an editor-set order
				// starting at zero.
				"order" : val( settings.navigationOrder ?: 500 )
			}
		];
	}

}
