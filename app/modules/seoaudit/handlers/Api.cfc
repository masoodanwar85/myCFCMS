/**
 * The SEO audit module's REST resource.
 *
 * Four endpoints, and they divide along the line the module already draws
 * between reading a report and doing the work:
 *
 *     GET  /api/v1/seo-audits        seo.view   the site's recent runs
 *     GET  /api/v1/seo-audits/:id    seo.view   one run, with its findings
 *     POST /api/v1/seo-audits        seo.run    start a run
 *     POST /api/v1/seo-audits/page   seo.run    audit one URL, now
 *
 * ## Why starting a run answers 202 and not 200
 *
 * `SeoAuditService.start()` hands the crawl to a background thread and returns
 * the row immediately, because a run is one HTTP request per URL and a
 * two-hundred-page site takes minutes. So the response describes something that
 * has *begun*, not something that is done: the client polls
 * `GET /api/v1/seo-audits/:id` until `status` stops being `running`. `202
 * Accepted` is the status that says exactly that, and a client that treats 200
 * as "the findings are in this response" would otherwise read an empty report
 * as a clean site.
 *
 * ## Why one URL is a different endpoint rather than a flag
 *
 * `POST /api/v1/seo-audits/page` writes no row, spawns no thread, and blocks
 * until it has an answer. An editor checking the page they just saved, six
 * times in a row, must not leave six runs in the report — and must not trip
 * `SeoAudit.AlreadyRunning` for the real nightly crawl. The two have different
 * costs, different lifetimes and different responses, so they are two
 * endpoints.
 */
