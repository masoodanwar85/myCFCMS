/**
 * How the navigation partial classes its links.
 *
 * `dropdown-toggle` marks a link that opens a submenu; `dropdown-item` marks
 * one that navigates. Both the stylesheet and the mobile menu script select on
 * that distinction, so getting it wrong does not throw — it produces a menu
 * that silently will not open.
 *
 * `_link.cfm` used to decide by DEPTH: level one was always a toggle, anything
 * below it always an item. On a two-level menu that happens to look right. On
 * this site's four-level menu it meant a third-level parent was classed as a
 * leaf, so tapping it on a phone navigated away instead of revealing its
 * children, and the caret rule for nested parents matched nothing.
 *
 * Rendered through a real request rather than by including the partial: the
 * recursion depends on the caller's `local` scope, and a spec that set that up
 * by hand would be testing its own scaffolding.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-nav-";

	function beforeAll(){
		super.beforeAll();
		variables.sites    = getInstance( "SiteService@core" );
		variables.pages    = getInstance( "PageService@pages" );
		variables.menus    = getInstance( "MenuService@core" );
		variables.settings = getInstance( "SiteSettingsRepository@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The rendered navigation", function(){

			beforeEach( function(){
				setup();
				variables.html = render( "/" );
			} );

			it( "renders the whole tree, three levels deep", function(){
				expect( html ).toInclude( "Level One" );
				expect( html ).toInclude( "Level Two" );
				expect( html ).toInclude( "Level Three" );
			} );

			/**
			 * The invariant. Every parent is a toggle and nothing else is, at
			 * any depth — which is what both the CSS and the mobile script
			 * assume.
			 */
			it( "gives every item with children a toggle, and only those", function(){
				expect( occurrences( html, "dropdown-toggle" ) )
					.toBe( occurrences( html, "has-children" ) );
			} );

			it( "classes a nested parent as a toggle, not as a leaf", function(){
				expect( html ).toMatch( 'class="nav-link dropdown-toggle"[^>]*>Level Two' );
			} );

			it( "classes a top-level leaf as an item, not as a toggle", function(){
				expect( html ).toMatch( 'class="nav-link dropdown-item"[^>]*>Standalone' );
			} );

			it( "classes the deepest item as a leaf", function(){
				expect( html ).toMatch( 'class="nav-link dropdown-item"[^>]*>Level Three' );
			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private numeric function occurrences( required string haystack, required string needle ){
		var without = replace( arguments.haystack, arguments.needle, "", "all" );

		return int( ( len( arguments.haystack ) - len( without ) ) / len( arguments.needle ) );
	}

	private string function render( required string uri ){
		var event = this.request(
			route   = arguments.uri,
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.site = sites.createSite( name = "Nav Render", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );

		var home = pages.createPage( siteId = site.getId(), title = "Home", slug = "home" );
		pages.publishPage( home.getId() );
		settings.put( site.getId(), "pages.homePageId", home.getId() );

		var menu = menus.createMenu( siteId = site.getId(), name = "Primary", slug = "primary" );

		var one = menus.addItem(
			menuId = menu.getId(), siteId = site.getId(),
			label  = "Level One", linkType = "url", url = "/one"
		);

		var two = menus.addItem(
			menuId = menu.getId(), siteId = site.getId(),
			label  = "Level Two", linkType = "url", url = "/one/two",
			parentId = one.getId()
		);

		menus.addItem(
			menuId = menu.getId(), siteId = site.getId(),
			label  = "Level Three", linkType = "url", url = "/one/two/three",
			parentId = two.getId()
		);

		// Top-level items with no children, to catch the opposite mistake.
		//
		// There are TWO of them on purpose. With one, the depth-based bug
		// produced two toggles and two parents — the counts matched by
		// coincidence and the invariant below passed while the menu was broken.
		// A second childless top-level item breaks the tie: the old code
		// classes three links as toggles where only two items have children.
		menus.addItem(
			menuId = menu.getId(), siteId = site.getId(),
			label  = "Standalone", linkType = "url", url = "/standalone"
		);

		menus.addItem(
			menuId = menu.getId(), siteId = site.getId(),
			label  = "Standalone Two", linkType = "url", url = "/standalone-two"
		);
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
