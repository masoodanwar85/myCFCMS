/**
 * Persistence for API tokens. Every read is scoped by site, except the lookup
 * by hash — which is how a bearer token is resolved before any site is known.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "api_tokens";
	variables.COLUMNS = [
		"id", "site_id", "user_id", "name", "token_hash", "prefix",
		"last_used_at", "expires_at", "revoked_at", "created_at", "updated_at"
	];

	core.models.api.ApiToken function create( required core.models.api.ApiToken token ){
		var stamp = now();

		var result = variables.query
			.from( variables.TABLE )
			.insert( {
				"site_id"    : arguments.token.getSiteId(),
				"user_id"    : arguments.token.getUserId(),
				"name"       : arguments.token.getName(),
				"token_hash" : arguments.token.getTokenHash(),
				"prefix"     : arguments.token.getPrefix(),
				"expires_at" : nullableDate( arguments.token.getExpiresAt() ),
				"created_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.token.setId( generatedKey( result, variables.TABLE ) );
		arguments.token.setCreatedAt( stamp );

		return arguments.token;
	}

	/**
	 * The lookup behind every authenticated API request.
	 *
	 * By hash, never by anything the caller supplied in the clear, and never by
	 * a `LIKE` on the prefix: the hash is the whole credential and the unique
	 * index makes this a single index hit.
	 */
	function findByHash( required string tokenHash ){
		var row = baseQuery().where( "token_hash", arguments.tokenHash ).first();

		return row.isEmpty() ? javacast( "null", "" ) : toToken( row );
	}

	function findById( required numeric id ){
		var row = baseQuery().where( "id", arguments.id ).first();

		return row.isEmpty() ? javacast( "null", "" ) : toToken( row );
	}

	array function findBySiteId( required numeric siteId ){
		return baseQuery()
			.where( "site_id", arguments.siteId )
			.orderBy( "created_at", "desc" )
			.get()
			.map( ( row ) => toToken( row ) );
	}

	function revoke( required numeric id ){
		variables.query
			.from( variables.TABLE )
			.where( "id", arguments.id )
			.whereNull( "revoked_at" )
			.update( {
				"revoked_at" : { value : now(), cfsqltype : "cf_sql_timestamp" },
				"updated_at" : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return this;
	}

	/**
	 * Record that a token was used.
	 *
	 * Best-effort and deliberately not part of the request's success: a write
	 * failure here must not turn a working API call into an error, and this is
	 * the one write on an otherwise read-only path.
	 */
	function touch( required numeric id ){
		try {
			variables.query
				.from( variables.TABLE )
				.where( "id", arguments.id )
				.update( { "last_used_at" : { value : now(), cfsqltype : "cf_sql_timestamp" } } );
		} catch ( any e ) {
			// Swallowed on purpose. See above.
		}

		return this;
	}

	function delete( required numeric id ){
		variables.query.from( variables.TABLE ).where( "id", arguments.id ).delete();
		return this;
	}

	core.models.api.ApiToken function toToken( required struct row ){
		var token = wirebox
			.getInstance( "ApiToken@core" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setUserId( arguments.row.user_id )
			.setName( arguments.row.name )
			.setTokenHash( arguments.row.token_hash )
			.setPrefix( arguments.row.prefix )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );

		for ( var field in [ "last_used_at", "expires_at", "revoked_at" ] ) {
			if ( structKeyExists( arguments.row, field ) && !isNull( arguments.row[ field ] ) && len( arguments.row[ field ] ) ) {
				var setter = "set" & replace( field, "_", "", "all" );

				invoke( token, setter, [ arguments.row[ field ] ] );
			}
		}

		return token;
	}

	private function baseQuery(){
		return variables.query.from( variables.TABLE ).select( variables.COLUMNS );
	}

	private struct function nullableDate( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_timestamp",
			null      : isNull( arguments.value ) || !len( arguments.value )
		};
	}

}
