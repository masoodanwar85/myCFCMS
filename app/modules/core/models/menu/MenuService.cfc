/**
 * A site's editable navigation.
 *
 * Owns three things: the menus themselves, the rules about what makes a valid
 * item, and the resolution that turns a stored link into an address at render
 * time.
 *
 * Everything is scoped by site. A menu id alone is never enough to change
 * anything — the caller must also say which site it believes the menu belongs
 * to, and a mismatch is an error rather than a silent no-op. That is the same
 * bargain the rest of the CMS makes, and it is what stops a guessed id in a
 * form post from reaching another tenant's navigation.
 */
component singleton accessors="true" {

	property name="wirebox"         inject="wirebox";
	property name="menuRepository"  inject="MenuRepository@core";
	property name="siteRepository"  inject="SiteRepository@core";
	property name="linkTargets"     inject="LinkTargetRegistry@core";
	property name="slugifier"       inject="Slugifier@core";
	property name="log"             inject="logbox:logger:{this}";

	// The menu a theme renders in the header unless it asks for another.
	this.PRIMARY = "primary";

	// One level of children. Deeper menus are a design problem rather than a
	// data one: a theme has to render them, and almost none do it well.
	variables.MAX_DEPTH = 2;

	variables.LINK_TYPES = "url,content";
	variables.TARGETS    = ",_blank";

	/* ------------------------------------------------------------- menus */

	/**
	 * @throws Menu.SiteNotFound
	 * @throws Menu.InvalidMenu
	 * @throws Menu.SlugAlreadyExists
	 */
	core.models.menu.Menu function createMenu(
		required numeric siteId,
		required string name,
		string slug = ""
	){
		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Menu.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		// Locals named for what they are rather than after the arguments they
		// come from: ACF refuses to compile a `var` that shadows an argument.
		var menuName = trim( arguments.name );

		if ( !len( menuName ) ) {
			throw( type = "Menu.InvalidMenu", message = "A menu needs a name." );
		}

		var menuSlug = len( trim( arguments.slug ) )
			? slugifier.slugify( arguments.slug )
			: slugifier.slugify( menuName );

		if ( !len( menuSlug ) ) {
			throw( type = "Menu.InvalidMenu", message = "[#menuName#] does not produce a usable menu slug." );
		}

		if ( menuRepository.menuSlugExists( arguments.siteId, menuSlug ) ) {
			throw( type = "Menu.SlugAlreadyExists", message = "This site already has a menu called [#menuSlug#]." );
		}

		return menuRepository.createMenu(
			wirebox.getInstance( "Menu@core" )
				.setSiteId( arguments.siteId )
				.setName( menuName )
				.setSlug( menuSlug )
		);
	}

	/**
	 * @throws Menu.NotFound
	 */
	core.models.menu.Menu function renameMenu(
		required numeric menuId,
		required numeric siteId,
		required string name
	){
		var menu     = requireMenu( arguments.menuId, arguments.siteId );
		var menuName = trim( arguments.name );

		if ( !len( menuName ) ) {
			throw( type = "Menu.InvalidMenu", message = "A menu needs a name." );
		}

		return menuRepository.updateMenu( menu.setName( menuName ) );
	}

	function deleteMenu( required numeric menuId, required numeric siteId ){
		var menu = requireMenu( arguments.menuId, arguments.siteId );

		menuRepository.deleteMenu( menu.getId() );

		return this;
	}

	array function getMenus( required numeric siteId ){
		return menuRepository.findMenusBySiteId( arguments.siteId );
	}

	function getMenu( required numeric menuId, required numeric siteId ){
		var menu = menuRepository.findMenuById( arguments.menuId );

		if ( isNull( menu ) || menu.getSiteId() != arguments.siteId ) {
			return;
		}

		return menu;
	}

	/* ------------------------------------------------------------- items */

	/**
	 * Add an item.
	 *
	 * @linkType    "content" or "url".
	 * @contentType The owning module's key, for a content link.
	 * @contentId   The row it points at, for a content link.
	 * @url         The address, for a url link.
	 * @parentId    An item in the same menu, to nest beneath.
	 *
	 * @throws Menu.NotFound
	 * @throws Menu.InvalidItem
	 * @throws Menu.TooDeep
	 */
	core.models.menu.MenuItem function addItem(
		required numeric menuId,
		required numeric siteId,
		required string label,
		string linkType    = "url",
		string contentType = "",
		numeric contentId  = 0,
		string url         = "",
		numeric parentId   = 0,
		string target      = ""
	){
		var menu = requireMenu( arguments.menuId, arguments.siteId );
		var text = trim( arguments.label );

		if ( !len( text ) ) {
			throw( type = "Menu.InvalidItem", message = "A menu item needs a label." );
		}

		if ( !listFindNoCase( variables.LINK_TYPES, arguments.linkType ) ) {
			throw( type = "Menu.InvalidItem", message = "[#arguments.linkType#] is not a kind of link." );
		}

		if ( !listFindNoCase( variables.TARGETS, arguments.target ) && len( arguments.target ) ) {
			throw( type = "Menu.InvalidItem", message = "[#arguments.target#] is not a link target." );
		}

		var item = wirebox
			.getInstance( "MenuItem@core" )
			.setMenuId( menu.getId() )
			.setSiteId( arguments.siteId )
			.setLabel( text )
			.setTarget( arguments.target );

		applyLink( item, arguments.linkType, arguments.contentType, arguments.contentId, arguments.url );

		if ( val( arguments.parentId ) ) {
			var parent = requireItem( arguments.parentId, arguments.siteId );

			if ( parent.getMenuId() != menu.getId() ) {
				throw( type = "Menu.InvalidItem", message = "A menu item cannot sit under an item in another menu." );
			}

			// Depth is capped at the point of insertion, not at render time: a
			// theme should never receive a shape it has no markup for.
			if ( val( parent.getParentId() ?: 0 ) ) {
				throw(
					type    = "Menu.TooDeep",
					message = "Menus go #variables.MAX_DEPTH# levels deep. [#parent.getLabel()#] is already a sub-item."
				);
			}

			item.setParentId( parent.getId() );
		}

		item.setSortOrder( menuRepository.nextSortOrder( menu.getId(), item.getParentId() ?: 0 ) );

		return menuRepository.createItem( item );
	}

	/**
	 * @throws Menu.NotFound
	 * @throws Menu.InvalidItem
	 */
	core.models.menu.MenuItem function updateItem(
		required numeric itemId,
		required numeric siteId,
		string label,
		string linkType,
		string contentType,
		numeric contentId,
		string url,
		string target
	){
		var item = requireItem( arguments.itemId, arguments.siteId );

		if ( !isNull( arguments.label ) ) {
			var text = trim( arguments.label );

			if ( !len( text ) ) {
				throw( type = "Menu.InvalidItem", message = "A menu item needs a label." );
			}

			item.setLabel( text );
		}

		if ( !isNull( arguments.target ) ) {
			if ( len( arguments.target ) && !listFindNoCase( variables.TARGETS, arguments.target ) ) {
				throw( type = "Menu.InvalidItem", message = "[#arguments.target#] is not a link target." );
			}

			item.setTarget( arguments.target );
		}

		if ( !isNull( arguments.linkType ) ) {
			if ( !listFindNoCase( variables.LINK_TYPES, arguments.linkType ) ) {
				throw( type = "Menu.InvalidItem", message = "[#arguments.linkType#] is not a kind of link." );
			}

			applyLink(
				item,
				arguments.linkType,
				arguments.contentType ?: "",
				val( arguments.contentId ?: 0 ),
				arguments.url ?: ""
			);
		}

		return menuRepository.updateItem( item );
	}

	function deleteItem( required numeric itemId, required numeric siteId ){
		var item = requireItem( arguments.itemId, arguments.siteId );

		menuRepository.deleteItem( item.getId() );

		return this;
	}

	/**
	 * Move an item one place up or down among its siblings.
	 *
	 * Swapping with the neighbour rather than renumbering the whole level: it
	 * is two writes instead of N, and it cannot renumber an item that another
	 * editor moved in between.
	 *
	 * @direction "up" or "down".
	 */
	function moveItem( required numeric itemId, required numeric siteId, required string direction ){
		var item     = requireItem( arguments.itemId, arguments.siteId );
		var siblings = menuRepository
			.findItemsByMenuId( item.getMenuId() )
			.filter( ( candidate ) => val( candidate.getParentId() ?: 0 ) == val( item.getParentId() ?: 0 ) );

		var position = 0;

		for ( var i = 1; i <= siblings.len(); i++ ) {
			if ( siblings[ i ].getId() == item.getId() ) {
				position = i;
				break;
			}
		}

		var swapWith = lCase( arguments.direction ) == "up" ? position - 1 : position + 1;

		// Already at the end it is being asked to move towards. Not an error:
		// the admin shows both arrows on every row, and pressing the one that
		// cannot do anything should do nothing.
		if ( !position || swapWith < 1 || swapWith > siblings.len() ) {
			return this;
		}

		var other = siblings[ swapWith ];
		var mine  = item.getSortOrder();

		menuRepository.updateItem( item.setSortOrder( other.getSortOrder() ) );
		menuRepository.updateItem( other.setSortOrder( mine ) );

		return this;
	}

	/* --------------------------------------------------------- rendering */

	/**
	 * A menu as a theme should render it: a tree, resolved, with dead links
	 * already removed.
	 *
	 * Returns an empty array when the site has no such menu, which is what lets
	 * the caller fall back to the module-contributed navigation.
	 */
	array function getRenderableMenu( required numeric siteId, string slug = this.PRIMARY ){
		var menu = menuRepository.findMenuBySlug( arguments.siteId, arguments.slug );

		if ( isNull( menu ) ) {
			return [];
		}

		return buildTree( resolveAll( arguments.siteId, menuRepository.findItemsByMenuId( menu.getId() ) ) );
	}

	/**
	 * The same tree, but for the admin: nothing is dropped, and an item whose
	 * content has gone is flagged rather than hidden. An editor needs to see the
	 * broken item in order to fix it.
	 */
	array function getEditableMenu( required numeric menuId, required numeric siteId ){
		var menu = requireMenu( arguments.menuId, arguments.siteId );

		return buildTree(
			resolveAll( arguments.siteId, menuRepository.findItemsByMenuId( menu.getId() ) ),
			false
		);
	}

	array function getLinkTargets( required numeric siteId ){
		return linkTargets.getTargetsFor( arguments.siteId );
	}

	/**
	 * Forget every menu item pointing at a piece of content that has been
	 * deleted. Called by the module that owns it.
	 */
	numeric function forgetContent(
		required numeric siteId,
		required string contentType,
		required numeric contentId
	){
		return menuRepository.deleteItemsForContent( arguments.siteId, arguments.contentType, arguments.contentId );
	}

	/* --------------------------------------------------------- internals */

	/**
	 * Give an item its address, and validate the pairing.
	 *
	 * A content link with no type, or a URL link with no URL, is rejected here
	 * rather than being stored and failing silently at render time.
	 */
	private function applyLink(
		required any item,
		required string linkType,
		string contentType = "",
		numeric contentId  = 0,
		string url         = ""
	){
		if ( lCase( arguments.linkType ) == "content" ) {
			// Only the type is compulsory. An id of 0 is a real answer for a
			// module's singleton — the blog archive is "the" archive, with no
			// row of its own — and requiring a truthy id would make those
			// unlinkable while looking like a validation rule.
			if ( !len( trim( arguments.contentType ) ) ) {
				throw( type = "Menu.InvalidItem", message = "A content link needs something to point at." );
			}

			arguments.item
				.setLinkType( "content" )
				.setContentType( trim( arguments.contentType ) )
				.setContentId( val( arguments.contentId ) )
				.setUrl( "" );

			return arguments.item;
		}

		var address = trim( arguments.url );

		if ( !len( address ) ) {
			throw( type = "Menu.InvalidItem", message = "A link needs an address." );
		}

		// `javascript:` in a menu is a stored cross-site scripting hole that
		// every visitor sees on every page. Anything that is not plainly a web
		// address, a mail link or a site-relative path is refused outright.
		if ( !reFindNoCase( "^(https?://|mailto:|tel:|/|##)", address ) ) {
			throw(
				type    = "Menu.InvalidItem",
				message = "A link must start with http://, https://, mailto:, tel:, / or ##."
			);
		}

		arguments.item
			.setLinkType( "url" )
			.setUrl( address )
			.setContentType( "" )
			.setContentId( 0 );

		return arguments.item;
	}

	/**
	 * Turn stored links into addresses.
	 *
	 * A content link is asked of the owning module every time. That is a read
	 * per distinct target, which for a menu is a handful — and it is what makes
	 * the menu correct after a rename rather than merely usually correct.
	 */
	private array function resolveAll( required numeric siteId, required array items ){
		var cache = {};

		for ( var item in arguments.items ) {
			if ( !item.isContentLink() ) {
				item.setHref( item.getUrl() ).setIsAvailable( true );
				continue;
			}

			var key = item.getContentType() & "/" & item.getContentId();

			if ( !structKeyExists( cache, key ) ) {
				var resolved = linkTargets.resolve( arguments.siteId, item.getContentType(), item.getContentId() );
				cache[ key ] = isNull( resolved ) ? "" : resolved;
			}

			if ( isSimpleValue( cache[ key ] ) ) {
				// Nothing owns this any more.
				item.setHref( "" ).setIsAvailable( false );
				continue;
			}

			item.setHref( "/" & cache[ key ].path ).setIsAvailable( true );
		}

		return arguments.items;
	}

	/**
	 * Flat list to two-level tree.
	 *
	 * @dropUnavailable Leave out items whose content has gone. True for the
	 *                  public site, false for the admin.
	 */
	private array function buildTree( required array items, boolean dropUnavailable = true ){
		var byId  = {};
		var roots = [];

		for ( var item in arguments.items ) {
			if ( arguments.dropUnavailable && !item.getIsAvailable() ) {
				continue;
			}

			item.setChildren( [] );
			byId[ item.getId() ] = item;
		}

		for ( var item in arguments.items ) {
			if ( !structKeyExists( byId, item.getId() ) ) {
				continue;
			}

			var parentId = val( item.getParentId() ?: 0 );

			// A child whose parent was dropped is dropped with it, rather than
			// being promoted to the top level where nobody put it.
			if ( parentId && structKeyExists( byId, parentId ) ) {
				byId[ parentId ].getChildren().append( item );
			} else if ( !parentId ) {
				roots.append( item );
			}
		}

		return roots;
	}

	private function requireMenu( required numeric menuId, required numeric siteId ){
		var menu = menuRepository.findMenuById( arguments.menuId );

		if ( isNull( menu ) || menu.getSiteId() != arguments.siteId ) {
			throw( type = "Menu.NotFound", message = "No menu with id [#arguments.menuId#] on this site." );
		}

		return menu;
	}

	private function requireItem( required numeric itemId, required numeric siteId ){
		var item = menuRepository.findItemById( arguments.itemId );

		if ( isNull( item ) || item.getSiteId() != arguments.siteId ) {
			throw( type = "Menu.NotFound", message = "No menu item with id [#arguments.itemId#] on this site." );
		}

		return item;
	}

}
