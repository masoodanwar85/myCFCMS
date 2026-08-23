/**
 * PageService's own logic, with repositories stubbed: slug derivation, path
 * building, validation, and the tree-integrity rules.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run(){
		describe( "PageService", function(){

			beforeEach( function(){
				variables.pageRepo = createStub()
					.$( "existsByPath", false )
					.$( "create" )
					.$( "update" )
					.$( "findById" )
					.$( "hasChildren", false )
					.$( "rewriteDescendantPaths", 0 )
					.$( "delete" );

				variables.siteRepo     = createStub().$( "findById", makeSite( 1 ) );
				variables.userRepo     = createStub().$( "findById" );
				variables.settingsRepo = createStub().$( "getValue", "" ).$( "put" ).$( "delete" );

				variables.service = createMock( "pages.models.PageService" )
					.setPageRepository( pageRepo )
					.setSiteRepository( siteRepo )
					.setUserRepository( userRepo )
					.setSiteSettingsRepo( settingsRepo )
					.setSettings( { "homePageSettingKey" : "pages.homePageId" } )
					.setInterceptorService( createStub().$( "announce" ) )
					.setWirebox( getWireBox() );
			} );

			describe( "slug and path derivation", function(){

				it( "slugifies a title", function(){
					expect( service.slugify( "About Us!" ) ).toBe( "about-us" );
					expect( service.slugify( "  Our   Team  " ) ).toBe( "our-team" );
					expect( service.slugify( "Bar & Grill" ) ).toBe( "bar-grill" );
					// Non-ASCII titles are dropped rather than transliterated:
					// "Cafe\u0301 Bar" would slug to "caf-bar". See the docs'
					// postponed list — transliteration needs a per-locale answer.
					expect( service.slugify( "!!!" ) ).toBe( "" );
				} );

				it( "normalises a lookup path", function(){
					expect( service.normalizePath( "/about/team/" ) ).toBe( "about/team" );
					expect( service.normalizePath( "About/Team" ) ).toBe( "about/team" );
					expect( service.normalizePath( "  /about/  " ) ).toBe( "about" );
					expect( service.normalizePath( "/" ) ).toBe( "" );
				} );

				it( "gives a top-level page a path equal to its slug", function(){
					pageRepo.$( "create", makePage( 1, 1, "about", "about" ) );

					service.createPage( siteId = 1, title = "About" );

					expect( pageRepo.$callLog().create[ 1 ][ 1 ].getPath() ).toBe( "about" );
				} );

				it( "prefixes a child path with its parent's", function(){
					pageRepo.$( "findById", makePage( 9, 1, "about", "about" ) );
					pageRepo.$( "create", makePage( 2, 1, "team", "about/team" ) );

					service.createPage( siteId = 1, title = "Team", parentId = 9 );

					expect( pageRepo.$callLog().create[ 1 ][ 1 ].getPath() ).toBe( "about/team" );
				} );

			} );

			describe( "validation", function(){

				it( "rejects an empty title", function(){
					expect( function(){
						service.createPage( siteId = 1, title = "   " );
					} ).toThrow( type = "Pages.InvalidPage" );
				} );

				it( "rejects a title that yields no slug", function(){
					expect( function(){
						service.createPage( siteId = 1, title = "---" );
					} ).toThrow( type = "Pages.InvalidPage" );
				} );

				it( "rejects an unknown status", function(){
					expect( function(){
						service.createPage( siteId = 1, title = "About", status = "live" );
					} ).toThrow( type = "Pages.InvalidPage" );
				} );

				it( "rejects an unknown site", function(){
					siteRepo.$( "findById" );

					expect( function(){
						service.createPage( siteId = 999, title = "About" );
					} ).toThrow( type = "Pages.SiteNotFound" );
				} );

				it( "rejects a parent on another site", function(){
					pageRepo.$( "findById", makePage( 9, 2, "about", "about" ) );

					expect( function(){
						service.createPage( siteId = 1, title = "Team", parentId = 9 );
					} ).toThrow( type = "Pages.CrossTenantParent" );
				} );

				it( "rejects a missing parent", function(){
					expect( function(){
						service.createPage( siteId = 1, title = "Team", parentId = 999 );
					} ).toThrow( type = "Pages.ParentNotFound" );
				} );

				it( "refuses a path the site already uses, before writing", function(){
					pageRepo.$( "existsByPath", true );

					expect( function(){
						service.createPage( siteId = 1, title = "About" );
					} ).toThrow( type = "Pages.PathAlreadyExists" );

					expect( pageRepo.$count( "create" ) ).toBe( 0 );
				} );

			} );

			describe( "publishing", function(){

				it( "stamps a publication date on first publish", function(){
					pageRepo.$( "findById", makePage( 1, 1, "about", "about" ) );
					pageRepo.$( "update", makePage( 1, 1, "about", "about" ) );

					service.publishPage( 1 );

					var saved = pageRepo.$callLog().update[ 1 ][ 1 ];
					expect( saved.isPublished() ).toBeTrue();
					expect( isNull( saved.getPublishedAt() ) ).toBeFalse();
				} );

				it( "keeps an existing publication date", function(){
					var original = createDateTime( 2020, 1, 1, 9, 0, 0 );
					var existing = makePage( 1, 1, "about", "about" ).setPublishedAt( original );

					pageRepo.$( "findById", existing );
					pageRepo.$( "update", existing );

					service.publishPage( 1 );

					expect( pageRepo.$callLog().update[ 1 ][ 1 ].getPublishedAt() ).toBe( original );
				} );

				it( "returns a page to draft when unpublished", function(){
					pageRepo.$( "findById", makePage( 1, 1, "about", "about" ).setStatus( "published" ) );
					pageRepo.$( "update", makePage( 1, 1, "about", "about" ) );

					service.unpublishPage( 1 );

					expect( pageRepo.$callLog().update[ 1 ][ 1 ].isDraft() ).toBeTrue();
				} );

			} );

			describe( "tree integrity", function(){

				it( "refuses to move a page beneath itself", function(){
					pageRepo.$( "findById", makePage( 1, 1, "about", "about" ) );

					expect( function(){
						service.movePage( 1, 1 );
					} ).toThrow( type = "Pages.CircularHierarchy" );
				} );

				it( "refuses to move a page beneath its own descendant", function(){
					// findById answers the page first, then the proposed parent.
					pageRepo.$( "findById" ).$results(
						makePage( 1, 1, "about", "about" ),
						makePage( 5, 1, "ada", "about/team/ada" )
					);

					expect( function(){
						service.movePage( 1, 5 );
					} ).toThrow( type = "Pages.CircularHierarchy" );

					expect( pageRepo.$count( "update" ) ).toBe( 0 );
				} );

				it( "rewrites descendant paths when a slug changes", function(){
					var page = makePage( 1, 1, "about", "about" );
					pageRepo.$( "findById", page );
					pageRepo.$( "update", page );

					service.updatePage( pageId = 1, slug = "who-we-are" );

					expect( pageRepo.$count( "rewriteDescendantPaths" ) ).toBe( 1 );

					var call = pageRepo.$callLog().rewriteDescendantPaths[ 1 ];
					expect( call[ 2 ] ).toBe( "about" );
					expect( call[ 3 ] ).toBe( "who-we-are" );
				} );

				it( "does not rewrite anything when the path is unchanged", function(){
					var page = makePage( 1, 1, "about", "about" );
					pageRepo.$( "findById", page );
					pageRepo.$( "update", page );

					service.updatePage( pageId = 1, title = "About Us" );

					expect( pageRepo.$count( "rewriteDescendantPaths" ) ).toBe( 0 );
				} );

			} );

			describe( "deleting", function(){

				it( "refuses a page with children unless asked outright", function(){
					pageRepo.$( "findById", makePage( 1, 1, "about", "about" ) );
					pageRepo.$( "hasChildren", true );

					expect( function(){
						service.deletePage( 1 );
					} ).toThrow( type = "Pages.PageHasChildren" );

					expect( pageRepo.$count( "delete" ) ).toBe( 0 );
				} );

				it( "deletes the subtree when told to", function(){
					pageRepo.$( "findById", makePage( 1, 1, "about", "about" ) );
					pageRepo.$( "hasChildren", true );

					service.deletePage( 1, true );

					expect( pageRepo.$count( "delete" ) ).toBe( 1 );
				} );

			} );

		} );
	}

	private function makeSite( required numeric id ){
		return getInstance( "Site@core" ).setId( arguments.id ).setName( "Site" ).setSlug( "site-#arguments.id#" );
	}

	private function makePage(
		required numeric id,
		required numeric siteId,
		required string slug,
		required string path
	){
		return getInstance( "Page@pages" )
			.setId( arguments.id )
			.setSiteId( arguments.siteId )
			.setTitle( arguments.slug )
			.setSlug( arguments.slug )
			.setPath( arguments.path );
	}

}
