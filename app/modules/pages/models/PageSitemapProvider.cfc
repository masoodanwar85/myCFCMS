/**
 * The site's pages, as sitemap entries.
 *
 * Published only. A draft in a sitemap invites a crawler to index a URL that
 * answers 404, which costs the site more than the missing entry would.
 *
 * The home page is ranked above the rest and everything else is left at the
 * default. Priority is a hint about relative importance *within* one site and
 * nothing more — search engines largely ignore it — so this does not try to
 * infer importance from depth or recency, which would be guessing dressed up as
 * data.
 */
component singleton accessors="true" {

	property name="pageRepository"   inject="PageRepository@pages";
	property name="siteSettingsRepo" inject="SiteSettingsRepository@core";
	property name="settings"         inject="coldbox:moduleSettings:pages";

	array function getSitemapEntries( required numeric siteId ){
		var homeId  = val( siteSettingsRepo.getValue( arguments.siteId, settings.homePageSettingKey ?: "pages.homePageId", "" ) );
		var entries = [];

		for ( var page in pageRepository.findPublishedBySiteId( arguments.siteId ) ) {
			// An editor can keep a page out — a thank-you page, a legal notice,
			// anything that is public but not worth a crawler's budget.
			if ( !page.getSitemapInclude() ) {
				continue;
			}

			// A page marked `noindex` must not be advertised in the sitemap
			// either. Doing both is contradictory, and the contradiction is the
			// sort a crawler resolves in whichever direction it likes.
			if ( !page.getRobotsIndex() ) {
				continue;
			}

			var isHome = homeId && page.getId() == homeId;

			entries.append( {
				// The home page is published at `/`, not at its own path, so
				// listing both would offer a crawler two URLs for one document.
				"path"            : isHome ? "" : page.getPath(),
				"lastModified"    : page.getUpdatedAt(),
				"changeFrequency" : page.getSitemapChangefreq(),
				// The home page keeps its implicit top ranking unless an editor
				// has actually moved it.
				"priority"        : isHome && page.getSitemapPriority() == 0.5
					? 1.0
					: page.getSitemapPriority()
			} );
		}

		return entries;
	}

}