component extends="core.models.api.ApiHandler" {

	property name="auditService" inject="SeoAuditService@seoaudit";
	property name="settings"     inject="coldbox:moduleSettings:seoaudit";

	// `view` and `run` are separate because they cost different things: reading
	// last night's report is free, and starting a run fetches every public URL
	// of the site. The same split the admin screens use.
	variables.permissions = {
		"index"  : "seo.view",
		"show"   : "seo.view",
		"create" : "seo.run",
		"page"   : "seo.run",
		"$every" : "seo.view"
	};

	/**
	 * `GET /api/v1/seo-audits`
	 *
	 * The site's recent runs, newest first — the counts only, not the findings.
	 * Not paged: the repository already keeps this to a window, because nobody
	 * reads the hundredth most recent audit.
	 */
	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		// A run killed by a restart cannot mark its own row failed, so a stuck
		// row is cleared on read rather than left `running` for ever — which
		// would also block every later audit of this site.
		auditService.reconcileStalled( siteId );

		var audits = auditService.getAuditsForSite( siteId );

		return respond(
			event = event,
			data  = audits.map( ( audit ) => toStruct( audit ) ),
			meta  = { "total" : audits.len() }
		);
	}

	/**
	 * `GET /api/v1/seo-audits/:id`
	 *
	 * One run and everything it found: the flat list, plus the same two
	 * groupings the admin report is built from — by check, which answers "what
	 * is wrong with this site", and by path, which answers "what do I fix on
	 * this page".
	 *
	 * While `status` is `running` the findings are deliberately empty rather
	 * than partial: a run writes them in one statement at the end, so there is
	 * nothing to show and a half-written report would be read as a verdict.
	 */
	function show( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		auditService.reconcileStalled( siteId );

		var audit = auditService.getAudit( val( rc.id ?: 0 ), siteId );

		if ( isNull( audit ) ) {
			return fail( event, 404, "not_found", "No audit with that id on this site." );
		}

		var out = toStruct( audit );

		out[ "findings" ] = auditService
			.getIssues( audit.getId(), siteId )
			.map( ( issue ) => {
				return {
					"path"     : issue.getPath() ?: "",
					"url"      : issue.getDisplayPath(),
					"pageId"   : val( issue.getPageId() ?: 0 ),
					"checkId"  : issue.getCheckId(),
					"severity" : issue.getSeverity(),
					"message"  : issue.getMessage() ?: "",
					"detail"   : issue.getDetail() ?: ""
				};
			} );

		out[ "byCheck" ] = auditService.summariseByCheck( audit.getId(), siteId );
		out[ "byPath" ]  = auditService.summariseByPath( audit.getId(), siteId );

		return respond( event = event, data = out );
	}

	/**
	 * `POST /api/v1/seo-audits`
	 *
	 * Start a crawl of the whole site. Answers `202` with the run to poll.
	 */
	function create( event, rc, prc ){
		try {
			var audit = auditService.start(
				siteId   = prc.currentSite.getId(),
				siteName = prc.currentSite.getName(),
				runBy    = prc.currentUser.getId()
			);
		} catch ( SeoAudit.AlreadyRunning e ) {
			// Mapped here rather than by `failFromException`, which classifies
			// types by the shape of the name and would call this a 500. It is a
			// conflict with the state of the data — the textbook 409 — and the
			// message tells the client what to do about it.
			return fail( event, 409, "conflict", e.message );
		} catch ( any e ) {
			return failFromException( event, e );
		}

		event.setHTTPHeader( name = "Location", value = "/api/v1/seo-audits/" & audit.getId() );

		return respond(
			event      = event,
			data       = toStruct( audit ),
			meta       = { "maxUrls" : val( settings.maxUrls ?: 250 ) },
			statusCode = 202
		);
	}

	/**
	 * `POST /api/v1/seo-audits/page`
	 *
	 * Audit one URL and answer with its findings. Nothing is stored.
	 *
	 * @path       The site-relative path, with or without a leading slash. An
	 *             absent or empty path is the home page, which is a real URL and
	 *             not a mistake.
	 * @checkLinks Also probe the page's own internal links. On by default,
	 *             because a link to a 404 is one of the most useful things this
	 *             can tell anybody; `false` when the caller wants the markup
	 *             checks alone and not one fetch per link.
	 */
	function page( event, rc, prc ){
		// `rc.checkLinks ?: true` would be wrong: ColdFusion's elvis operator
		// falls through on any *falsy* value, not only on null, so a client
		// sending `false` would get the links probed anyway. Presence has to be
		// tested separately from value.
		var wantsLinks = !structKeyExists( rc, "checkLinks" ) || asBoolean( rc.checkLinks );

		try {
			var result = auditService.auditOne(
				siteId     = prc.currentSite.getId(),
				path       = rc.path ?: "",
				siteName   = prc.currentSite.getName(),
				checkLinks = wantsLinks
			);
		} catch ( any e ) {
			return failFromException( event, e );
		}

		// A URL that does not answer is reported as a *finding*, not as an HTTP
		// failure of this endpoint: the audit did its job, and the answer is
		// "this page is broken". Returning 404 here would mean a client could
		// not tell "no such endpoint" from "no such page".
		return respond(
			event = event,
			data  = result,
			meta  = {
				"errors"   : countBy( result.findings, "error" ),
				"warnings" : countBy( result.findings, "warning" ),
				"notices"  : countBy( result.findings, "notice" )
			}
		);
	}

	/* --------------------------------------------------------------------- */

	/**
	 * A run as JSON. An explicit projection, not the entity — serialising the
	 * entity would put whatever is added to it next into the public API by
	 * accident.
	 */
	private struct function toStruct( required any audit ){
		return {
			"id"           : arguments.audit.getId(),
			"status"       : arguments.audit.getStatus(),
			"urlCount"     : val( arguments.audit.getUrlCount() ?: 0 ),
			"queuedCount"  : val( arguments.audit.getQueuedCount() ?: 0 ),
			"errorCount"   : val( arguments.audit.getErrorCount() ?: 0 ),
			"warningCount" : val( arguments.audit.getWarningCount() ?: 0 ),
			"noticeCount"  : val( arguments.audit.getNoticeCount() ?: 0 ),
			"issueCount"   : arguments.audit.getIssueCount(),
			"note"         : arguments.audit.getNote() ?: "",
			"startedAt"    : isoOrEmpty( arguments.audit.getStartedAt() ),
			"finishedAt"   : isoOrEmpty( arguments.audit.getFinishedAt() )
		};
	}

	/**
	 * `?:` will not do for a date: the elvis operator falls through on any
	 * falsy value, so the test has to be `isNull`.
	 */
	private string function isoOrEmpty( any value ){
		return isNull( arguments.value ) ? "" : dateTimeFormat( arguments.value, "iso" );
	}

	/**
	 * A JSON `false` arrives as a real boolean; a form field arrives as the
	 * string "false", which `!!` would read as true.
	 */
	private boolean function asBoolean( required any value ){
		if ( isBoolean( arguments.value ) ) {
			return arguments.value;
		}

		return listFindNoCase( "true,yes,on,1", trim( arguments.value ) ) > 0;
	}

	private numeric function countBy( required array findings, required string severity ){
		var wanted = arguments.severity;

		return arguments.findings.filter( ( finding ) => finding.severity == wanted ).len();
	}

}
