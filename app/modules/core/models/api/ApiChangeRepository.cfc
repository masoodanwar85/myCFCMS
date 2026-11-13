/**
 * Persistence for the API change log. Every read is scoped by site.
 *
 * Insert-only by design: nothing in the application updates a row here, because
 * a log that can be edited is not a log. Rows go when the site goes, by cascade.
 *
 * shortcut: no retention policy, so the log grows without bound. This project
 * has no scheduler to hang one on; add a pruning task when it does, or trim the
 * table from a deploy step.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE = "api_change_log";

	// `l.*` as raw SQL rather than through `select()`: qb quotes each
	// identifier, and a quoted `*` is not valid SQL.
	variables.READ = "l.*, u.name AS user_name, t.name AS token_name";

	core.models.api.ApiChange function create( required core.models.api.ApiChange change ){
		var stamp = now();

		var result = variables.query
			.from( variables.TABLE )
			.insert( {
				"site_id"       : arguments.change.getSiteId(),
				"user_id"       : nullableNumber( arguments.change.getUserId() ),
				"token_id"      : nullableNumber( arguments.change.getTokenId() ),
				"action"        : left( arguments.change.getAction(), 32 ),
				"resource_type" : left( arguments.change.getResourceType(), 32 ),
				"resource_id"   : nullableNumber( arguments.change.getResourceId() ),
				"before_json"   : arguments.change.getBeforeJson() ?: "",
				"after_json"    : arguments.change.getAfterJson() ?: "",
				"created_at"    : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.change.setId( generatedKey( result, variables.TABLE ) );
		arguments.change.setCreatedAt( stamp );

		return arguments.change;
	}

	/**
	 * The site's changes, newest first.
	 *
	 * `LEFT JOIN`, both of them: a change outlives the user who made it and the
	 * token they used, and an inner join would make the log silently lose
	 * exactly the entries somebody deleting a token would want gone.
	 *
	 * @resourceType Narrow to `page` or `media`.
	 * @resourceId   Narrow to one thing's history. Needs `resourceType` to mean
	 *               anything — ids are unique within a type, not across them.
	 */
	array function findForSite(
		required numeric siteId,
		numeric limit       = 50,
		numeric offset      = 0,
		string resourceType = "",
		numeric resourceId  = 0
	){
		return scoped( arguments.siteId, arguments.resourceType, arguments.resourceId )
			.selectRaw( variables.READ )
			.leftJoin( "users AS u", "u.id", "l.user_id" )
			.leftJoin( "api_tokens AS t", "t.id", "l.token_id" )
			.orderBy( "l.created_at", "desc" )
			// Then by id, because a burst of changes shares a second and
			// without this their order on the screen is whatever MySQL felt
			// like — which looks like the log being wrong.
			.orderBy( "l.id", "desc" )
			.limit( arguments.limit )
			.offset( arguments.offset )
			.get()
			.map( ( row ) => toChange( row ) );
	}

	numeric function countForSite(
		required numeric siteId,
		string resourceType = "",
		numeric resourceId  = 0
	){
		return scoped( arguments.siteId, arguments.resourceType, arguments.resourceId ).count();
	}

	function findById( required numeric id, required numeric siteId ){
		var rows = scoped( arguments.siteId )
			.selectRaw( variables.READ )
			.leftJoin( "users AS u", "u.id", "l.user_id" )
			.leftJoin( "api_tokens AS t", "t.id", "l.token_id" )
			.where( "l.id", arguments.id )
			.get();

		if ( !rows.len() ) {
			return;
		}

		return toChange( rows[ 1 ] );
	}

	/* -------------------------------------------------------------- internals */

	private function scoped(
		required numeric siteId,
		string resourceType = "",
		numeric resourceId  = 0
	){
		var builder = variables.query
			.from( variables.TABLE & " AS l" )
			.where( "l.site_id", arguments.siteId );

		if ( len( trim( arguments.resourceType ) ) ) {
			builder.where( "l.resource_type", trim( arguments.resourceType ) );

			if ( arguments.resourceId ) {
				builder.where( "l.resource_id", arguments.resourceId );
			}
		}

		return builder;
	}

	private core.models.api.ApiChange function toChange( required any row ){
		var change = wirebox
			.getInstance( "ApiChange@core" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setAction( arguments.row.action )
			.setResourceType( arguments.row.resource_type )
			.setBeforeJson( arguments.row.before_json ?: "" )
			.setAfterJson( arguments.row.after_json ?: "" )
			.setCreatedAt( arguments.row.created_at )
			.setUserName( arguments.row.user_name ?: "" )
			.setTokenName( arguments.row.token_name ?: "" );

		// Nullable columns, so each is set only when there is a value: an
		// unset property reads as null, which is the truth for a change whose
		// user or token has since been deleted.
		if ( len( arguments.row.user_id ?: "" ) ) {
			change.setUserId( val( arguments.row.user_id ) );
		}
		if ( len( arguments.row.token_id ?: "" ) ) {
			change.setTokenId( val( arguments.row.token_id ) );
		}
		if ( len( arguments.row.resource_id ?: "" ) ) {
			change.setResourceId( val( arguments.row.resource_id ) );
		}

		return change;
	}

	private struct function nullableNumber( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_bigint",
			null      : isNull( arguments.value )
		};
	}

}
