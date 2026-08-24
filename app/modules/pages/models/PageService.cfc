/**
 * Page use cases.
 *
 * Owns three things the repository deliberately does not: the tree's integrity
 * (no page may become its own ancestor), the materialised `path` and keeping it
 * true for a whole subtree after a rename or move, and the publishing states.
 *
 * Renders nothing and knows no HTTP, so the same calls will back an admin
 * screen, a REST endpoint and a GraphQL mutation.
 */
component singleton accessors="true" {

	property name="pageRepository"   inject="PageRepository@pages";
	property name="slugifier"        inject="Slugifier@core";
	property name="siteRepository"   inject="SiteRepository@core";
	property name="userRepository"   inject="UserRepository@core";
	property name="siteSettingsRepo" inject="SiteSettingsRepository@core";
	property name="settings"         inject="coldbox:moduleSettings:pages";
	property name="interceptorService" inject="coldbox:interceptorService";
	property name="sanitizer"        inject="ContentSanitizer@core";
	property name="redirects"        inject="RedirectService@core";
	property name="wirebox"          inject="wirebox";

	/* ---------------------------------------------------------------------
	 * Writing
	 * ------------------------------------------------------------------ */

	/**
	 * Create a page.
	 *
	 * @siteId   The owning site.
	 * @title    Human-readable title.
	 * @slug     URL segment. Derived from the title when omitted.
	 * @parentId Omit for a top-level page.
	 * @authorId Recorded as creator; must belong to the site, or be a super admin.
	 * @allowUnfilteredHtml Skip HTML sanitising. The caller is responsible for
	 *                      checking the author holds `content.unfiltered`.
	 *
	 * @throws Pages.SiteNotFound
	 * @throws Pages.InvalidPage
	 * @throws Pages.ParentNotFound
	 * @throws Pages.CrossTenantParent
	 * @throws Pages.InvalidAuthor
	 * @throws Pages.PathAlreadyExists
	 */
	pages.models.Page function createPage(
		required numeric siteId,
		required string title,
		string slug            = "",
		numeric parentId,
		string content         = "",
		string status          = "draft",
		string metaTitle       = "",
		string metaDescription = "",
		numeric sortOrder      = 0,
		numeric authorId,
		boolean allowUnfilteredHtml = false,
		struct seo = {}
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Pages.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var pageTitle = trim( arguments.title );

		if ( !len( pageTitle ) ) {
			throw( type = "Pages.InvalidPage", message = "A page requires a title." );
		}

		if ( !isValidStatus( arguments.status ) ) {
			throw(
				type    = "Pages.InvalidPage",
				message = "Unknown page status [#arguments.status#]. Expected `draft`, `published` or `archived`."
			);
		}

		var pageSlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( pageTitle );

		if ( !len( pageSlug ) ) {
			throw(
				type    = "Pages.InvalidPage",
				message = "Could not derive a usable slug from [#pageTitle#]. Provide one explicitly."
			);
		}

		var parent = javacast( "null", "" );

		if ( !isNull( arguments.parentId ) ) {
			parent = requireParentForSite( arguments.siteId, arguments.parentId );
		}

		var path = buildPath( isNull( parent ) ? "" : parent.getPath(), pageSlug );

		if ( pageRepository.existsByPath( arguments.siteId, path ) ) {
			throw(
				type    = "Pages.PathAlreadyExists",
				message = "This site already has a page at [#path#]."
			);
		}

		if ( !isNull( arguments.authorId ) ) {
			requireAuthorForSite( arguments.authorId, arguments.siteId );
		}

		var page = wirebox
			.getInstance( "Page@pages" )
			.setSiteId( arguments.siteId )
			.setTitle( pageTitle )
			.setSlug( pageSlug )
			.setPath( path )
			.setStatus( arguments.status )
			.setContent( sanitizer.sanitize( arguments.content, arguments.allowUnfilteredHtml ) )
			.setMetaTitle( trim( arguments.metaTitle ) )
			.setMetaDescription( trim( arguments.metaDescription ) )
			.setSortOrder( arguments.sortOrder );

		if ( !isNull( parent ) ) {
			page.setParentId( parent.getId() );
		}

		if ( !isNull( arguments.authorId ) ) {
			page.setCreatedBy( arguments.authorId );
			page.setUpdatedBy( arguments.authorId );
		}

		applySeo( page, arguments.seo, arguments.allowUnfilteredHtml );

		// A page created straight into `published` still needs its date.
		if ( page.isPublished() ) {
			page.setPublishedAt( now() );
		}

		var created = pageRepository.create( page );

		interceptorService.announce( "onPageCreated", { page : created } );

		return created;
	}

	/**
	 * Edit a page.
	 *
	 * Changing the slug moves the page's URL and every URL beneath it, so the
	 * subtree's paths are rewritten in the same call.
	 *
	 * @throws Pages.PageNotFound
	 * @throws Pages.InvalidPage
	 * @throws Pages.PathAlreadyExists
	 */
	pages.models.Page function updatePage(
		required numeric pageId,
		string title,
		string slug,
		string content,
		string metaTitle,
		string metaDescription,
		numeric sortOrder,
		numeric editorId,
		boolean allowUnfilteredHtml = false,
		/**
		 * The optional SEO, social, sitemap and scheduling fields, as a struct.
		 *
		 * A struct rather than seventeen more named arguments: the signature
		 * would otherwise be unreadable, and every caller that only wanted to
		 * change a title would have to scroll past them. Only the keys present
		 * are applied, so a partial update stays partial.
		 */
		struct seo = {}
	){
		var page    = requirePage( arguments.pageId );
		var oldPath = page.getPath();

		if ( !isNull( arguments.title ) ) {
			if ( !len( trim( arguments.title ) ) ) {
				throw( type = "Pages.InvalidPage", message = "A page requires a title." );
			}
			page.setTitle( trim( arguments.title ) );
		}

		if ( !isNull( arguments.slug ) ) {
			var newSlug = slugify( arguments.slug );

			if ( !len( newSlug ) ) {
				throw( type = "Pages.InvalidPage", message = "[#arguments.slug#] is not a usable slug." );
			}

			page.setSlug( newSlug );
			page.setPath( buildPath( parentPathOf( page ), newSlug ) );
		}

		if ( !isNull( arguments.content ) ) {
			page.setContent( sanitizer.sanitize( arguments.content, arguments.allowUnfilteredHtml ) );
		}
		if ( !isNull( arguments.metaTitle ) ) {
			page.setMetaTitle( trim( arguments.metaTitle ) );
		}
		if ( !isNull( arguments.metaDescription ) ) {
			page.setMetaDescription( trim( arguments.metaDescription ) );
		}
		if ( !isNull( arguments.sortOrder ) ) {
			page.setSortOrder( arguments.sortOrder );
		}
		if ( !isNull( arguments.editorId ) ) {
			requireAuthorForSite( arguments.editorId, page.getSiteId() );
			page.setUpdatedBy( arguments.editorId );
		}

		applySeo( page, arguments.seo, arguments.allowUnfilteredHtml );

		var moved = page.getPath() != oldPath;

		if ( moved && pageRepository.existsByPath( page.getSiteId(), page.getPath() ) ) {
			throw(
				type    = "Pages.PathAlreadyExists",
				message = "This site already has a page at [#page.getPath()#]."
			);
		}

		// Captured before the rewrite, while the old paths still exist.
		var subtree = moved ? pageRepository.findDescendants( page.getSiteId(), oldPath ) : [];

		var updated = pageRepository.update( page );

		if ( moved ) {
			pageRepository.rewriteDescendantPaths( page.getSiteId(), oldPath, page.getPath() );
			rememberMove( page.getSiteId(), oldPath, page.getPath(), subtree );
		}

		interceptorService.announce( "onPageUpdated", { page : updated, pathChanged : moved } );

		return updated;
	}

	/**
	 * Move a page to a new parent, or to the top level.
	 *
	 * @newParentId Omit to move the page to the top level.
	 *
	 * @throws Pages.PageNotFound
	 * @throws Pages.ParentNotFound
	 * @throws Pages.CrossTenantParent
	 * @throws Pages.CircularHierarchy
	 * @throws Pages.PathAlreadyExists
	 */
	pages.models.Page function movePage( required numeric pageId, numeric newParentId ){
		var page    = requirePage( arguments.pageId );
		var oldPath = page.getPath();
		var parent  = javacast( "null", "" );

		if ( !isNull( arguments.newParentId ) ) {
			parent = requireParentForSite( page.getSiteId(), arguments.newParentId );
		}

		if ( !isNull( parent ) ) {
			// A page cannot be moved beneath itself or beneath its own
			// descendant; either would detach the subtree from the tree and
			// leave a cycle no query could terminate on. The materialised path
			// makes this an O(1) check instead of a walk.
			if ( parent.getId() == page.getId() || isDescendantPath( parent.getPath(), oldPath ) ) {
				throw(
					type    = "Pages.CircularHierarchy",
					message = "A page cannot be moved beneath itself or one of its own descendants."
				);
			}

			page.setParentId( parent.getId() );
		} else {
			page.clearParent();
		}

		page.setPath( buildPath( isNull( parent ) ? "" : parent.getPath(), page.getSlug() ) );

		if ( page.getPath() != oldPath && pageRepository.existsByPath( page.getSiteId(), page.getPath() ) ) {
			throw(
				type    = "Pages.PathAlreadyExists",
				message = "This site already has a page at [#page.getPath()#]."
			);
		}

		var pathChanged = page.getPath() != oldPath;
		var subtree     = pathChanged ? pageRepository.findDescendants( page.getSiteId(), oldPath ) : [];

		var updated = pageRepository.update( page );

		if ( pathChanged ) {
			pageRepository.rewriteDescendantPaths( page.getSiteId(), oldPath, page.getPath() );
			rememberMove( page.getSiteId(), oldPath, page.getPath(), subtree );
		}

		interceptorService.announce( "onPageUpdated", { page : updated, pathChanged : pathChanged } );

		return updated;
	}

	/* ---------------------------------------------------------------------
	 * Publishing
	 * ------------------------------------------------------------------ */

	/**
	 * Make a page live.
	 *
	 * `published_at` is set the first time only, so re-publishing after a
	 * correction does not rewrite the original publication date.
	 */
	pages.models.Page function publishPage( required numeric pageId, numeric editorId ){
		var page = requirePage( arguments.pageId );

		page.setStatus( page.STATUS_PUBLISHED );

		if ( isNull( page.getPublishedAt() ) ) {
			page.setPublishedAt( now() );
		}

		if ( !isNull( arguments.editorId ) ) {
			requireAuthorForSite( arguments.editorId, page.getSiteId() );
			page.setUpdatedBy( arguments.editorId );
		}

		var updated = pageRepository.update( page );

		interceptorService.announce( "onPagePublished", { page : updated } );

		return updated;
	}

	/**
	 * Take a page off the public site, back to draft.
	 */
	pages.models.Page function unpublishPage( required numeric pageId, numeric editorId ){
		var page = requirePage( arguments.pageId );

		page.setStatus( page.STATUS_DRAFT );

		if ( !isNull( arguments.editorId ) ) {
			requireAuthorForSite( arguments.editorId, page.getSiteId() );
			page.setUpdatedBy( arguments.editorId );
		}

		var updated = pageRepository.update( page );

		interceptorService.announce( "onPageUnpublished", { page : updated } );

		return updated;
	}

	/**
	 * Retire a page without deleting it.
	 */
	pages.models.Page function archivePage( required numeric pageId, numeric editorId ){
		var page = requirePage( arguments.pageId );

		page.setStatus( page.STATUS_ARCHIVED );

		if ( !isNull( arguments.editorId ) ) {
			requireAuthorForSite( arguments.editorId, page.getSiteId() );
			page.setUpdatedBy( arguments.editorId );
		}

		return pageRepository.update( page );
	}

	/* ---------------------------------------------------------------------
	 * Deleting
	 * ------------------------------------------------------------------ */

	/**
	 * Delete a page.
	 *
	 * The database cascades to descendants, so the tree can never be orphaned.
	 * Because that is destructive and easy to trigger by accident, deleting a
	 * page that has children is refused unless the caller says so outright.
	 *
	 * @includeDescendants Delete the whole subtree.
	 *
	 * @throws Pages.PageNotFound
	 * @throws Pages.PageHasChildren
	 */
	function deletePage( required numeric pageId, boolean includeDescendants = false ){
		var page = requirePage( arguments.pageId );

		if ( !arguments.includeDescendants && pageRepository.hasChildren( arguments.pageId ) ) {
			throw(
				type    = "Pages.PageHasChildren",
				message = "Page [#arguments.pageId#] has child pages.",
				detail  = "Pass includeDescendants=true to delete the subtree, or move the children first."
			);
		}

		clearHomePageIfMatches( page );

		pageRepository.delete( arguments.pageId );

		interceptorService.announce( "onPageDeleted", { pageId : arguments.pageId, siteId : page.getSiteId() } );

		return this;
	}

	/* ---------------------------------------------------------------------
	 * Reading
	 * ------------------------------------------------------------------ */

	function getPageById( required numeric pageId ){
		return pageRepository.findById( arguments.pageId );
	}

	/**
	 * Resolve a URL path within a site. Includes drafts — this is the editor's
	 * view. A front end should use `getPublishedPageByPath`.
	 */
	function getPageByPath( required numeric siteId, required string path ){
		return pageRepository.findByPath( arguments.siteId, normalizePath( arguments.path ) );
	}

	/**
	 * Resolve a URL path to a page the public may see.
	 */
	function getPublishedPageByPath( required numeric siteId, required string path ){
		return pageRepository.findPublishedByPath( arguments.siteId, normalizePath( arguments.path ) );
	}

	array function getPagesForSite( required numeric siteId ){
		return pageRepository.findBySiteId( arguments.siteId );
	}

	array function getPublishedPagesForSite( required numeric siteId ){
		return pageRepository.findPublishedBySiteId( arguments.siteId );
	}

	array function getRootPages( required numeric siteId ){
		return pageRepository.findRootPages( arguments.siteId );
	}

	array function getChildren( required numeric pageId ){
		return pageRepository.findChildren( arguments.pageId );
	}

	array function getDescendants( required numeric pageId ){
		var page = requirePage( arguments.pageId );
		return pageRepository.findDescendants( page.getSiteId(), page.getPath() );
	}

	/**
	 * The page's ancestors, outermost first, followed by the page itself.
	 *
	 * Derived from the materialised path, so this is one query for the whole
	 * trail rather than one per level.
	 */
	array function getBreadcrumb( required numeric pageId ){
		var page = requirePage( arguments.pageId );
		var trail = [];
		var accumulated = "";

		for ( var segment in listToArray( page.getPath(), "/" ) ) {
			accumulated = len( accumulated ) ? accumulated & "/" & segment : segment;

			var ancestor = pageRepository.findByPath( page.getSiteId(), accumulated );

			if ( !isNull( ancestor ) ) {
				trail.append( ancestor );
			}
		}

		return trail;
	}

	/**
	 * A site's pages as a nested tree.
	 *
	 * Reads every page once and assembles the structure in memory, rather than
	 * issuing a query per level.
	 *
	 * @return An array of `{ page, children : [...] }` structs, in menu order.
	 */
	array function getTree( required numeric siteId ){
		var allPages = pageRepository.findBySiteId( arguments.siteId );
		var nodes    = {};
		var roots    = [];

		for ( var page in allPages ) {
			nodes[ page.getId() ] = { "page" : page, "children" : [] };
		}

		for ( var page in allPages ) {
			if ( page.isRoot() || !nodes.keyExists( page.getParentId() ) ) {
				roots.append( nodes[ page.getId() ] );
			} else {
				nodes[ page.getParentId() ].children.append( nodes[ page.getId() ] );
			}
		}

		sortNodes( roots );

		return roots;
	}

	/* ---------------------------------------------------------------------
	 * Ordering
	 * ------------------------------------------------------------------ */

	/**
	 * Set the order of a set of sibling pages.
	 *
	 * @orderedPageIds Page ids in the order they should appear.
	 */
	function reorderPages( required array orderedPageIds ){
		var position = 0;

		for ( var pageId in arguments.orderedPageIds ) {
			pageRepository.updateSortOrder( pageId, position );
			position++;
		}

		return this;
	}

	/* ---------------------------------------------------------------------
	 * Home page
	 * ------------------------------------------------------------------ */

	/**
	 * Record which page a site serves at its root.
	 *
	 * Stored as a site setting rather than a column, so Core needs no knowledge
	 * of pages and a site without this module simply has no such setting.
	 *
	 * @throws Pages.PageNotFound
	 * @throws Pages.CrossTenantPage
	 */
	function setHomePage( required numeric siteId, required numeric pageId ){
		var page = requirePage( arguments.pageId );

		if ( page.getSiteId() != arguments.siteId ) {
			throw(
				type    = "Pages.CrossTenantPage",
				message = "Page [#arguments.pageId#] does not belong to site [#arguments.siteId#]."
			);
		}

		siteSettingsRepo.put( arguments.siteId, homePageSettingKey(), arguments.pageId );

		return this;
	}

	/**
	 * @return The site's home Page, or null when none is set or it has gone.
	 */
	function getHomePage( required numeric siteId ){
		var pageId = siteSettingsRepo.getValue( arguments.siteId, homePageSettingKey(), "" );

		if ( !len( pageId ) || !isNumeric( pageId ) ) {
			return;
		}

		var page = pageRepository.findById( val( pageId ) );

		// The setting can outlive the page it names.
		if ( isNull( page ) || page.getSiteId() != arguments.siteId ) {
			return;
		}

		return page;
	}

	/* ---------------------------------------------------------------------
	 * SEO, social, sitemap and scheduling
	 * ------------------------------------------------------------------ */

	// Closed lists. A value outside them is dropped rather than stored, so
	// nothing an author types can become an arbitrary attribute in the markup.
	variables.OG_TYPES      = "website,article,profile,book,video.other,music.song";
	variables.TWITTER_CARDS = "summary,summary_large_image,app,player";
	variables.CHANGEFREQS   = "always,hourly,daily,weekly,monthly,yearly,never";

	/**
	 * Apply the optional SEO fields to a page.
	 *
	 * Every field is skipped when absent, so this serves both `createPage` and
	 * a partial `updatePage` without either having to enumerate them.
	 *
	 * @allowRawMarkup Whether the caller's user holds `content.unfiltered`.
	 *                 See `applyRawMarkup` for why that gate exists.
	 */
	private function applySeo(
		required any page,
		required struct values,
		boolean allowRawMarkup = false
	){
		var given = arguments.values;

		if ( structKeyExists( given, "metaKeywords" ) ) {
			arguments.page.setMetaKeywords( trim( given.metaKeywords ) );
		}

		if ( structKeyExists( given, "canonicalUrl" ) ) {
			arguments.page.setCanonicalUrl( safeUrl( given.canonicalUrl, "canonical URL" ) );
		}

		// `structKeyExists`, not truthiness: `false` is the whole point of
		// these two, and the elvis-style shortcut would make them unsettable.
		if ( structKeyExists( given, "robotsIndex" ) ) {
			arguments.page.setRobotsIndex( asBoolean( given.robotsIndex ) );
		}
		if ( structKeyExists( given, "robotsFollow" ) ) {
			arguments.page.setRobotsFollow( asBoolean( given.robotsFollow ) );
		}

		if ( structKeyExists( given, "ogTitle" ) ) {
			arguments.page.setOgTitle( trim( given.ogTitle ) );
		}
		if ( structKeyExists( given, "ogDescription" ) ) {
			arguments.page.setOgDescription( trim( given.ogDescription ) );
		}
		if ( structKeyExists( given, "ogImage" ) ) {
			arguments.page.setOgImage( safeUrl( given.ogImage, "OG image URL" ) );
		}
		if ( structKeyExists( given, "ogType" ) ) {
			arguments.page.setOgType( fromList( given.ogType, variables.OG_TYPES, "website" ) );
		}
		if ( structKeyExists( given, "twitterCard" ) ) {
			arguments.page.setTwitterCard( fromList( given.twitterCard, variables.TWITTER_CARDS, "summary_large_image" ) );
		}

		if ( structKeyExists( given, "sitemapInclude" ) ) {
			arguments.page.setSitemapInclude( asBoolean( given.sitemapInclude ) );
		}
		if ( structKeyExists( given, "sitemapPriority" ) ) {
			// Clamped rather than rejected: a priority is a hint, and refusing
			// to save a whole page over one out-of-range number is worse than
			// storing the nearest legal value.
			arguments.page.setSitemapPriority( max( 0, min( 1, val( given.sitemapPriority ) ) ) );
		}
		if ( structKeyExists( given, "sitemapChangefreq" ) ) {
			arguments.page.setSitemapChangefreq( fromList( given.sitemapChangefreq, variables.CHANGEFREQS, "weekly" ) );
		}

		applySchedule( arguments.page, given );
		applyRawMarkup( arguments.page, given, arguments.allowRawMarkup );

		return arguments.page;
	}

	private function applySchedule( required any page, required struct given ){
		if ( structKeyExists( arguments.given, "publishFrom" ) ) {
			setOrClear( arguments.page, "publishFrom", arguments.given.publishFrom );
		}
		if ( structKeyExists( arguments.given, "publishUntil" ) ) {
			setOrClear( arguments.page, "publishUntil", arguments.given.publishUntil );
		}

		var from  = arguments.page.getPublishFrom();
		var until = arguments.page.getPublishUntil();

		// A window that closes before it opens can never serve the page, and is
		// far more likely a slip than an intention.
		if ( !isNull( from ) && !isNull( until ) && dateCompare( from, until ) > 0 ) {
			throw(
				type    = "Pages.InvalidSchedule",
				message = "A page cannot stop being published before it starts."
			);
		}

		return arguments.page;
	}

	/**
	 * `head_markup`, `body_markup` and `json_ld`.
	 *
	 * These are emitted into every visitor's page **without sanitising** —
	 * that is what they are for, and it makes them the most dangerous fields in
	 * the CMS. Anyone who could write them could put a script on a client's
	 * site, so they are gated by the same `content.unfiltered` permission that
	 * guards raw HTML in page content.
	 *
	 * A caller without it does not get an error, because that would leak which
	 * fields exist to someone who cannot use them. The values are simply
	 * ignored, and the admin does not render the inputs at all.
	 */
	private function applyRawMarkup( required any page, required struct given, required boolean allowed ){
		if ( !arguments.allowed ) {
			return arguments.page;
		}

		if ( structKeyExists( arguments.given, "headMarkup" ) ) {
			arguments.page.setHeadMarkup( trim( arguments.given.headMarkup ) );
		}
		if ( structKeyExists( arguments.given, "bodyMarkup" ) ) {
			arguments.page.setBodyMarkup( trim( arguments.given.bodyMarkup ) );
		}

		if ( structKeyExists( arguments.given, "jsonLd" ) ) {
			var block = trim( arguments.given.jsonLd );

			// Validated on the way in. Invalid JSON-LD is silently discarded by
			// every consumer, so an author would get no feedback at all — and a
			// broken block would sit in the page indefinitely.
			if ( len( block ) && !isJSON( block ) ) {
				throw(
					type    = "Pages.InvalidPage",
					message = "The JSON-LD block is not valid JSON."
				);
			}

			arguments.page.setJsonLd( block );
		}

		return arguments.page;
	}

	/**
	 * A URL safe to put in an `href` or a `content` attribute.
	 *
	 * Absolute http(s) or site-relative only. `javascript:` in a canonical tag
	 * is not executable, but `data:` and friends in an `og:image` reach places
	 * this code cannot see, and an allow-list is the only durable answer.
	 *
	 * @throws Pages.InvalidPage
	 */
	private string function safeUrl( required string value, required string label ){
		var address = trim( arguments.value );

		if ( !len( address ) ) {
			return "";
		}

		if ( !reFindNoCase( "^(https?://|/)", address ) ) {
			throw(
				type    = "Pages.InvalidPage",
				message = "The #arguments.label# must start with http://, https:// or /."
			);
		}

		return address;
	}

	private string function fromList( required string value, required string allowed, required string fallback ){
		var candidate = lCase( trim( arguments.value ) );

		return listFindNoCase( arguments.allowed, candidate ) ? candidate : arguments.fallback;
	}

	private boolean function asBoolean( required any value ){
		if ( isBoolean( arguments.value ) ) {
			return arguments.value;
		}

		// What an unchecked HTML checkbox posts, versus what a checked one does.
		return listFindNoCase( "on,yes,1,true", trim( arguments.value ) ) > 0;
	}

	/**
	 * Set a date property, or clear it when the value is blank.
	 *
	 * Clearing matters: an editor removing a schedule must actually remove it,
	 * and a generated setter given an empty string would store one rather than
	 * a null.
	 */
	private function setOrClear( required any page, required string property, required any value ){
		var raw = isSimpleValue( arguments.value ) ? trim( arguments.value ) : arguments.value;

		if ( isSimpleValue( raw ) && !len( raw ) ) {
			// Through the entity, because a generated accessor reads from the
			// component's own `variables` scope — which nothing outside it can
			// reach.
			arguments.page.clearDate( arguments.property );
			return arguments.page;
		}

		if ( !isDate( raw ) ) {
			throw( type = "Pages.InvalidPage", message = "[#arguments.property#] is not a date." );
		}

		invoke( arguments.page, "set" & arguments.property, [ parseDateTime( raw ) ] );

		return arguments.page;
	}

	/* ---------------------------------------------------------------------
	 * Helpers
	 * ------------------------------------------------------------------ */

	boolean function isValidStatus( required string status ){
		return [ "draft", "published", "archived" ].findNoCase( arguments.status ) > 0;
	}

	string function slugify( required string value ){
		// Delegated: five copies of this each dropped accented
		// characters instead of transliterating them.
		return slugifier.slugify( arguments.value );
	}

	/**
	 * Paths are stored without leading or trailing slashes, so "/about/team/",
	 * "about/team" and "/about/team" all resolve to the same page.
	 */
	string function normalizePath( required string path ){
		return reReplace( lCase( trim( arguments.path ) ), "^/+|/+$", "", "all" );
	}

	private string function buildPath( required string parentPath, required string slug ){
		return len( arguments.parentPath ) ? arguments.parentPath & "/" & arguments.slug : arguments.slug;
	}

	private string function parentPathOf( required pages.models.Page page ){
		if ( arguments.page.isRoot() ) {
			return "";
		}

		var parent = pageRepository.findById( arguments.page.getParentId() );

		return isNull( parent ) ? "" : parent.getPath();
	}

	/**
	 * Remember the old URLs of a page and everything that moved with it.
	 *
	 * A descendant's new path is its old one with the parent's prefix swapped,
	 * which is exactly what the database rewrite did, so the two cannot drift.
	 *
	 * @subtree Descendants as they were *before* the rewrite.
	 */
	private function rememberMove(
		required numeric siteId,
		required string oldPath,
		required string newPath,
		required array subtree
	){
		var moves = [ { "from" : arguments.oldPath, "to" : arguments.newPath } ];

		for ( var descendant in arguments.subtree ) {
			var was = descendant.getPath();

			moves.append( {
				"from" : was,
				"to"   : arguments.newPath & mid( was, len( arguments.oldPath ) + 1, len( was ) )
			} );
		}

		redirects.recordAll( arguments.siteId, moves );

		return this;
	}

	/**
	 * Is `candidatePath` at or beneath `ancestorPath`?
	 */
	private boolean function isDescendantPath( required string candidatePath, required string ancestorPath ){
		return arguments.candidatePath == arguments.ancestorPath
			|| left( arguments.candidatePath, len( arguments.ancestorPath ) + 1 ) == arguments.ancestorPath & "/";
	}

	private function requirePage( required numeric pageId ){
		var page = pageRepository.findById( arguments.pageId );

		if ( isNull( page ) ) {
			throw( type = "Pages.PageNotFound", message = "No page with id [#arguments.pageId#]." );
		}

		return page;
	}

	/**
	 * @return The parent Page. Callers skip this entirely for a top-level page.
	 */
	private function requireParentForSite( required numeric siteId, required numeric parentId ){
		var parent = pageRepository.findById( arguments.parentId );

		if ( isNull( parent ) ) {
			throw( type = "Pages.ParentNotFound", message = "No page with id [#arguments.parentId#]." );
		}

		if ( parent.getSiteId() != arguments.siteId ) {
			throw(
				type    = "Pages.CrossTenantParent",
				message = "Page [#arguments.parentId#] belongs to another site.",
				detail  = "A page's parent must belong to the same site."
			);
		}

		return parent;
	}

	/**
	 * An author must belong to the site, or be a platform super admin.
	 */
	private function requireAuthorForSite( required numeric userId, required numeric siteId ){
		var user = userRepository.findById( arguments.userId );

		if ( isNull( user ) ) {
			throw( type = "Pages.InvalidAuthor", message = "No user with id [#arguments.userId#]." );
		}

		if ( !user.belongsToSite( arguments.siteId ) ) {
			throw(
				type    = "Pages.InvalidAuthor",
				message = "User [#arguments.userId#] does not belong to site [#arguments.siteId#]."
			);
		}

		return user;
	}

	private string function homePageSettingKey(){
		return settings.homePageSettingKey ?: "pages.homePageId";
	}

	private function clearHomePageIfMatches( required pages.models.Page page ){
		var current = siteSettingsRepo.getValue( arguments.page.getSiteId(), homePageSettingKey(), "" );

		if ( len( current ) && val( current ) == arguments.page.getId() ) {
			siteSettingsRepo.delete( arguments.page.getSiteId(), homePageSettingKey() );
		}

		return this;
	}

	private function sortNodes( required array nodes ){
		arguments.nodes.sort( function( a, b ){
			if ( a.page.getSortOrder() != b.page.getSortOrder() ) {
				return a.page.getSortOrder() < b.page.getSortOrder() ? -1 : 1;
			}
			return compareNoCase( a.page.getTitle(), b.page.getTitle() );
		} );

		for ( var node in arguments.nodes ) {
			sortNodes( node.children );
		}

		return this;
	}

}
