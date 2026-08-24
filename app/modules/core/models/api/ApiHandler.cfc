/**
 * The request boundary for the REST API.
 *
 * The counterpart to `SecuredHandler`, and deliberately its sibling rather than
 * its subclass: the two share a shape but almost nothing else. An admin request
 * carries a session cookie, needs a CSRF token, renders a layout, and refuses
 * by redirecting to a sign-in page. An API request carries a bearer token,
 * needs no CSRF (nothing is sent automatically, so nothing can be forged),
 * renders JSON, and refuses with a status code.
 *
 * What they *do* share is the thing that matters: **fail-closed permissions**.
 * A handler declares what each action needs, and an action with no entry and no
 * `$every` fallback is refused. Forgetting to declare a permission must never
 * be the same as declaring it public.
 *
 *     variables.permissions = {
 *         "index"  : "pages.view",
 *         "create" : "pages.create",
 *         "$every" : "pages.view"
 *     };
 *
 * ## The same permissions as the admin
 *
 * An API request is authorised against `pages.view`, not `api.pages.read`. A
 * parallel permission set is how an installation ends up with an API that can
 * do things the admin refuses — and nobody notices until it is used.
 *
 * ## One error shape
 *
 * Every failure looks the same, so a client can handle errors generically:
 *
 *     { "error" : { "code" : "forbidden", "message" : "..." } }
 *
 * and every success is wrapped, so adding pagination to a collection later does
 * not change the shape of the response:
 *
 *     { "data" : ..., "meta" : { ... } }
 */
