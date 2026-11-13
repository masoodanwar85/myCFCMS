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

	/**
	 * The extra page fields that travel in the service's `seo` struct.
	 *
	 * One flat list, and the values are passed through **verbatim**. The
	 * service converts and validates every one of them — `asBoolean` for the
	 * switches, `val` and a clamp for the sitemap priority, `fromList` for
	 * `ogType` and `twitterCard`, `safeUrl` for the addresses — so a handler
	 * that coerced them first would be a second opinion on the same question,
	 * and the two would eventually disagree.
	 *
	 * The admin's equivalent in `Admin.cfc:seoFrom()` needs `seoTabPresent` and
	 * `contentTabPresent` markers because an unticked HTML checkbox posts
	 * nothing at all, so absence there cannot be told from "off". JSON has no
	 * such problem: `false` arrives as `false`, and a key that is missing is
	 * genuinely missing. That is what makes this a PATCH.
	 */
	variables.SEO_FIELDS = "metaKeywords,canonicalUrl,robotsIndex,robotsFollow,"
		& "ogTitle,ogDescription,ogImage,ogType,twitterCard,"
		& "sitemapInclude,sitemapPriority,sitemapChangefreq,"
		& "showHeading,template,featuredImage,inheritFeaturedImage,"
		& "publishFrom,publishUntil";

	// Raw markup is HTML that bypasses the sanitiser, so it is only read from
	// the request when the token's user may write it. The service refuses it
	// too; this is the outer of the two gates, so a crafted request cannot
	// reach the service with values it will silently drop.
	variables.RAW_FIELDS = "headMarkup,bodyMarkup,jsonLd";

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
			allowUnfilteredHtml : authorization.can( prc.currentUser, "content.unfiltered", prc.currentSite.getId() ),
			// Canonical, robots, the social tags, the sitemap hints, the
			// template, the featured image and the schedule. The same struct
			// the admin builds, so there is one implementation of "apply the
			// SEO fields" and the API cannot drift from the screen.
			seo                 : seoFrom( rc, prc )
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

		var created = toStruct( page, true );

		recordChange( prc, "create", "page", page.getId(), {}, created );

		// 201 with a Location header: the two things a client needs to know
		// where the thing it just made now lives.
		event.setHTTPHeader( name = "Location", value = "/api/v1/pages/" & page.getId() );

		return respond( event = event, data = created, statusCode = 201 );
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

		// Taken before anything is written, because this is the only moment the
		// previous state still exists. The projection rather than the entity:
		// entities are mutable and `updatePage` is handed the same instance, so
		// a reference kept here would quietly become the *new* state.
		var was = toStruct( page, true );

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

		changes.seo = seoFrom( rc, prc );

		try {
			var updated = pageService.updatePage( argumentCollection = changes );

			// Moving is a separate call, because it rewrites the path of every
			// descendant and leaves redirects behind. Only done when the
			// request said anything about the parent at all — on a PATCH an
			// absent `parentId` means "leave the page where it is", not "move
			// it to the top level".
			if ( structKeyExists( rc, "parentId" ) ) {
				updated = reparent( updated, val( rc.parentId ) );
			}
		} catch ( any e ) {
			return failFromException( event, e );
		}

		var now = toStruct( updated, true );

		recordChange( prc, "update", "page", page.getId(), was, now );

		return respond( event = event, data = now );
	}

	/**
	 * Move a page under a new parent, or to the top level when given 0.
	 *
	 * Returns the page untouched when it is already there, so a client that
	 * sends the whole object back on every PATCH does not rewrite its subtree's
	 * paths — and fill the redirect table — for nothing.
	 */
	private function reparent( required any page, required numeric wantedParent ){
		var currentParent = arguments.page.isRoot() ? 0 : arguments.page.getParentId();

		if ( arguments.wantedParent == currentParent ) {
			return arguments.page;
		}

		return arguments.wantedParent
			? pageService.movePage( arguments.page.getId(), arguments.wantedParent )
			: pageService.movePage( arguments.page.getId() );
	}

	/**
	 * The `seo` struct for a request: the fields that are present, untouched.
	 *
	 * See `variables.SEO_FIELDS` for why nothing is coerced here.
	 */
	private struct function seoFrom( required struct rc, required struct prc ){
		var given = {};

		for ( var field in listToArray( variables.SEO_FIELDS ) ) {
			if ( structKeyExists( arguments.rc, field ) ) {
				given[ field ] = arguments.rc[ field ];
			}
		}

		if ( !authorization.can( arguments.prc.currentUser, "content.unfiltered", arguments.prc.currentSite.getId() ) ) {
			return given;
		}

		for ( var field in listToArray( variables.RAW_FIELDS ) ) {
			if ( structKeyExists( arguments.rc, field ) ) {
				given[ field ] = arguments.rc[ field ];
			}
		}

		return given;
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

		var was = toStruct( page, true );

		try {
			var result = arguments.published
				? pageService.publishPage( page.getId(), arguments.prc.currentUser.getId() )
				: pageService.unpublishPage( page.getId(), arguments.prc.currentUser.getId() );
		} catch ( any e ) {
			return failFromException( arguments.event, e );
		}

		var now = toStruct( result, true );

		// Its own action rather than an `update`, because "who published this"
		// is the question somebody asks of the log most often, and answering it
		// should not mean reading two snapshots to spot a `status` field.
		recordChange(
			arguments.prc,
			arguments.published ? "publish" : "unpublish",
			"page",
			page.getId(),
			was,
			now
		);

		return respond( event = arguments.event, data = now );
	}

	/**
	 * `DELETE /api/v1/pages/:id`
	 */
	function remove( event, rc, prc ){
		var page = pageService.getPageById( val( rc.id ?: 0 ) );

		if ( isNull( page ) || page.getSiteId() != prc.currentSite.getId() ) {
			return fail( event, 404, "not_found", "No page with that id." );
		}

		var was = toStruct( page, true );

		try {
			// A subtree is only deleted when asked for outright, the same rule
			// the admin enforces — an API must not be the lenient way in.
			pageService.deletePage( page.getId(), ( rc.withChildren ?: "" ) == "true" );
		} catch ( any e ) {
			return failFromException( event, e );
		}

		// The most important entry in the log: it is the only record left of
		// what the page said. The row is gone, so `before` is all there is.
		recordChange( prc, "delete", "page", page.getId(), was, {} );

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

		if ( !arguments.withContent ) {
			return out;
		}

		out[ "content" ] = arguments.page.getContent() ?: "";

		// The rest of the editable surface, on the single-page view only. A
		// client that has just PATCHed a canonical URL has to be able to read
		// back what was stored — the sanitiser and the service's own validators
		// may well have changed it — and a tree of fifty pages carrying all of
		// this is a response nobody asked for.
		out[ "template" ]             = arguments.page.getTemplate() ?: "";
		out[ "featuredImage" ]        = arguments.page.getFeaturedImage() ?: "";
		out[ "inheritFeaturedImage" ] = arguments.page.getInheritFeaturedImage();
		out[ "showHeading" ]          = arguments.page.getShowHeading();

		out[ "metaKeywords" ]  = arguments.page.getMetaKeywords() ?: "";
		out[ "canonicalUrl" ]  = arguments.page.getCanonicalUrl() ?: "";
		out[ "robotsIndex" ]   = arguments.page.getRobotsIndex();
		out[ "robotsFollow" ]  = arguments.page.getRobotsFollow();

		out[ "ogTitle" ]       = arguments.page.getOgTitle() ?: "";
		out[ "ogDescription" ] = arguments.page.getOgDescription() ?: "";
		out[ "ogImage" ]       = arguments.page.getOgImage() ?: "";
		out[ "ogType" ]        = arguments.page.getOgType() ?: "";
		out[ "twitterCard" ]   = arguments.page.getTwitterCard() ?: "";

		out[ "sitemapInclude" ]    = arguments.page.getSitemapInclude();
		out[ "sitemapPriority" ]   = arguments.page.getSitemapPriority();
		out[ "sitemapChangefreq" ] = arguments.page.getSitemapChangefreq() ?: "";

		out[ "publishFrom" ]  = isoOrEmpty( arguments.page.getPublishFrom() );
		out[ "publishUntil" ] = isoOrEmpty( arguments.page.getPublishUntil() );

		// Reported whatever the token's permissions are. Reading these is
		// `pages.view`, the same as reading `content`; it is *writing* them
		// that needs `content.unfiltered`.
		out[ "headMarkup" ] = arguments.page.getHeadMarkup() ?: "";
		out[ "bodyMarkup" ] = arguments.page.getBodyMarkup() ?: "";
		out[ "jsonLd" ]     = arguments.page.getJsonLd() ?: "";

		return out;
	}

	/**
	 * A date as ISO 8601, or an empty string when it is not set.
	 *
	 * `?:` will not do here: the elvis operator in ColdFusion falls through on
	 * any falsy value, and these are dates — so the test has to be `isNull`.
	 */
	private string function isoOrEmpty( any value ){
		return isNull( arguments.value ) ? "" : dateTimeFormat( arguments.value, "iso" );
	}

}
