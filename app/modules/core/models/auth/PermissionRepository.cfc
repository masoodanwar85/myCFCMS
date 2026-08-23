/**
 * Persistence for the global permission catalogue.
 *
 * Read-mostly. Rows arrive through migrations — Core's own in Group 2, and each
 * feature module's alongside its own tables — so there is no create/update API
 * here for application code to reach for.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.TABLE   = "permissions";
	variables.COLUMNS = [ "id", "slug", "name", "description", "created_at", "updated_at" ];

	/**
	 * @return Permission, or null when the slug is not in the catalogue.
	 */
	function findBySlug( required string slug ){
		var row = variables.query
			.from( variables.TABLE )
			.select( variables.COLUMNS )
			.where( "slug", arguments.slug )
			.first();

		if ( row.isEmpty() ) {
			return;
		}

		return toPermission( row );
	}

	function findById( required numeric id ){
		var row = variables.query
			.from( variables.TABLE )
			.select( variables.COLUMNS )
			.where( "id", arguments.id )
			.first();

		if ( row.isEmpty() ) {
			return;
		}

		return toPermission( row );
	}

	boolean function existsBySlug( required string slug ){
		return variables.query.from( variables.TABLE ).where( "slug", arguments.slug ).exists();
	}

	array function findAll(){
		return variables.query
			.from( variables.TABLE )
			.select( variables.COLUMNS )
			.orderBy( "slug" )
			.get()
			.map( ( row ) => toPermission( row ) );
	}

	/**
	 * Resolve many slugs at once.
	 *
	 * Used when granting a set of permissions to a role, so seeding a role is
	 * one lookup rather than one per slug.
	 *
	 * @return A `{ slug : id }` struct, containing only slugs that exist.
	 */
	struct function findIdsBySlugs( required array slugs ){
		var ids = {};

		if ( arguments.slugs.isEmpty() ) {
			return ids;
		}

		variables.query
			.from( variables.TABLE )
			.select( [ "id", "slug" ] )
			.whereIn( "slug", arguments.slugs )
			.get()
			.each( ( row ) => {
				ids[ row.slug ] = row.id;
			} );

		return ids;
	}

	core.models.auth.Permission function toPermission( required struct row ){
		return wirebox
			.getInstance( "Permission@core" )
			.setId( arguments.row.id )
			.setSlug( arguments.row.slug )
			.setName( arguments.row.name )
			.setDescription( arguments.row.description ?: "" )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

}
