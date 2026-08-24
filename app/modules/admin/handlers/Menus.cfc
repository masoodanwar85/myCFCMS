/**
 * Editing a site's navigation.
 *
 * One permission guards the lot. Splitting "create a menu" from "add an item"
 * would be precision without meaning: anyone who can do either can change what
 * every visitor sees on every page.
 *
 * Every action passes `prc.currentSite.getId()` to the service, which refuses
 * a menu or item belonging to another tenant. Nothing here trusts an id from
 * the URL on its own.
 */
component extends="core.models.security.SecuredHandler" {

	property name="menuService" inject="MenuService@core";
	property name="navigation"  inject="NavigationService@core";

	variables.permissions = {
		"index"      : "menus.manage",
		"edit"       : "menus.manage",
		"create"     : "menus.manage",
		"remove"     : "menus.manage",
		"rename"     : "menus.manage",
		"addItem"    : "menus.manage",
		"updateItem" : "menus.manage",
		"removeItem" : "menus.manage",
		"moveItem"   : "menus.manage",
		"$every"     : "menus.manage"
	};

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		prc.pageTitle = "Menus";
		prc.menus     = menuService.getMenus( siteId );

		// So the screen can say plainly which of the two a visitor is seeing
		// rather than leaving an editor to work out why the site does not match
		// what is in front of them.
		prc.usingCurated = navigation.hasCuratedMenu( siteId );

		event.setView( view = "menus/index", module = "admin" );
	}

	function create( event, rc, prc ){
		try {
			var menu = menuService.createMenu(
				siteId = prc.currentSite.getId(),
				name   = rc.name ?: "",
				slug   = rc.slug ?: ""
			);
		} catch ( any e ) {
			return done( "/admin/menus", e.message, "error" );
		}

		return done( "/admin/menus/edit/" & menu.getId(), "Menu created." );
	}

	function edit( event, rc, prc ){
		var siteId = prc.currentSite.getId();
		var menu   = menuService.getMenu( val( rc.id ?: 0 ), siteId );

		if ( isNull( menu ) ) {
			return done( "/admin/menus", "That menu does not exist.", "error" );
		}

		prc.pageTitle = menu.getName();
		prc.menu      = menu;
		// The editable tree keeps items whose content has gone, flagged, so an
		// editor can see and fix what the public site is silently skipping.
		prc.items     = menuService.getEditableMenu( menu.getId(), siteId );
		prc.targets   = menuService.getLinkTargets( siteId );
		prc.parents   = prc.items;

		event.setView( view = "menus/edit", module = "admin" );
	}

	function rename( event, rc, prc ){
		try {
			menuService.renameMenu( val( rc.id ?: 0 ), prc.currentSite.getId(), rc.name ?: "" );
		} catch ( any e ) {
			return done( "/admin/menus/edit/" & val( rc.id ?: 0 ), e.message, "error" );
		}

		return done( "/admin/menus/edit/" & val( rc.id ?: 0 ), "Menu renamed." );
	}

	function remove( event, rc, prc ){
		try {
			menuService.deleteMenu( val( rc.id ?: 0 ), prc.currentSite.getId() );
		} catch ( any e ) {
			return done( "/admin/menus", e.message, "error" );
		}

		return done( "/admin/menus", "Menu deleted. The site is back to its automatic navigation." );
	}

	/**
	 * The form posts one field for the target and this splits it, because a
	 * `<select>` can carry one value and a link needs three: what kind, which
	 * module's content, and which row. The value is `type:id`, or `url` for the
	 * free-text case.
	 */
	function addItem( event, rc, prc ){
		var menuId = val( rc.id ?: 0 );
		var link   = parseTarget( rc.target ?: "" );

		try {
			menuService.addItem(
				menuId      = menuId,
				siteId      = prc.currentSite.getId(),
				label       = rc.label ?: "",
				linkType    = link.linkType,
				contentType = link.contentType,
				contentId   = link.contentId,
				url         = rc.url ?: "",
				parentId    = val( rc.parentId ?: 0 ),
				target      = ( rc.newTab ?: "" ) == "on" ? "_blank" : ""
			);
		} catch ( any e ) {
			return done( "/admin/menus/edit/" & menuId, e.message, "error" );
		}

		return done( "/admin/menus/edit/" & menuId, "Item added." );
	}

	function updateItem( event, rc, prc ){
		var menuId = val( rc.menuId ?: 0 );

		try {
			menuService.updateItem(
				itemId = val( rc.id ?: 0 ),
				siteId = prc.currentSite.getId(),
				label  = rc.label ?: "",
				target = ( rc.newTab ?: "" ) == "on" ? "_blank" : ""
			);
		} catch ( any e ) {
			return done( "/admin/menus/edit/" & menuId, e.message, "error" );
		}

		return done( "/admin/menus/edit/" & menuId, "Item saved." );
	}

	function removeItem( event, rc, prc ){
		var menuId = val( rc.menuId ?: 0 );

		try {
			menuService.deleteItem( val( rc.id ?: 0 ), prc.currentSite.getId() );
		} catch ( any e ) {
			return done( "/admin/menus/edit/" & menuId, e.message, "error" );
		}

		return done( "/admin/menus/edit/" & menuId, "Item removed." );
	}

	function moveItem( event, rc, prc ){
		var menuId = val( rc.menuId ?: 0 );

		try {
			menuService.moveItem(
				itemId    = val( rc.id ?: 0 ),
				siteId    = prc.currentSite.getId(),
				direction = rc.direction ?: "up"
			);
		} catch ( any e ) {
			return done( "/admin/menus/edit/" & menuId, e.message, "error" );
		}

		return done( "/admin/menus/edit/" & menuId );
	}

	/**
	 * `"pages.page:12"` -> a content link. `"url"` -> a free-text address.
	 *
	 * Splitting on the last colon, not the first: a content type may contain
	 * one, and the id never does.
	 */
	private struct function parseTarget( required string value ){
		var raw = trim( arguments.value );

		if ( !len( raw ) || raw == "url" || !find( ":", raw ) ) {
			return { linkType : "url", contentType : "", contentId : 0 };
		}

		var at = len( raw ) - find( ":", reverse( raw ) ) + 1;

		return {
			linkType    : "content",
			contentType : left( raw, at - 1 ),
			contentId   : val( mid( raw, at + 1, len( raw ) ) )
		};
	}

}
