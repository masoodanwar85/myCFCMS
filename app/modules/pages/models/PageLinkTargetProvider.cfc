/**
 * Lets a menu item point at a page.
 *
 * The item stores `pages.page` and a row id, never a URL, so renaming a page
 * moves every menu that links to it instead of leaving a stale address behind
 * for RedirectService to catch.
 *
 * Only published pages are offered. A menu is public, and putting a draft in it
 * either exposes work in progress or links visitors to a 404.
 */
component singleton accessors="true" {

	property name="pageRepository"   inject="PageRepository@pages";
	property name="siteSettingsRepo" inject="SiteSettingsRepository@core";
	property name="settings"         inject="coldbox:moduleSettings:pages";

	this.TYPE = "pages.page";

	array function getLinkTargets( required numeric siteId ){
		// A plain loop rather than `.map()`. Inside a closure, `arguments`
		// is the closure's own — so `arguments.siteId` there is not this
		// function's site id, it is undefined, and the whole provider fails
		// with the registry quietly logging a warning and showing no pages.
		var targets = [];
		var homeId  = homePageId( arguments.siteId );

		for ( var page in pageRepository.findPublishedBySiteId( arguments.siteId ) ) {
			var depth = listLen( page.getPath(), "/" ) - 1;

			targets.append( {
				"type"  : this.TYPE,
				"id"    : page.getId(),
				// Indented by depth so the picker reads as a tree rather than
				// an alphabetical list of unrelated titles.
				"label" : ( depth > 0 ? repeatString( "— ", depth ) : "" ) & page.getTitle(),
				"path"  : homeId && page.getId() == homeId ? "" : page.getPath(),
				"group" : "Pages"
			} );
		}

		return targets;
	}

	function resolveLinkTarget( required numeric siteId, required string type, required numeric id ){
		if ( arguments.type != this.TYPE ) {
			return;
		}

		var page   = pageRepository.findById( arguments.id );
		var homeId = homePageId( arguments.siteId );

		// Deleted, moved to another site, or unpublished since the menu item
		// was created. All three mean the same thing to a menu: do not link.
		if ( isNull( page ) || page.getSiteId() != arguments.siteId || !page.isPublished() ) {
			return;
		}

		return {
			"label" : page.getTitle(),
			"path"  : homeId && page.getId() == homeId ? "" : page.getPath()
		};
	}

	/**
	 * Which page the site serves at `/`, or 0.
	 *
	 * A menu item pointing at the home page should link there rather than to
	 * its own path — the same address the canonical tag names, so a menu and a
	 * canonical never disagree about where the front page is.
	 */
	private numeric function homePageId( required numeric siteId ){
		return val(
			siteSettingsRepo.getValue( arguments.siteId, settings.homePageSettingKey ?: "pages.homePageId", "" )
		);
	}

}
