/**
 * Persistence for audit runs and their findings. Every read is scoped by site.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.AUDITS = "seo_audits";
	variables.ISSUES = "seo_audit_issues";

	variables.AUDIT_COLUMNS = [
		"id", "site_id", "status", "started_at", "finished_at", "heartbeat_at",
		"url_count", "queued_count", "error_count", "warning_count",
		"notice_count", "note", "run_by", "created_at", "updated_at"
	];

	variables.ISSUE_COLUMNS = [
		"id", "audit_id", "site_id", "path", "page_id", "check_id",
		"severity", "message", "detail", "created_at"
	];

	/* ---------------------------------------------------------------- runs */

	seoaudit.models.SeoAudit function createAudit( required seoaudit.models.SeoAudit audit ){
		var stamp = now();

		var result = variables.query
			.from( variables.AUDITS )
			.insert( {
				"site_id"       : arguments.audit.getSiteId(),
				"status"        : arguments.audit.getStatus() ?: "running",
				"started_at"    : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"finished_at"   : { value : "", cfsqltype : "cf_sql_timestamp", null : true },
				"heartbeat_at"  : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"url_count"     : 0,
				"queued_count"  : 0,
				"error_count"   : 0,
				"warning_count" : 0,
				"notice_count"  : 0,
				"note"          : arguments.audit.getNote() ?: "",
				"run_by"        : nullableNumber( arguments.audit.getRunBy() ),
				"created_at"    : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"updated_at"    : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.audit.setId( generatedKey( result, variables.AUDITS ) );
		arguments.audit.setStartedAt( stamp );
		arguments.audit.setCreatedAt( stamp );

		return arguments.audit;
	}

	seoaudit.models.SeoAudit function finishAudit( required seoaudit.models.SeoAudit audit ){
		var stamp = now();

		variables.query
			.from( variables.AUDITS )
			.where( "id", arguments.audit.getId() )
			.update( {
				"status"        : arguments.audit.getStatus(),
				"finished_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"heartbeat_at"  : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"url_count"     : val( arguments.audit.getUrlCount() ?: 0 ),
				"queued_count"  : val( arguments.audit.getQueuedCount() ?: 0 ),
				"error_count"   : val( arguments.audit.getErrorCount() ?: 0 ),
				"warning_count" : val( arguments.audit.getWarningCount() ?: 0 ),
				"notice_count"  : val( arguments.audit.getNoticeCount() ?: 0 ),
				"note"          : left( arguments.audit.getNote() ?: "", 500 ),
				"updated_at"    : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.audit.setFinishedAt( stamp );

		return arguments.audit;
	}

	/**
	 * Record how far a run has got, and that it is still alive.
	 *
	 * The heartbeat is the point as much as the counts: a thread that dies
	 * cannot mark its own row failed, and a stale heartbeat is the only
	 * evidence anything else has that the run is gone rather than slow.
	 */
	function touchProgress( required numeric auditId, required numeric fetched, required numeric queued ){
		variables.query
			.from( variables.AUDITS )
			.where( "id", arguments.auditId )
			.update( {
				"url_count"    : arguments.fetched,
				"queued_count" : arguments.queued,
				"heartbeat_at" : { value : now(), cfsqltype : "cf_sql_timestamp" },
				"updated_at"   : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return this;
	}

	/**
	 * The run currently in progress for a site, if there is one.
	 *
	 * Used to refuse a second concurrent crawl. Call `failStalledRuns` first,
	 * or a dead run will look like a live one for ever.
	 */
	function findRunningForSite( required numeric siteId ){
		var row = variables.query
			.from( variables.AUDITS )
			.select( variables.AUDIT_COLUMNS )
			.where( "site_id", arguments.siteId )
			.where( "status", "running" )
			.orderBy( "id", "desc" )
			.first();

		return row.isEmpty() ? javacast( "null", "" ) : toAudit( row );
	}

	/**
	 * Mark as failed any run that has stopped reporting.
	 *
	 * `heartbeat_at IS NULL` is included deliberately: a run that died before
	 * its first progress write has no heartbeat at all, and judging it by
	 * `started_at` is the only thing left. Without that clause such a run would
	 * stay `running` for ever and block every later audit of the site.
	 *
	 * @return how many rows were marked failed.
	 */
	numeric function failStalledRuns( required numeric siteId, required numeric stallMinutes ){
		var cutoff = dateAdd( "n", -arguments.stallMinutes, now() );

		var result = queryExecute(
			"
			UPDATE `seo_audits`
			SET `status` = 'failed',
			    `finished_at` = :stamp,
			    `note` = CONCAT( COALESCE( NULLIF( `note`, '' ), '' ),
			                     'The run stopped without reporting — the server was probably restarted.' ),
			    `updated_at` = :stamp
			WHERE `site_id` = :siteId
			  AND `status` = 'running'
			  AND COALESCE( `heartbeat_at`, `started_at` ) < :cutoff
			",
			{
				siteId : { value : arguments.siteId, cfsqltype : "cf_sql_bigint" },
				cutoff : { value : cutoff, cfsqltype : "cf_sql_timestamp" },
				stamp  : { value : now(), cfsqltype : "cf_sql_timestamp" }
			},
			{ result : "local.updateResult" }
		);

		return val( local.updateResult.recordCount ?: 0 );
	}

	function findAuditById( required numeric id, required numeric siteId ){
		var row = variables.query
			.from( variables.AUDITS )
			.select( variables.AUDIT_COLUMNS )
			.where( "id", arguments.id )
			.where( "site_id", arguments.siteId )
			.first();

		return row.isEmpty() ? javacast( "null", "" ) : toAudit( row );
	}

	/**
	 * The most recent finished or running run, which is what the report opens
	 * on.
	 */
	function findLatestForSite( required numeric siteId ){
		var row = variables.query
			.from( variables.AUDITS )
			.select( variables.AUDIT_COLUMNS )
			.where( "site_id", arguments.siteId )
			.orderBy( "started_at", "desc" )
			.orderBy( "id", "desc" )
			.first();

		return row.isEmpty() ? javacast( "null", "" ) : toAudit( row );
	}

	array function findAuditsForSite( required numeric siteId, numeric limit = 20 ){
		return variables.query
			.from( variables.AUDITS )
			.select( variables.AUDIT_COLUMNS )
			.where( "site_id", arguments.siteId )
			.orderBy( "started_at", "desc" )
			.orderBy( "id", "desc" )
			.limit( arguments.limit )
			.get()
			.map( ( row ) => toAudit( row ) );
	}

	/* -------------------------------------------------------------- findings */

	/**
	 * Findings are written in one statement per run rather than one per
	 * finding. A hundred pages with six findings each is six hundred inserts,
	 * and six hundred round trips is most of the time a run takes.
	 */
	function addIssues( required numeric auditId, required numeric siteId, required array issues ){
		if ( !arguments.issues.len() ) {
			return this;
		}

		var stamp = now();
		var rows  = [];

		for ( var issue in arguments.issues ) {
			// An **ordered** struct, deliberately. A plain struct literal has no
			// key order in CFML, so a multi-row insert built from them can bind
			// one row's columns in a different order from the next — which
			// showed up as "Column 'path' cannot be null" when a null `page_id`
			// landed in `path`'s position. Ordered structs make every row agree.
			var row = structNew( "ordered" );

			row[ "audit_id" ]   = arguments.auditId;
			row[ "site_id" ]    = arguments.siteId;
			row[ "path" ]       = text( issue.path ?: "", 500 );
			row[ "page_id" ]    = nullableNumber( issue.pageId ?: javacast( "null", "" ) );
			row[ "check_id" ]   = text( issue.checkId ?: "unknown", 64 );
			row[ "severity" ]   = text( issue.severity ?: "notice", 16 );
			row[ "message" ]    = text( issue.message ?: "", 500 );
			row[ "detail" ]     = text( issue.detail ?: "", 1000 );
			row[ "created_at" ] = { value : stamp, cfsqltype : "cf_sql_timestamp" };

			rows.append( row );
		}

		variables.query.from( variables.ISSUES ).insert( rows );

		return this;
	}

	array function findIssuesForAudit( required numeric auditId, required numeric siteId ){
		return issueQuery( arguments.auditId, arguments.siteId )
			// Errors first, then warnings, then notices: a report that opens on
			// its own worst finding is read; one that opens on a list of
			// cosmetic notices is not.
			.orderByRaw( "FIELD(severity, 'error', 'warning', 'notice')" )
			.orderBy( "path" )
			.orderBy( "check_id" )
			.get()
			.map( ( row ) => toIssue( row ) );
	}

	/**
	 * How many findings of each check, for the summary. Grouped in SQL rather
	 * than counted in CFML so the summary does not need every row loaded.
	 */
	array function summariseByCheck( required numeric auditId, required numeric siteId ){
		return issueQuery( arguments.auditId, arguments.siteId )
			.selectRaw( "check_id, severity, COUNT(*) AS total" )
			.groupBy( [ "check_id", "severity" ] )
			.orderByRaw( "FIELD(severity, 'error', 'warning', 'notice'), total DESC" )
			.get()
			.map( ( row ) => {
				return {
					"checkId"  : row.check_id,
					"severity" : row.severity,
					"total"    : val( row.total )
				};
			} );
	}

	/**
	 * Distinct audited paths with a count of findings, for the per-page view.
	 */
	array function summariseByPath( required numeric auditId, required numeric siteId ){
		return issueQuery( arguments.auditId, arguments.siteId )
			.selectRaw(
				"path, MAX(page_id) AS page_id, COUNT(*) AS total,"
				& " SUM(severity = 'error') AS errors,"
				& " SUM(severity = 'warning') AS warnings,"
				& " SUM(severity = 'notice') AS notices"
			)
			.groupBy( "path" )
			.orderByRaw( "errors DESC, warnings DESC, path ASC" )
			.get()
			.map( ( row ) => {
				return {
					"path"     : row.path,
					"pageId"   : val( row.page_id ?: 0 ),
					"total"    : val( row.total ),
					"errors"   : val( row.errors ),
					"warnings" : val( row.warnings ),
					"notices"  : val( row.notices )
				};
			} );
	}

	function deleteAudit( required numeric auditId, required numeric siteId ){
		// Issues go with the run by cascade, so only the run is deleted here.
		variables.query
			.from( variables.AUDITS )
			.where( "id", arguments.auditId )
			.where( "site_id", arguments.siteId )
			.delete();

		return this;
	}

	/* -------------------------------------------------------------- internals */

	private function issueQuery( required numeric auditId, required numeric siteId ){
		return variables.query
			.from( variables.ISSUES )
			.where( "audit_id", arguments.auditId )
			.where( "site_id", arguments.siteId )
			.select( variables.ISSUE_COLUMNS );
	}

	private seoaudit.models.SeoAudit function toAudit( required struct row ){
		var audit = wirebox
			.getInstance( "SeoAudit@seoaudit" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setStatus( arguments.row.status )
			.setStartedAt( arguments.row.started_at )
			.setUrlCount( val( arguments.row.url_count ) )
			.setQueuedCount( val( arguments.row.queued_count ?: 0 ) )
			.setErrorCount( val( arguments.row.error_count ) )
			.setWarningCount( val( arguments.row.warning_count ) )
			.setNoticeCount( val( arguments.row.notice_count ) )
			.setNote( arguments.row.note ?: "" )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );

		if ( hasValue( arguments.row, "finished_at" ) ) {
			audit.setFinishedAt( arguments.row.finished_at );
		}
		if ( hasValue( arguments.row, "heartbeat_at" ) ) {
			audit.setHeartbeatAt( arguments.row.heartbeat_at );
		}
		if ( hasValue( arguments.row, "run_by" ) ) {
			audit.setRunBy( val( arguments.row.run_by ) );
		}

		return audit;
	}

	private seoaudit.models.SeoIssue function toIssue( required struct row ){
		var issue = wirebox
			.getInstance( "SeoIssue@seoaudit" )
			.setId( arguments.row.id )
			.setAuditId( arguments.row.audit_id )
			.setSiteId( arguments.row.site_id )
			.setPath( arguments.row.path )
			.setCheckId( arguments.row.check_id )
			.setSeverity( arguments.row.severity )
			.setMessage( arguments.row.message )
			.setDetail( arguments.row.detail ?: "" )
			.setCreatedAt( arguments.row.created_at );

		if ( hasValue( arguments.row, "page_id" ) ) {
			issue.setPageId( val( arguments.row.page_id ) );
		}

		return issue;
	}

	private boolean function hasValue( required struct row, required string key ){
		return structKeyExists( arguments.row, arguments.key )
			&& !isNull( arguments.row[ arguments.key ] )
			&& len( arguments.row[ arguments.key ] );
	}

	/**
	 * A string column, bound explicitly as text that is **not** null.
	 *
	 * qb infers a binding from the value, and it treats an empty string as
	 * NULL. For most columns that is harmless; here it is not, because an empty
	 * `path` is a real value — it is the home page, served at the site root and
	 * recorded as `""` everywhere else in this CMS. Left to inference, every
	 * finding about the home page was rejected with "Column 'path' cannot be
	 * null", which took the whole run down with it.
	 */
	private struct function text( required string value, required numeric maxLength ){
		return {
			value     : left( arguments.value, arguments.maxLength ),
			cfsqltype : "cf_sql_varchar",
			null      : false
		};
	}

	private struct function nullableNumber( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_bigint",
			null      : isNull( arguments.value )
		};
	}

}
