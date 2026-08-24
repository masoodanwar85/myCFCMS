/**
 * The Pages module's REST resources.
 *
 * Lives in the module, not in Core, for the same reason its admin screens do:
 * installing or removing Pages adds or removes its endpoints, and Core never
 * learns that pages exist.
 *
 * Every action goes through the *same service* the admin screens use. That is
 * the payoff for the rule set in Group 1 — business logic in services, never in
 * handlers — and it is why an API endpoint cannot drift from the admin: there
 * is one implementation of "create a page", and two ways to reach it.
 */
component extends="core.models.api.ApiHandler" {

	property name="pageService" inject="PageService@pages";

	variables.permissions = {
		"index"   : "pages.view",
		"show"    : "pages.view",
		"create"  : "pages.create",
		"update"  : "pages.update",
		"publish"   : "pages.publish",
		"unpublish" : "pages.publish",
		"remove"  : "pages.delete",
		"$every"  : "pages.view"
	};

	/**
	 * `GET /api/v1/pages`
	 *
	 * The whole tree for this site. Not paged: a page tree is shown whole so
	 * the hierarchy reads correctly, exactly as the admin screen does.
	 */
	function index( event, rc, prc ){
		var pages = pageService.getPagesForSite( prc.currentSite.getId() );

		return respond(
			event = event,
			data  = pages.map( ( page ) => toStruct( page ) ),
			meta  = { "total" : pages.len() }
		);
	}

	/**
	 * `GET /api/v1/pages/:id`
	 */
	function show( event, rc, prc ){
		var page = pageService.getPageById( val( rc.id ?: 0 ) );

		// Scoped to the token's site. An id from the URL must not reach another
		// tenant's content, and "belongs to another site" answers exactly the
		// same as "does not exist" — a 404 either way, so the API cannot be
		// used to discover which ids are in use elsewhere.
		if ( isNull( page ) || page.getSiteId() != prc.currentSite.getId() ) {
			return fail( event, 404, "not_found", "No page with that id." );
		}

		return respond( event = event, data = toStruct( page, true ) );
	}

	/**
	 * `POST /api/v1/pages`
	 */
	function create( event, rc, prc ){
		var attributes = {
			siteId          : prc.currentSite.getId(),
			title           : rc.title ?: "",
			slug            : rc.slug ?: "",
			content         : rc.content ?: "",
			metaTitle       : rc.metaTitle ?: "",
			metaDescription : rc.metaDescription ?: "",
			authorId        : prc.currentUser.getId(),
			// The same permission gate the admin applies. An API that
			// sanitised differently would be a way round the policy.
			allowUnfilteredHtml : authorization.can( prc.currentUser, "content.unfiltered", prc.currentSite.getId() )
		};

		// Only when one was actually asked for. `parentId` is optional on the
		// service, and passing 0 does not mean "top level" — it means "the page
		// whose id is 0", which the service then refuses to find.
		if ( val( rc.parentId ?: 0 ) ) {
			attributes.parentId = val( rc.parentId );
		}

		if ( val( rc.sortOrder ?: 0 ) ) {
			attributes.sortOrder = val( rc.sortOrder );
		}

		try {
			var page = pageService.createPage( argumentCollection = attributes );
		} catch ( any e ) {
			return failFromException( event, e );
		}

		// 201 with a Location header: the two things a client needs to know
		// where the thing it just made now lives.
		event.setHTTPHeader( name = "Location", value = "/api/v1/pages/" & page.getId() );

		return respond( event = event, data = toStruct( page, true ), statusCode = 201 );
	}

	/**
	 * `PATCH /api/v1/pages/:id`
	 *
	 * Only the fields present in the body are changed, which is what makes this
	 * a PATCH rather than a PUT — a client updating a title should not have to
	 * send the whole page back and risk clobbering someone else's edit to the
	 * body in between.
	 */
	function update( event, rc, prc ){
		var page = pageService.getPageById( val( rc.id ?: 0 ) );

		if ( isNull( page ) || page.getSiteId() != prc.currentSite.getId() ) {
			return fail( event, 404, "not_found", "No page with that id." );
		}

		var changes = {
			pageId              : page.getId(),
			editorId            : prc.currentUser.getId(),
			allowUnfilteredHtml : authorization.can( prc.currentUser, "content.unfiltered", prc.currentSite.getId() )
		};

		for ( var field in [ "title", "slug", "content", "metaTitle", "metaDescription" ] ) {
			if ( structKeyExists( rc, field ) ) {
				changes[ field ] = rc[ field ];
			}
		}

		if ( structKeyExists( rc, "sortOrder" ) ) {
			changes.sortOrder = val( rc.sortOrder );
		}

		try {
			var updated = pageService.updatePage( argumentCollection = changes );
		} catch ( any e ) {
			return failFromException( event, e );
		}

		return respond( event = event, data = toStruct( updated, true ) );
	}

	/**
	 * `POST /api/v1/pages/:id/publish`
	 *
	 * Its own endpoint rather than `PATCH { status : "published" }`, because
	 * publishing is a different permission from editing and a URL is the
	 * clearest place for that difference to live.
	 */
	function publish( event, rc, prc ){
		return setPublished( event, rc, prc, true );
	}

	/**
	 * `POST /api/v1/pages/:id/unpublish`
	 */
	function unpublish( event, rc, prc ){
		return setPublished( event, rc, prc, false );
	}

	private function setPublished( event, rc, prc, required boolean published ){
		var page = pageService.getPageById( val( arguments.rc.id ?: 0 ) );

		if ( isNull( page ) || page.getSiteId() != arguments.prc.currentSite.getId() ) {
			return fail( arguments.event, 404, "not_found", "No page with that id." );
		}

		try {
			var result = arguments.published
				? pageService.publishPage( page.getId(), arguments.prc.currentUser.getId() )
				: pageService.unpublishPage( page.getId(), arguments.prc.currentUser.getId() );
		} catch ( any e ) {
			return failFromException( arguments.event, e );
		}

		return respond( event = arguments.event, data = toStruct( result, true ) );
	}

	/**
	 * `DELETE /api/v1/pages/:id`
	 */
	function remove( event, rc, prc ){
		var page = pageService.getPageById( val( rc.id ?: 0 ) );

		if ( isNull( page ) || page.getSiteId() != prc.currentSite.getId() ) {
			return fail( event, 404, "not_found", "No page with that id." );
		}

		try {
			// A subtree is only deleted when asked for outright, the same rule
			// the admin enforces — an API must not be the lenient way in.
			pageService.deletePage( page.getId(), ( rc.withChildren ?: "" ) == "true" );
		} catch ( any e ) {
			return failFromException( event, e );
		}

		return respond( event = event, data = { "deleted" : true, "id" : page.getId() } );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * A page as JSON.
	 *
	 * An explicit projection, not the entity. Serialising an entity would put
	 * whatever a developer adds to it next into the public API by accident —
	 * which is how internal columns end up in someone else's client.
	 *
	 * @withContent Collections leave the body out: a tree of fifty pages with
	 *              full HTML is a large response nobody asked for.
	 */
	private struct function toStruct( required any page, boolean withContent = false ){
		var out = {
			"id"              : arguments.page.getId(),
			"title"           : arguments.page.getTitle(),
			"slug"            : arguments.page.getSlug(),
			"path"            : arguments.page.getPath(),
			"url"             : "/" & arguments.page.getPath(),
			"status"          : arguments.page.getStatus(),
			"parentId"        : val( arguments.page.getParentId() ?: 0 ),
			"sortOrder"       : val( arguments.page.getSortOrder() ?: 0 ),
			"metaTitle"       : arguments.page.getMetaTitle() ?: "",
			"metaDescription" : arguments.page.getMetaDescription() ?: "",
			"publishedAt"     : isNull( arguments.page.getPublishedAt() ) ? "" : dateTimeFormat( arguments.page.getPublishedAt(), "iso" ),
			"updatedAt"       : isNull( arguments.page.getUpdatedAt() ) ? "" : dateTimeFormat( arguments.page.getUpdatedAt(), "iso" )
		};

		if ( arguments.withContent ) {
			out[ "content" ] = arguments.page.getContent() ?: "";
		}

		return out;
	}

}
