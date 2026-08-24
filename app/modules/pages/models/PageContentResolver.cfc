/**
 * Answers Core's routing question on behalf of the Pages module.
 *
 * Core asks "does anything serve this path for this site?" and this replies
 * with a page, or null. That is the entire coupling: Core never imports
 * PageService, and this module never registers a route.
 *
 * It supplies the breadcrumb a post's own view needs. The site's navigation is
 * not its business: that comes from PageNavigationProvider, which Core asks
 * regardless of which module served the URL.
 */
component singleton accessors="true" {

	property name="pageService" inject="PageService@pages";
	property name="shortcodes"  inject="ShortcodeService@core";

	/**
	 * @siteId The resolved tenant.
	 * @path   Normalised request path, no leading or trailing slash.
	 *         An empty path means the site root.
	 *
	 * @return A content resolution struct, or null when no page serves this path.
	 */
	function resolveContent( required numeric siteId, required string path ){
		var isRoot = !len( arguments.path );

		var page = isRoot
			? resolveHomePage( arguments.siteId )
			: pageService.getPublishedPageByPath( arguments.siteId, arguments.path );

		if ( isNull( page ) ) {
			return;
		}

		// The home page answers at `/` *and* at its own path — `/home` serves
		// exactly what `/` serves. Both keep working, because links to either
		// exist in the wild, but only one is offered for indexing. Comparing
		// the resolved page against the site's designated home page catches the
		// `/home` case too, which asking about the requested path alone does not.
		var home     = pageService.getHomePage( arguments.siteId );
		var isHome   = !isNull( home ) && home.getId() == page.getId();

		// An explicit canonical wins over anything derived. It is the field an
		// editor reaches for when this page duplicates something elsewhere —
		// including somewhere off this site — so it has to be able to say so.
		var explicitCanonical = trim( page.getCanonicalUrl() ?: "" );

		// Shortcodes expand on the way out, never on the way in. The stored
		// content keeps `[image id="12"]` as written, so an author can still
		// edit it and the sanitiser has nothing to object to; the theme gets
		// the expansion. Done here rather than in the theme so a third-party
		// theme does not have to know shortcodes exist.
		//
		// The entity is built fresh from a row on every request, so setting the
		// expanded content on it changes nothing in the database.
		page.setContent(
			shortcodes.expand(
				content = page.getContent() ?: "",
				context = { "siteId" : arguments.siteId, "path" : arguments.path }
			)
		);

		return {
			"view"            : "page",
			"args"            : {
				"page"       : page,
				"breadcrumb" : pageService.getBreadcrumb( page.getId() )
			},
			"title"           : page.getEffectiveMetaTitle(),
			"metaDescription" : page.getMetaDescription() ?: "",
			"statusCode"      : 200,
			"canonicalPath"   : len( explicitCanonical ) ? explicitCanonical : ( isHome ? "" : page.getPath() ),
			"modifiedAt"      : page.getUpdatedAt(),
			"publishedAt"     : page.getPublishedAt() ?: "",
			// The page's own answers, where it has given any. An empty string
			// means "no opinion", and SeoService fills it from the site's
			// defaults — so a page nobody has opened the SEO tab on behaves
			// exactly as it did before these fields existed.
			"robots"          : page.getRobotsDirective(),
			"image"           : page.getOgImage() ?: "",
			"contentType"     : page.getOgType() ?: "website",
			"twitterCard"     : page.getTwitterCard() ?: "",
			"keywords"        : page.getMetaKeywords() ?: "",
			"ogTitle"         : page.getOgTitle() ?: "",
			"ogDescription"   : page.getOgDescription() ?: "",
			"headMarkup"      : page.getHeadMarkup() ?: "",
			"bodyMarkup"      : page.getBodyMarkup() ?: "",
			"jsonLd"          : page.getJsonLd() ?: ""
		};
	}

	/**
	 * The site root.
	 *
	 * A site designates its home page through a site setting. Only a published
	 * one is served: a draft home page must not silently become the front door.
	 */
	private function resolveHomePage( required numeric siteId ){
		var home = pageService.getHomePage( arguments.siteId );

		if ( isNull( home ) || !home.isPublished() ) {
			return;
		}

		return home;
	}

}
