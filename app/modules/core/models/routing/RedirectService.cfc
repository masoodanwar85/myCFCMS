/**
 * Keeps old URLs working after content moves.
 *
 * Modules call `record()` when a path changes; Core's front controller consults
 * `find()` before serving a 404.
 *
 * The interesting part is not storing a row — it is not accumulating a maze.
 * Recording A -> B does three things:
 *
 *   1. refuses a self-redirect,
 *   2. repoints anything that already pointed at A so it now points at B,
 *      which collapses chains instead of following them at request time,
 *   3. removes any redirect *from* B, because B now resolves on its own and a
 *      redirect away from it would send visitors in a circle.
 *
 * Together those keep every redirect exactly one hop.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "site_redirects";
	variables.COLUMNS = [ "id", "site_id", "from_path", "to_path", "status_code", "created_at", "updated_at" ];

	/**
	 * Remember that `fromPath` has become `toPath` on this site.
	 *
	 * @statusCode 301 for a permanent move, 302 when it may move back.
	 */
	function record(
		required numeric siteId,
		required string fromPath,
		required string toPath,
		numeric statusCode = 301
	){
		var from = normalize( arguments.fromPath );
		var to   = normalize( arguments.toPath );

		// Nothing moved, or the paths are unusable.
		if ( !len( from ) || from == to ) {
			return this;
		}

		var stamp = now();

		// Order matters here, and getting it wrong is not theoretical: renaming
		// a page back to a name it held before turned an existing row into a
		// self-redirect and the write failed outright.
		//
		// 1. The destination resolves on its own now, so any redirect *away*
		//    from it is stale. Removing these first also stops step 2 turning
		//    one of them into a redirect to itself.
		variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "from_path", to )
			.delete();

		// 2. Anything that pointed at the old path now points at the new one,
		//    so a visitor never follows two hops and repeated renames cannot
		//    build a chain.
		variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "to_path", from )
			.update( { "to_path" : to, "updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" } } );

		// 3. The old path may already have been redirected once before.
		variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "from_path", from )
			.delete();

		variables.query
			.from( variables.TABLE )
			.insert( {
				"site_id"     : arguments.siteId,
				"from_path"   : from,
				"to_path"     : to,
				"status_code" : arguments.statusCode,
				"created_at"  : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"updated_at"  : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		return this;
	}

	/**
	 * Record a move for a whole subtree.
	 *
	 * Renaming a parent moves every descendant, and each of those URLs was just
	 * as publishable as the parent's.
	 *
	 * @moves An array of `{ from : "...", to : "..." }`.
	 */
	function recordAll( required numeric siteId, required array moves ){
		for ( var move in arguments.moves ) {
			record( arguments.siteId, move.from ?: "", move.to ?: "" );
		}

		return this;
	}

	/**
	 * Where should this path send a visitor?
	 *
	 * @return `{ toPath, statusCode }`, or null when the path has no redirect.
	 */
	function find( required numeric siteId, required string path ){
		var row = variables.query
			.from( variables.TABLE )
			.select( [ "to_path", "status_code" ] )
			.where( "site_id", arguments.siteId )
			.where( "from_path", normalize( arguments.path ) )
			.first();

		if ( row.isEmpty() ) {
			return;
		}

		return { "toPath" : row.to_path, "statusCode" : row.status_code };
	}

	array function findForSite( required numeric siteId ){
		return variables.query
			.from( variables.TABLE )
			.select( variables.COLUMNS )
			.where( "site_id", arguments.siteId )
			.orderBy( "from_path" )
			.get();
	}

	function forget( required numeric siteId, required string fromPath ){
		variables.query
			.from( variables.TABLE )
			.where( "site_id", arguments.siteId )
			.where( "from_path", normalize( arguments.fromPath ) )
			.delete();

		return this;
	}

	/**
	 * Paths are stored without surrounding slashes, matching how the front
	 * controller normalises an incoming request.
	 */
	string function normalize( required string path ){
		return reReplace( lCase( trim( arguments.path ) ), "^/+|/+$", "", "all" );
	}

}
