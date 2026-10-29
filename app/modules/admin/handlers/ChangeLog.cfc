/**
 * What the API has changed on this site.
 *
 * Read-only, and there is no action here that writes anything — a log with an
 * edit button is not a log. Entries go when the site goes, by cascade, and
 * nothing else removes one.
 *
 * ## Why `api.tokens.manage` and not a permission of its own
 *
 * The log answers "what did a token do", which is the same question the token
 * screen exists for, and it sits beside it in the navigation. A new permission
 * would have meant a migration to register it and a second to grant it to every
 * existing owner, to end up with exactly the set of people who can already see
 * the tokens themselves. Worth revisiting if somebody needs to read the log
 * without being able to issue credentials.
 */
component extends="core.models.security.SecuredHandler" {

	property name="changeLog" inject="ChangeLogService@core";
	property name="paginator" inject="Paginator@core";

	variables.permissions = {
		"index"  : "api.tokens.manage",
		"$every" : "api.tokens.manage"
	};

	// What the filter offers. A fixed list rather than a `DISTINCT` over the
	// table: the options should not disappear because nothing has happened yet.
	variables.TYPES = [ "page", "media" ];

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		// Anything unrecognised is read as "everything", so a hand-edited URL
		// cannot produce an empty screen that looks like an empty log.
		var type = listFindNoCase( variables.TYPES.toList(), trim( rc.type ?: "" ) )
			? lCase( trim( rc.type ) )
			: "";

		prc.pageTitle  = "API activity";
		prc.types      = variables.TYPES;
		prc.type       = type;
		prc.pagination = paginator.paginate(
			total   = changeLog.countForSite( siteId, type ),
			page    = paginator.readPage( rc.page ?: 1 ),
			perPage = 25
		);
		prc.pageBase = "/admin/api-activity" & ( len( type ) ? "?type=" & urlEncodedFormat( type ) : "" );
		prc.changes  = changeLog.getForSite(
			siteId       = siteId,
			limit        = prc.pagination.perPage,
			offset       = prc.pagination.offset,
			resourceType = type
		);

		event.setView( view = "changeLog/index", module = "admin" );
	}

}