component extends="coldbox.system.EventHandler" {

	property name="apiTokens"     inject="ApiTokenService@core";
	property name="authorization" inject="AuthorizationService@core";
	property name="tenantContext" inject="TenantContext@core";
	property name="paginator"     inject="Paginator@core";
	property name="log"           inject="logbox:logger:{this}";

	// Actions reachable without a token.
	variables.publicActions = "";

	// action -> permission slug. `$every` is the fallback.
	variables.permissions = {};

	function preHandler( event, rc, prc, action, eventArguments ){
		event.noLayout();

		// Every response is JSON, including the refusals below.
		event.setHTTPHeader( name = "Content-Type", value = "application/json; charset=utf-8" );

		// An API response is per-token and must never be cached by a shared
		// proxy: one client's data reaching another's request is the worst
		// failure this layer can have.
		event.setHTTPHeader( name = "Cache-Control", value = "no-store, private" );
		event.setHTTPHeader( name = "X-Content-Type-Options", value = "nosniff" );

		if ( !tenantContext.hasCurrentTenant() ) {
			return fail( event, 404, "unknown_site", "No site is served at this address." );
		}

		prc.currentSite = tenantContext.getCurrentTenant();

		if ( !readBody( event, rc ) ) {
			return fail( event, 400, "malformed_body", "The request body is not valid JSON." );
		}

		if ( listFindNoCase( variables.publicActions, arguments.action ) ) {
			return;
		}

		var presented = bearerToken( event );

		if ( !len( presented ) ) {
			// `WWW-Authenticate` is what tells a client *how* to authenticate,
			// and is the part of a 401 that is most often left out.
			event.setHTTPHeader( name = "WWW-Authenticate", value = "Bearer realm=""api""" );

			return fail( event, 401, "unauthenticated", "This endpoint needs a bearer token." );
		}

		var resolved = apiTokens.resolve( presented );

		if ( isNull( resolved ) ) {
			event.setHTTPHeader( name = "WWW-Authenticate", value = "Bearer realm=""api""" );

			// One message for every reason: no such token, revoked, expired,
			// user deactivated, site suspended. A client that can tell those
			// apart can enumerate them.
			return fail( event, 401, "unauthenticated", "That token is not valid." );
		}

		// A token is bound to the site it was issued for. Presenting it against
		// another tenant's domain is refused even though the token itself is
		// perfectly good — which is the whole point of binding it.
		if ( resolved.token.getSiteId() != prc.currentSite.getId() ) {
			return fail( event, 403, "wrong_site", "That token belongs to a different site." );
		}

		prc.currentUser  = resolved.user;
		prc.currentToken = resolved.token;

		var required = requiredPermission( arguments.action );

		if ( !len( required ) ) {
			// Fail closed. An action nobody declared a permission for is a bug,
			// and the safe reading of a bug is "refuse".
			return fail( event, 403, "forbidden", "This endpoint is not available." );
		}

		if ( !authorization.can( prc.currentUser, required, prc.currentSite.getId() ) ) {
			return fail( event, 403, "forbidden", "Your token does not carry the [#required#] permission." );
		}
	}

	/* ------------------------------------------------------------- helpers */

	/**
	 * A successful response.
	 *
	 * @data The payload — a struct for one thing, an array for a collection.
	 * @meta Pagination and anything else about the response rather than in it.
	 */
	function respond( event, any data, struct meta = {}, numeric statusCode = 200 ){
		var body = { "data" : arguments.data };

		if ( !arguments.meta.isEmpty() ) {
			body[ "meta" ] = arguments.meta;
		}

		event.renderData( type = "json", data = body, statusCode = arguments.statusCode );

		return;
	}

	/**
	 * A paged collection, with the `meta` block a client needs to walk it.
	 */
	function respondPaged( event, required array items, required struct page ){
		return respond(
			event = arguments.event,
			data  = arguments.items,
			meta  = {
				"page"       : arguments.page.page,
				"perPage"    : arguments.page.perPage,
				"total"      : arguments.page.total,
				"totalPages" : arguments.page.totalPages,
				"hasNext"    : arguments.page.hasNext
			}
		);
	}

	/**
	 * A failure, in the one shape every client can rely on.
	 */
	function fail( event, numeric statusCode, required string code, required string message ){
		event.renderData(
			type       = "json",
			statusCode = arguments.statusCode,
			data       = { "error" : { "code" : arguments.code, "message" : arguments.message } }
		);

		// Stops the action running. `noExecution()` was not enough here for the
		// same reason it was not enough in SecuredHandler — see the comment
		// there — so the event is overridden to a handler that renders nothing.
		event.overrideEvent( "core:Api.refused" );

		return;
	}

	/**
	 * Turn an exception from a service into a response.
	 *
	 * Services throw typed errors — `Pages.PageNotFound`, `Menu.InvalidItem` —
	 * and this maps the shape of the type onto a status code so every handler
	 * does not repeat the same `switch`.
	 */
	function failFromException( event, required any exception ){
		var type    = arguments.exception.type ?: "";
		var suffix  = listLast( type, "." );
		var message = arguments.exception.message ?: "Something went wrong.";

		if ( reFindNoCase( "NotFound$", suffix ) ) {
			return fail( arguments.event, 404, "not_found", message );
		}

		if ( reFindNoCase( "(AlreadyExists|Exists|Taken|HasChildren|InUse)$", suffix ) ) {
			// The request was well-formed and refused because of the state of
			// the data — deleting a page that still has children, reusing a
			// slug. That is a 409, not a 500 and not a validation error.
			return fail( arguments.event, 409, "conflict", message );
		}

		if ( reFindNoCase( "^(Invalid|CrossTenant|Circular|TooDeep|Unusable)", suffix ) ) {
			return fail( arguments.event, 422, "invalid", message );
		}

		// Anything unrecognised is a 500, and the message is *not* passed on:
		// an unexpected exception's text is written for a log, and may name a
		// table, a file path or a query.
		log.error( "Unhandled API exception [#type#]: #message#", arguments.exception );

		return fail( arguments.event, 500, "server_error", "The request could not be completed." );
	}

	/**
	 * Read pagination from the query string, capped by Paginator.
	 */
	struct function readPage( rc, required numeric total, numeric perPage = 25 ){
		return paginator.paginate(
			total   = arguments.total,
			page    = paginator.readPage( arguments.rc.page ?: 1 ),
			perPage = val( arguments.rc.perPage ?: 0 ) ? val( arguments.rc.perPage ) : arguments.perPage
		);
	}

	/* ----------------------------------------------------------- internals */

	/**
	 * The bearer token, or an empty string.
	 *
	 * Header only. A token in a query string ends up in access logs, proxy
	 * logs, browser history and `Referer` headers — which is why the API does
	 * not accept one there however convenient it would be.
	 */
	/**
	 * Merge the request body into `rc`.
	 *
	 * Two reasons this has to exist rather than being left to the framework:
	 *
	 *   1. **JSON.** A REST client sends `application/json`, and ColdFusion
	 *      does not unpack that into a scope — the body is just a string.
	 *   2. **PUT and PATCH.** ColdFusion populates the FORM scope for a POST
	 *      only. A form-encoded `PATCH` therefore arrives with an empty `rc`,
	 *      and an update silently changes nothing while answering `200` — which
	 *      is exactly what it did before this was written.
	 *
	 * Values already in `rc` win, so a path parameter like `:id` cannot be
	 * overwritten by a body claiming a different one.
	 *
	 * @return false when the body claimed to be JSON and was not.
	 */
	private boolean function readBody( event, rc ){
		var body = trim( arguments.event.getHTTPContent() ?: "" );

		if ( !len( body ) ) {
			return true;
		}

		var rawType     = arguments.event.getHTTPHeader( "Content-Type", "" );
		var contentType = isNull( rawType ) ? "" : lCase( rawType );

		if ( find( "json", contentType ) ) {
			if ( !isJSON( body ) ) {
				return false;
			}

			var parsed = deserializeJSON( body );

			// A bare array or string is not something `rc` can absorb, and
			// quietly ignoring it would hide a client's mistake.
			if ( !isStruct( parsed ) ) {
				return false;
			}

			for ( var key in parsed ) {
				if ( !structKeyExists( arguments.rc, key ) ) {
					arguments.rc[ key ] = parsed[ key ];
				}
			}

			return true;
		}

		// Form-encoded on a verb ColdFusion does not unpack for us.
		if ( find( "application/x-www-form-urlencoded", contentType ) ) {
			for ( var pair in listToArray( body, "&" ) ) {
				var name = urlDecode( listFirst( pair, "=" ) );

				if ( len( name ) && !structKeyExists( arguments.rc, name ) ) {
					arguments.rc[ name ] = find( "=", pair )
						? urlDecode( listRest( pair, "=" ) )
						: "";
				}
			}
		}

		return true;
	}

	private string function bearerToken( event ){
		// `event.getHTTPHeader()` rather than `getHTTPRequestData()`. The
		// latter reads the *real* HTTP request, which is right in production
		// and useless anywhere the framework is driving the request itself — a
		// simulated request in a spec has no such header, so every
		// authenticated test would have failed with a 401 while the code was
		// perfectly correct. Reading through the event works in both.
		var header = arguments.event.getHTTPHeader( "Authorization", "" );

		// Explicitly, because on Adobe ColdFusion an absent header can come
		// back as null despite the default — ColdBox's own source carries a
		// comment about exactly that. Without this, every *unauthenticated*
		// request died with "variable HEADER is undefined" instead of
		// answering 401.
		if ( isNull( header ) ) {
			return "";
		}

		if ( !reFindNoCase( "^Bearer\s+", header ) ) {
			return "";
		}

		return trim( reReplaceNoCase( header, "^Bearer\s+", "" ) );
	}

	private string function requiredPermission( required string action ){
		if ( structKeyExists( variables.permissions, arguments.action ) ) {
			return variables.permissions[ arguments.action ];
		}

		return variables.permissions[ "$every" ] ?: "";
	}

}
