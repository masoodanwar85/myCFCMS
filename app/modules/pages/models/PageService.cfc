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
	property name="siteRepository"   inject="SiteRepository@core";
	property name="userRepository"   inject="UserRepository@core";
	property name="siteSettingsRepo" inject="SiteSettingsRepository@core";
	property name="settings"         inject="coldbox:moduleSettings:pages";
	property name="interceptorService" inject="coldbox:interceptorService";
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
		numeric authorId
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
			.setContent( arguments.content )
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
		numeric editorId
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
			page.setContent( arguments.content );
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

		var moved = page.getPath() != oldPath;

		if ( moved && pageRepository.existsByPath( page.getSiteId(), page.getPath() ) ) {
			throw(
				type    = "Pages.PathAlreadyExists",
				message = "This site already has a page at [#page.getPath()#]."
			);
		}

		var updated = pageRepository.update( page );

		if ( moved ) {
			pageRepository.rewriteDescendantPaths( page.getSiteId(), oldPath, page.getPath() );
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

		var updated = pageRepository.update( page );

		if ( page.getPath() != oldPath ) {
			pageRepository.rewriteDescendantPaths( page.getSiteId(), oldPath, page.getPath() );
		}

		interceptorService.announce( "onPageUpdated", { page : updated, pathChanged : page.getPath() != oldPath } );

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
	 * Helpers
	 * ------------------------------------------------------------------ */

	boolean function isValidStatus( required string status ){
		return [ "draft", "published", "archived" ].findNoCase( arguments.status ) > 0;
	}

	string function slugify( required string value ){
		var slug = lCase( trim( arguments.value ) );
		slug     = reReplace( slug, "[^a-z0-9]+", "-", "all" );
		slug     = reReplace( slug, "^-+|-+$", "", "all" );

		return slug;
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
