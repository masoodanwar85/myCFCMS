/**
 * Editable navigation.
 *
 * Two things carry most of the weight here. The first is tenant isolation: a
 * menu id in a form post must never reach another site's navigation. The second
 * is what happens when a menu points at content that has moved or gone — the
 * whole reason an item stores *what* it links to rather than a URL.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-mn-";

	function beforeAll(){
		super.beforeAll();
		variables.menus  = getInstance( "MenuService@core" );
		variables.nav    = getInstance( "NavigationService@core" );
		variables.sites  = getInstance( "SiteService@core" );
		variables.pages  = getInstance( "PageService@pages" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Menus", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "creating one", function(){

				it( "derives a slug from the name", function(){
					var menu = menus.createMenu( siteId = site.getId(), name = "Footer Links" );

					expect( menu.getSlug() ).toBe( "footer-links" );

					menus.deleteMenu( menu.getId(), site.getId() );
				} );

				it( "refuses a duplicate slug on one site", function(){
					expect( function(){
						menus.createMenu( siteId = site.getId(), name = "Primary", slug = "primary" );
					} ).toThrow( type = "Menu.SlugAlreadyExists" );
				} );

				it( "allows the same slug on another site", function(){
					var other = menus.createMenu( siteId = otherSite.getId(), name = "Primary", slug = "primary" );

					expect( other.getSlug() ).toBe( "primary" );
				} );

				it( "refuses an unknown site", function(){
					expect( function(){
						menus.createMenu( siteId = 987654321, name = "Primary" );
					} ).toThrow( type = "Menu.SiteNotFound" );
				} );

				it( "rejects a name that yields no slug", function(){
					expect( function(){
						menus.createMenu( siteId = site.getId(), name = "!!!" );
					} ).toThrow( type = "Menu.InvalidMenu" );
				} );

			} );

			describe( "tenant isolation", function(){

				it( "refuses to read another site's menu", function(){
					expect( isNull( menus.getMenu( menu.getId(), otherSite.getId() ) ) ).toBeTrue();
				} );

				it( "refuses to add an item to another site's menu", function(){
					expect( function(){
						menus.addItem(
							menuId   = menu.getId(),
							siteId   = otherSite.getId(),
							label    = "Sneaky",
							linkType = "url",
							url      = "/x"
						);
					} ).toThrow( type = "Menu.NotFound" );
				} );

				it( "refuses to delete another site's menu", function(){
					expect( function(){
						menus.deleteMenu( menu.getId(), otherSite.getId() );
					} ).toThrow( type = "Menu.NotFound" );
				} );

			} );

			describe( "what an item may link to", function(){

				it( "refuses a javascript: URL", function(){
					// Stored XSS on every page of the site if this ever passes.
					expect( function(){
						menus.addItem( menuId = menu.getId(), siteId = site.getId(),
							label = "Bad", linkType = "url", url = "javascript:alert(1)" );
					} ).toThrow( type = "Menu.InvalidItem" );
				} );

				it( "refuses a data: URL", function(){
					expect( function(){
						menus.addItem( menuId = menu.getId(), siteId = site.getId(),
							label = "Bad", linkType = "url", url = "data:text/html,<script>alert(1)</script>" );
					} ).toThrow( type = "Menu.InvalidItem" );
				} );

				it( "accepts the schemes a menu legitimately needs", function(){
					for ( var address in [ "https://example.com", "http://example.com", "/about", "##section", "mailto:a@b.test", "tel:+441234" ] ) {
						var item = menus.addItem( menuId = menu.getId(), siteId = site.getId(),
							label = "Link", linkType = "url", url = address );

						expect( item.getUrl() ).toBe( address );

						menus.deleteItem( item.getId(), site.getId() );
					}
				} );

				it( "refuses an empty label", function(){
					expect( function(){
						menus.addItem( menuId = menu.getId(), siteId = site.getId(),
							label = "  ", linkType = "url", url = "/x" );
					} ).toThrow( type = "Menu.InvalidItem" );
				} );

				it( "accepts a content link whose id is zero", function(){
					// A module singleton — "the blog archive" — has no row of
					// its own, and 0 is a real id for it rather than a missing one.
					var item = menus.addItem( menuId = menu.getId(), siteId = site.getId(),
						label = "Journal", linkType = "content", contentType = "blog.archive", contentId = 0 );

					expect( item.isContentLink() ).toBeTrue();
					expect( item.getContentId() ).toBe( 0 );

					menus.deleteItem( item.getId(), site.getId() );
				} );

			} );

			describe( "structure", function(){

				it( "nests one level", function(){
					var parent = addUrlItem( "Parent", "/parent" );
					var child  = menus.addItem( menuId = menu.getId(), siteId = site.getId(),
						label = "Child", linkType = "url", url = "/child", parentId = parent.getId() );

					var tree = menus.getRenderableMenu( site.getId(), "primary" );
					var found = tree.filter( ( i ) => i.getLabel() == "Parent" );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].getChildren().len() ).toBe( 1 );
					expect( found[ 1 ].getChildren()[ 1 ].getLabel() ).toBe( "Child" );

					menus.deleteItem( parent.getId(), site.getId() );
				} );

				it( "refuses a third level", function(){
					var parent = addUrlItem( "P", "/p" );
					var child  = menus.addItem( menuId = menu.getId(), siteId = site.getId(),
						label = "C", linkType = "url", url = "/c", parentId = parent.getId() );

					expect( function(){
						menus.addItem( menuId = menu.getId(), siteId = site.getId(),
							label = "GC", linkType = "url", url = "/gc", parentId = child.getId() );
					} ).toThrow( type = "Menu.TooDeep" );

					menus.deleteItem( parent.getId(), site.getId() );
				} );

				it( "deletes children with their parent", function(){
					var parent = addUrlItem( "P2", "/p2" );
					menus.addItem( menuId = menu.getId(), siteId = site.getId(),
						label = "C2", linkType = "url", url = "/c2", parentId = parent.getId() );

					menus.deleteItem( parent.getId(), site.getId() );

					// A child promoted to the top level would appear somewhere
					// nobody put it.
					var labels = menus.getRenderableMenu( site.getId() ).map( ( i ) => i.getLabel() );

					expect( labels ).notToInclude( "C2" );
				} );

				it( "swaps an item with its neighbour", function(){
					var first  = addUrlItem( "First", "/1" );
					var second = addUrlItem( "Second", "/2" );

					menus.moveItem( second.getId(), site.getId(), "up" );

					var labels = menus.getRenderableMenu( site.getId() ).map( ( i ) => i.getLabel() );
					var a = labels.find( "First" );
					var b = labels.find( "Second" );

					expect( b ).toBeLT( a );

					menus.deleteItem( first.getId(), site.getId() );
					menus.deleteItem( second.getId(), site.getId() );
				} );

				it( "does nothing when asked to move past the end", function(){
					var only = addUrlItem( "Only", "/only" );

					// Both arrows show on every row; the one that cannot act
					// should do nothing rather than error.
					menus.moveItem( only.getId(), site.getId(), "up" );
					menus.moveItem( only.getId(), site.getId(), "down" );

					expect( menus.getRenderableMenu( site.getId() ).len() ).toBeGTE( 1 );

					menus.deleteItem( only.getId(), site.getId() );
				} );

			} );

			describe( "links that point at content", function(){

				it( "follows the page when it is renamed", function(){
					var item = menus.addItem( menuId = menu.getId(), siteId = site.getId(),
						label = "About", linkType = "content", contentType = "pages.page", contentId = about.getId() );

					expect( hrefOf( "About" ) ).toBe( "/about" );

					pages.updatePage( pageId = about.getId(), slug = "about-us" );

					// The whole reason an item stores the target rather than
					// the address.
					expect( hrefOf( "About" ) ).toBe( "/about-us" );

					pages.updatePage( pageId = about.getId(), slug = "about" );
					menus.deleteItem( item.getId(), site.getId() );
				} );

				it( "drops an item whose page is unpublished, without hiding it from the editor", function(){
					var item = menus.addItem( menuId = menu.getId(), siteId = site.getId(),
						label = "Hidden", linkType = "content", contentType = "pages.page", contentId = about.getId() );

					pages.unpublishPage( about.getId() );

					var public = menus.getRenderableMenu( site.getId() ).map( ( i ) => i.getLabel() );
					expect( public ).notToInclude( "Hidden" );

					// The admin must still see it, flagged, or nobody can fix it.
					var editable = menus.getEditableMenu( menu.getId(), site.getId() )
						.filter( ( i ) => i.getLabel() == "Hidden" );

					expect( editable.len() ).toBe( 1 );
					expect( editable[ 1 ].getIsAvailable() ).toBeFalse();

					pages.publishPage( about.getId() );
					menus.deleteItem( item.getId(), site.getId() );
				} );

			} );

			describe( "what the site actually renders", function(){

				it( "uses the module-contributed navigation when no menu exists", function(){
					// Adding menus must not blank the navigation of every site
					// that has never opened the new screen.
					var items = nav.getNavigationFor( otherSite.getId() );

					expect( items ).toBeArray();
					expect( nav.hasCuratedMenu( otherSite.getId() ) ).toBeFalse();
				} );

				it( "prefers a curated menu once one has items", function(){
					var item = addUrlItem( "Curated", "/curated" );

					expect( nav.hasCuratedMenu( site.getId() ) ).toBeTrue();

					var labels = nav.getNavigationFor( site.getId() ).map( ( i ) => i.label );
					expect( labels ).toInclude( "Curated" );

					menus.deleteItem( item.getId(), site.getId() );
				} );

				it( "falls back again when the menu is emptied", function(){
					// Deleting the last item should restore the automatic menu
					// rather than leaving the site with no navigation at all.
					expect( nav.hasCuratedMenu( site.getId() ) ).toBeFalse();
					expect( nav.getNavigationFor( site.getId() ) ).notToBeEmpty();
				} );

				it( "gives a theme plain structs, not entities", function(){
					var item  = addUrlItem( "Shape", "/shape" );
					var first = nav.getNavigationFor( site.getId() )[ 1 ];

					expect( first ).toBeStruct();
					expect( first ).toHaveKey( "label" );
					expect( first ).toHaveKey( "href" );
					expect( first ).toHaveKey( "children" );

					menus.deleteItem( item.getId(), site.getId() );
				} );

				it( "offers nothing for a named menu nobody has built", function(){
					// A theme asking for `footer` should not be handed a copy
					// of the header.
					expect( nav.getNavigationFor( site.getId(), "footer" ) ).toBeEmpty();
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function addUrlItem( required string label, required string url ){
		return menus.addItem(
			menuId   = menu.getId(),
			siteId   = site.getId(),
			label    = arguments.label,
			linkType = "url",
			url      = arguments.url
		);
	}

	private string function hrefOf( required string label ){
		var found = menus.getRenderableMenu( site.getId() ).filter( ( i ) => i.getLabel() == label );

		return found.len() ? found[ 1 ].getHref() : "";
	}

	private function seed(){
		variables.site      = sites.createSite( name = "Menu One", slug = PREFIX & "one" );
		variables.otherSite = sites.createSite( name = "Menu Two", slug = PREFIX & "two" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );

		variables.about = pages.createPage( siteId = site.getId(), title = "About" );
		pages.publishPage( about.getId() );

		variables.menu = menus.createMenu( siteId = site.getId(), name = "Primary", slug = "primary" );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
