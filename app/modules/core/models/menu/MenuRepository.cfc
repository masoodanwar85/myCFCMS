/**
 * Persistence for menus and their items. Every read is scoped by site.
 */
component singleton extends="core.models.persistence.BaseRepository" {

	variables.MENUS       = "menus";
	variables.ITEMS       = "menu_items";
	variables.MENU_COLS   = [ "id", "site_id", "name", "slug", "created_at", "updated_at" ];
	variables.ITEM_COLS   = [
		"id", "menu_id", "site_id", "parent_id", "label", "link_type",
		"content_type", "content_id", "url", "target", "sort_order",
		"created_at", "updated_at"
	];

	/* ------------------------------------------------------------- menus */

	core.models.menu.Menu function createMenu( required core.models.menu.Menu menu ){
		var stamp = now();

		var result = variables.query
			.from( variables.MENUS )
			.insert( {
				"site_id"    : arguments.menu.getSiteId(),
				"name"       : arguments.menu.getName(),
				"slug"       : arguments.menu.getSlug(),
				"created_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"updated_at" : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.menu.setId( generatedKey( result, variables.MENUS ) );
		arguments.menu.setCreatedAt( stamp );

		return arguments.menu;
	}

	core.models.menu.Menu function updateMenu( required core.models.menu.Menu menu ){
		variables.query
			.from( variables.MENUS )
			.where( "id", arguments.menu.getId() )
			.update( {
				"name"       : arguments.menu.getName(),
				"slug"       : arguments.menu.getSlug(),
				"updated_at" : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return arguments.menu;
	}

	function findMenuById( required numeric id ){
		return toMenuOrNull(
			variables.query.from( variables.MENUS ).select( variables.MENU_COLS ).where( "id", arguments.id ).first()
		);
	}

	function findMenuBySlug( required numeric siteId, required string slug ){
		return toMenuOrNull(
			variables.query
				.from( variables.MENUS )
				.select( variables.MENU_COLS )
				.where( "site_id", arguments.siteId )
				.where( "slug", arguments.slug )
				.first()
		);
	}

	array function findMenusBySiteId( required numeric siteId ){
		return variables.query
			.from( variables.MENUS )
			.select( variables.MENU_COLS )
			.where( "site_id", arguments.siteId )
			.orderBy( "name" )
			.get()
			.map( ( row ) => toMenu( row ) );
	}

	boolean function menuSlugExists( required numeric siteId, required string slug ){
		return variables.query
			.from( variables.MENUS )
			.where( "site_id", arguments.siteId )
			.where( "slug", arguments.slug )
			.exists();
	}

	function deleteMenu( required numeric id ){
		// Items go with it through ON DELETE CASCADE.
		variables.query.from( variables.MENUS ).where( "id", arguments.id ).delete();
		return this;
	}

	/* ------------------------------------------------------------- items */

	core.models.menu.MenuItem function createItem( required core.models.menu.MenuItem item ){
		var stamp = now();

		var result = variables.query
			.from( variables.ITEMS )
			.insert( {
				"menu_id"      : arguments.item.getMenuId(),
				"site_id"      : arguments.item.getSiteId(),
				"parent_id"    : nullableNumber( arguments.item.getParentId() ),
				"label"        : arguments.item.getLabel(),
				"link_type"    : arguments.item.getLinkType(),
				"content_type" : nullableString( arguments.item.getContentType() ),
				// Not `nullableNumber`: that treats 0 as absent, and 0 is the id a
				// module's singleton uses (the blog archive has no row of its own).
				// Null only when this is not a content link at all.
				"content_id"   : contentId( arguments.item ),
				"url"          : nullableString( arguments.item.getUrl() ),
				// Bound explicitly with `null : false`. `target` is NOT NULL with
				// a default of '', and qb infers a null bind from an empty
				// string — which MySQL then rejects outright.
				"target"       : { value : arguments.item.getTarget() ?: "", cfsqltype : "cf_sql_varchar", null : false },
				"sort_order"   : arguments.item.getSortOrder() ?: 0,
				"created_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" },
				"updated_at"   : { value : stamp, cfsqltype : "cf_sql_timestamp" }
			} );

		arguments.item.setId( generatedKey( result, variables.ITEMS ) );
		arguments.item.setCreatedAt( stamp );

		return arguments.item;
	}

	core.models.menu.MenuItem function updateItem( required core.models.menu.MenuItem item ){
		variables.query
			.from( variables.ITEMS )
			.where( "id", arguments.item.getId() )
			.update( {
				"parent_id"    : nullableNumber( arguments.item.getParentId() ),
				"label"        : arguments.item.getLabel(),
				"link_type"    : arguments.item.getLinkType(),
				"content_type" : nullableString( arguments.item.getContentType() ),
				// Not `nullableNumber`: that treats 0 as absent, and 0 is the id a
				// module's singleton uses (the blog archive has no row of its own).
				// Null only when this is not a content link at all.
				"content_id"   : contentId( arguments.item ),
				"url"          : nullableString( arguments.item.getUrl() ),
				"target"       : { value : arguments.item.getTarget() ?: "", cfsqltype : "cf_sql_varchar", null : false },
				"sort_order"   : arguments.item.getSortOrder() ?: 0,
				"updated_at"   : { value : now(), cfsqltype : "cf_sql_timestamp" }
			} );

		return arguments.item;
	}

	function findItemById( required numeric id ){
		var row = variables.query
			.from( variables.ITEMS )
			.select( variables.ITEM_COLS )
			.where( "id", arguments.id )
			.first();

		return row.isEmpty() ? javacast( "null", "" ) : toItem( row );
	}

	/**
	 * Every item in a menu, in the order a theme should render them.
	 *
	 * One query for the whole menu including children: a menu is small, and a
	 * query per level would put the number of round trips in the hands of
	 * whoever edits the navigation.
	 */
	array function findItemsByMenuId( required numeric menuId ){
		return variables.query
			.from( variables.ITEMS )
			.select( variables.ITEM_COLS )
			.where( "menu_id", arguments.menuId )
			.orderBy( "sort_order" )
			.orderBy( "id" )
			.get()
			.map( ( row ) => toItem( row ) );
	}

	numeric function countItemsInMenu( required numeric menuId ){
		return variables.query.from( variables.ITEMS ).where( "menu_id", arguments.menuId ).count();
	}

	/**
	 * The next free position at one level, so a new item lands at the end
	 * rather than colliding with an existing order.
	 */
	numeric function nextSortOrder( required numeric menuId, parentId ){
		var q = variables.query
			.from( variables.ITEMS )
			.selectRaw( "COALESCE(MAX(sort_order), -1) + 1 AS next" )
			.where( "menu_id", arguments.menuId );

		if ( isNull( arguments.parentId ) || !val( arguments.parentId ) ) {
			q.whereNull( "parent_id" );
		} else {
			q.where( "parent_id", arguments.parentId );
		}

		var row = q.first();

		return row.isEmpty() ? 0 : val( row.next );
	}

	function deleteItem( required numeric id ){
		variables.query.from( variables.ITEMS ).where( "id", arguments.id ).delete();
		return this;
	}

	/**
	 * Drop every menu item across the installation that pointed at a piece of
	 * content that no longer exists.
	 *
	 * Called when a module reports a deletion. Without it an item lingers,
	 * resolves to nothing, and is silently skipped on every render — invisible
	 * on the site and confusing in the admin.
	 */
	numeric function deleteItemsForContent(
		required numeric siteId,
		required string contentType,
		required numeric contentId
	){
		return variables.query
			.from( variables.ITEMS )
			.where( "site_id", arguments.siteId )
			.where( "link_type", "content" )
			.where( "content_type", arguments.contentType )
			.where( "content_id", arguments.contentId )
			.delete();
	}

	/* ---------------------------------------------------------- mapping */

	core.models.menu.Menu function toMenu( required struct row ){
		return wirebox
			.getInstance( "Menu@core" )
			.setId( arguments.row.id )
			.setSiteId( arguments.row.site_id )
			.setName( arguments.row.name )
			.setSlug( arguments.row.slug )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );
	}

	core.models.menu.MenuItem function toItem( required struct row ){
		var item = wirebox
			.getInstance( "MenuItem@core" )
			.setId( arguments.row.id )
			.setMenuId( arguments.row.menu_id )
			.setSiteId( arguments.row.site_id )
			.setLabel( arguments.row.label )
			.setLinkType( arguments.row.link_type )
			.setUrl( arguments.row.url ?: "" )
			.setTarget( arguments.row.target ?: "" )
			.setSortOrder( arguments.row.sort_order )
			.setCreatedAt( arguments.row.created_at )
			.setUpdatedAt( arguments.row.updated_at );

		if ( hasValue( arguments.row, "parent_id" ) ) {
			item.setParentId( arguments.row.parent_id );
		}
		if ( hasValue( arguments.row, "content_type" ) ) {
			item.setContentType( arguments.row.content_type );
		}
		// `hasValue` checks length, not truthiness: a stored `content_id` of 0
		// is a module singleton, not a missing value.
		if ( hasValue( arguments.row, "content_id" ) ) {
			item.setContentId( arguments.row.content_id );
		}

		return item;
	}

	private function toMenuOrNull( required struct row ){
		return arguments.row.isEmpty() ? javacast( "null", "" ) : toMenu( arguments.row );
	}

	private boolean function hasValue( required struct row, required string key ){
		return structKeyExists( arguments.row, arguments.key )
			&& !isNull( arguments.row[ arguments.key ] )
			&& len( arguments.row[ arguments.key ] );
	}

	private struct function contentId( required any item ){
		var isContent = arguments.item.isContentLink();

		return {
			value     : isContent ? val( arguments.item.getContentId() ?: 0 ) : "",
			cfsqltype : "cf_sql_bigint",
			null      : !isContent
		};
	}

	private struct function nullableNumber( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_bigint",
			null      : isNull( arguments.value ) || !val( arguments.value )
		};
	}

	private struct function nullableString( value ){
		return {
			value     : isNull( arguments.value ) ? "" : arguments.value,
			cfsqltype : "cf_sql_varchar",
			null      : isNull( arguments.value ) || !len( arguments.value )
		};
	}

}
