/**
 * The Pages module's own admin screens, served at /admin/pages.
 *
 * This handler lives in the Pages module, not in the admin module, and that is
 * the point: the admin shell carries no knowledge of pages, and installing or
 * removing this module adds or removes its screens and its navigation entry
 * without the admin changing. Blog will follow exactly this shape.
 *
 * It extends Core's SecuredHandler, so it depends on Core alone.
 */
component extends="core.models.security.SecuredHandler" {

	property name="pageService" inject="PageService@pages";

	variables.permissions = {
		"index"     : "pages.view",
		"new"       : "pages.create",
		"create"    : "pages.create",
		"edit"      : "pages.update",
		"update"    : "pages.update",
		"publish"   : "pages.publish",
		"unpublish" : "pages.publish",
		"setHome"   : "pages.update",
		"remove"    : "pages.delete",
		"$every"    : "pages.view"
	};

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		prc.pageTitle = "Pages";
		prc.tree      = flatten( pageService.getTree( siteId ), 0 );
		prc.homePage  = pageService.getHomePage( siteId );

		prc.canCreate  = authorization.can( prc.currentUser, "pages.create" );
		prc.canUpdate  = authorization.can( prc.currentUser, "pages.update" );
		prc.canPublish = authorization.can( prc.currentUser, "pages.publish" );
		prc.canDelete  = authorization.can( prc.currentUser, "pages.delete" );

		event.setView( view = "admin/index", module = "pages" );
	}

	function new( event, rc, prc ){
		prc.pageTitle = "New page";
		prc.page      = "";
		prc.parents   = pageService.getPagesForSite( prc.currentSite.getId() );

		prc.useEditor      = true;
		prc.mayPostRawHtml = mayPostRawHtml( prc );

		event.setView( view = "admin/form", module = "pages" );
	}

	function create( event, rc, prc ){
		try {
			var page = pageService.createPage(
				siteId          = prc.currentSite.getId(),
				title           = rc.title ?: "",
				slug            = rc.slug ?: "",
				content         = rc.content ?: "",
				metaTitle       = rc.metaTitle ?: "",
				metaDescription = rc.metaDescription ?: "",
				sortOrder       = val( rc.sortOrder ?: 0 ),
				authorId        = prc.currentUser.getId(),
				allowUnfilteredHtml = mayPostRawHtml( prc ),
				seo             = seoFrom( rc, prc ),
				argumentCollection = parentArgs( rc )
			);
		} catch ( any e ) {
			return done( "/admin/pages/new", e.message, "error" );
		}

		return done( "/admin/pages", "Page created." );
	}

	function edit( event, rc, prc ){
		var page = requireSitePage( rc.id ?: 0, prc );

		prc.pageTitle = "Edit page";
		prc.page      = page;
		prc.parents   = pageService
			.getPagesForSite( prc.currentSite.getId() )
			.filter( ( candidate ) => candidate.getId() != page.getId() );

		prc.useEditor      = true;
		prc.mayPostRawHtml = mayPostRawHtml( prc );

		event.setView( view = "admin/form", module = "pages" );
	}

	/**
	 * The SEO, social, sitemap and scheduling fields, from the form.
	 *
	 * Only keys actually posted are included, so the service applies a partial
	 * update and a form that omits a tab leaves those values alone.
	 *
	 * Checkboxes are the exception: an unticked one posts *nothing at all*, so
	 * absence has to mean `false` rather than "unchanged". They are keyed off a
	 * companion hidden field the form always posts, which is what tells this
	 * the tab was rendered at all.
	 */
	private struct function seoFrom( required struct rc, required struct prc ){
		var given = {};

		for ( var field in [
			"metaKeywords", "canonicalUrl", "ogTitle", "ogDescription", "ogImage",
			"ogType", "twitterCard", "sitemapPriority", "sitemapChangefreq",
			"publishFrom", "publishUntil"
		] ) {
			if ( structKeyExists( arguments.rc, field ) ) {
				given[ field ] = arguments.rc[ field ];
			}
		}

		if ( ( arguments.rc.seoTabPresent ?: "" ) == "1" ) {
			given.robotsIndex    = ( arguments.rc.robotsIndex ?: "" ) == "on";
			given.robotsFollow   = ( arguments.rc.robotsFollow ?: "" ) == "on";
			given.sitemapInclude = ( arguments.rc.sitemapInclude ?: "" ) == "on";
		}

		// Its own marker, and not `seoTabPresent`: this checkbox lives on the
		// Content tab, and reading it under the SEO tab's flag would tie two
		// unrelated parts of the form together. An unticked checkbox posts
		// nothing at all, so without a marker there is no way to tell "the
		// author cleared it" from "this form had no such field".
		if ( ( arguments.rc.contentTabPresent ?: "" ) == "1" ) {
			given.showHeading = ( arguments.rc.showHeading ?: "" ) == "on";
		}

		// Raw markup is only read from the form when the author may write it.
		// The service refuses it too — this is the outer of two gates, so a
		// crafted post cannot reach the service with values it will silently
		// drop and leave an author wondering why nothing saved.
		if ( mayPostRawHtml( arguments.prc ) ) {
			for ( var field in [ "headMarkup", "bodyMarkup", "jsonLd" ] ) {
				if ( structKeyExists( arguments.rc, field ) ) {
					given[ field ] = arguments.rc[ field ];
				}
			}
		}

		return given;
	}

	function update( event, rc, prc ){
		var page = requireSitePage( rc.id ?: 0, prc );

		try {
			pageService.updatePage(
				pageId          = page.getId(),
				title           = rc.title ?: page.getTitle(),
				slug            = rc.slug ?: page.getSlug(),
				content         = rc.content ?: "",
				metaTitle       = rc.metaTitle ?: "",
				metaDescription = rc.metaDescription ?: "",
				sortOrder       = val( rc.sortOrder ?: 0 ),
				editorId        = prc.currentUser.getId(),
				allowUnfilteredHtml = mayPostRawHtml( prc ),
				seo             = seoFrom( rc, prc )
			);

			// Moving is separate from editing, because it rewrites the paths of
			// every descendant and should only happen when the parent changed.
			var wantedParent = len( rc.parentId ?: "" ) ? val( rc.parentId ) : 0;
			var currentParent = page.isRoot() ? 0 : page.getParentId();

			if ( wantedParent != currentParent ) {
				if ( wantedParent ) {
					pageService.movePage( page.getId(), wantedParent );
				} else {
					pageService.movePage( page.getId() );
				}
			}
		} catch ( any e ) {
			return done( "/admin/pages/edit/" & page.getId(), e.message, "error" );
		}

		return done( "/admin/pages", "Page saved." );
	}

	function publish( event, rc, prc ){
		var page = requireSitePage( rc.id ?: 0, prc );

		pageService.publishPage( page.getId(), prc.currentUser.getId() );

		return done( "/admin/pages", "Page published." );
	}

	function unpublish( event, rc, prc ){
		var page = requireSitePage( rc.id ?: 0, prc );

		pageService.unpublishPage( page.getId(), prc.currentUser.getId() );

		return done( "/admin/pages", "Page unpublished." );
	}

	function setHome( event, rc, prc ){
		var page = requireSitePage( rc.id ?: 0, prc );

		pageService.setHomePage( prc.currentSite.getId(), page.getId() );

		return done( "/admin/pages", "Home page set." );
	}

	function remove( event, rc, prc ){
		var page = requireSitePage( rc.id ?: 0, prc );

		try {
			pageService.deletePage( page.getId(), ( rc.withChildren ?: "" ) == "yes" );
		} catch ( Pages.PageHasChildren e ) {
			return done( "/admin/pages", "That page has child pages. Delete or move them first.", "error" );
		}

		return done( "/admin/pages", "Page deleted." );
	}

	/**
	 * Whether this author may store markup without sanitising.
	 *
	 * The service sanitises unless told otherwise, so the decision is made here
	 * — at the request boundary, where the acting user is known.
	 */
	private boolean function mayPostRawHtml( required struct prc ){
		return authorization.can( arguments.prc.currentUser, "content.unfiltered" );
	}

	/**
	 * Only pass `parentId` when one was actually chosen, so an empty select
	 * means "top level" rather than parent zero.
	 */
	private struct function parentArgs( required struct rc ){
		return len( arguments.rc.parentId ?: "" ) && val( arguments.rc.parentId )
			? { parentId : val( arguments.rc.parentId ) }
			: {};
	}

	/**
	 * Flatten the tree for a table, carrying depth so it can be indented.
	 */
	private array function flatten( required array nodes, required numeric depth ){
		var rows = [];

		for ( var node in arguments.nodes ) {
			rows.append( { "page" : node.page, "depth" : arguments.depth } );
			rows.append( flatten( node.children, arguments.depth + 1 ), true );
		}

		return rows;
	}

	/**
	 * Load a page, refusing anything that is not this site's.
	 */
	private function requireSitePage( required numeric pageId, required struct prc ){
		var page = pageService.getPageById( arguments.pageId );

		if ( isNull( page ) || page.getSiteId() != arguments.prc.currentSite.getId() ) {
			throw( type = "Admin.NotFoundHere", message = "No page [#arguments.pageId#] on this site." );
		}

		return page;
	}

}
