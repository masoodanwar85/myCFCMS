/**
 * The Pages module against a real MySQL schema.
 *
 * The parts worth testing here are the ones a stub cannot honestly stand in
 * for: path uniqueness scoped per site, the subtree path rewrite after a rename
 * or move, the self-referencing cascade, and the interaction with Group 1's
 * cascade from `sites`.
 *
 * Requires migrations to have run: `box migrate up`.
 * Rows hang off a `zzt-pg-` site and are removed afterwards.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-pg-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();
		variables.sites    = getInstance( "SiteService@core" );
		variables.users    = getInstance( "UserService@core" );
		variables.roles    = getInstance( "RoleService@core" );
		variables.pages    = getInstance( "PageService@pages" );
		variables.pageRepo = getInstance( "PageRepository@pages" );
		variables.settings = getInstance( "SiteSettingsRepository@core" );
		cleanup();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Pages persistence", function(){

			afterEach( function(){
				cleanup();
			} );

			describe( "creating pages", function(){

				it( "round-trips a top-level page", function(){
					var site = newSite( "One" );
					var page = pages.createPage( siteId = site.getId(), title = "About Us" );

					expect( page.getId() ).toBeGT( 0 );

					var loaded = pageRepo.findById( page.getId() );

					expect( loaded.getTitle() ).toBe( "About Us" );
					expect( loaded.getSlug() ).toBe( "about-us" );
					expect( loaded.getPath() ).toBe( "about-us" );
					expect( loaded.getSiteId() ).toBe( site.getId() );
					expect( loaded.isRoot() ).toBeTrue();
					expect( loaded.isDraft() ).toBeTrue();
				} );

				it( "builds a child path from its parent", function(){
					var site   = newSite( "Two" );
					var parent = pages.createPage( siteId = site.getId(), title = "About" );
					var child  = pages.createPage( siteId = site.getId(), title = "The Team", parentId = parent.getId() );

					expect( child.getPath() ).toBe( "about/the-team" );
					expect( child.isRoot() ).toBeFalse();
					expect( child.getDepth() ).toBe( 1 );
				} );

				it( "nests to arbitrary depth", function(){
					var site = newSite( "Three" );
					var a    = pages.createPage( siteId = site.getId(), title = "A" );
					var b    = pages.createPage( siteId = site.getId(), title = "B", parentId = a.getId() );
					var c    = pages.createPage( siteId = site.getId(), title = "C", parentId = b.getId() );

					expect( c.getPath() ).toBe( "a/b/c" );
					expect( c.getDepth() ).toBe( 2 );
				} );

				it( "accepts an explicit slug", function(){
					var site = newSite( "Four" );
					var page = pages.createPage( siteId = site.getId(), title = "About Us", slug = "who-we-are" );

					expect( page.getPath() ).toBe( "who-we-are" );
				} );

				it( "refuses two pages at the same path on one site", function(){
					var site = newSite( "Five" );
					pages.createPage( siteId = site.getId(), title = "About" );

					expect( function(){
						pages.createPage( siteId = site.getId(), title = "About" );
					} ).toThrow( type = "Pages.PathAlreadyExists" );
				} );

				it( "enforces that in the database, not only in the service", function(){
					var site = newSite( "Six" );
					pages.createPage( siteId = site.getId(), title = "About" );

					expect( function(){
						pageRepo.create(
							getInstance( "Page@pages" )
								.setSiteId( site.getId() )
								.setTitle( "Impostor" )
								.setSlug( "about" )
								.setPath( "about" )
						);
					} ).toThrow( type = "Pages.PathAlreadyExists" );
				} );

				it( "allows the same path on two different sites", function(){
					var siteA = newSite( "Seven A" );
					var siteB = newSite( "Seven B" );

					var a = pages.createPage( siteId = siteA.getId(), title = "About" );
					var b = pages.createPage( siteId = siteB.getId(), title = "About" );

					expect( a.getPath() ).toBe( b.getPath() );
					expect( a.getId() ).notToBe( b.getId() );
				} );

				it( "allows the same slug under different parents", function(){
					var site = newSite( "Eight" );
					var one  = pages.createPage( siteId = site.getId(), title = "Products" );
					var two  = pages.createPage( siteId = site.getId(), title = "Services" );

					var a = pages.createPage( siteId = site.getId(), title = "Overview", parentId = one.getId() );
					var b = pages.createPage( siteId = site.getId(), title = "Overview", parentId = two.getId() );

					expect( a.getPath() ).toBe( "products/overview" );
					expect( b.getPath() ).toBe( "services/overview" );
				} );

				it( "refuses a parent belonging to another site", function(){
					var siteA  = newSite( "Nine A" );
					var siteB  = newSite( "Nine B" );
					var parent = pages.createPage( siteId = siteA.getId(), title = "About" );

					expect( function(){
						pages.createPage( siteId = siteB.getId(), title = "Team", parentId = parent.getId() );
					} ).toThrow( type = "Pages.CrossTenantParent" );
				} );

				it( "rejects an empty title and an unusable slug", function(){
					var site = newSite( "Ten" );

					expect( function(){
						pages.createPage( siteId = site.getId(), title = "  " );
					} ).toThrow( type = "Pages.InvalidPage" );

					expect( function(){
						pages.createPage( siteId = site.getId(), title = "!!!" );
					} ).toThrow( type = "Pages.InvalidPage" );
				} );

				it( "rejects an unknown site", function(){
					expect( function(){
						pages.createPage( siteId = 987654321, title = "About" );
					} ).toThrow( type = "Pages.SiteNotFound" );
				} );

			} );

			describe( "authorship", function(){

				it( "records the author", function(){
					var site   = newSite( "Eleven" );
					var author = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var page   = pages.createPage( siteId = site.getId(), title = "About", authorId = author.getId() );

					expect( pageRepo.findById( page.getId() ).getCreatedBy() ).toBe( author.getId() );
				} );

				it( "refuses an author from another site", function(){
					var siteA   = newSite( "Twelve A" );
					var siteB   = newSite( "Twelve B" );
					var outsider = users.createUser( siteB.getId(), "Eve", "eve@other.com", PASSWORD );

					expect( function(){
						pages.createPage( siteId = siteA.getId(), title = "About", authorId = outsider.getId() );
					} ).toThrow( type = "Pages.InvalidAuthor" );
				} );

				it( "accepts a platform super admin as author on any site", function(){
					var site  = newSite( "Thirteen" );
					var admin = users.createSuperAdmin( "Root", "#PREFIX#root@platform.com", PASSWORD );

					expect( function(){
						pages.createPage( siteId = site.getId(), title = "About", authorId = admin.getId() );
					} ).notToThrow();
				} );

				it( "keeps the page when its author is deleted", function(){
					var site   = newSite( "Fourteen" );
					var author = users.createUser( site.getId(), "Ada", "ada@client.com", PASSWORD );
					var page   = pages.createPage( siteId = site.getId(), title = "About", authorId = author.getId() );

					users.deleteUser( author.getId() );

					var loaded = pageRepo.findById( page.getId() );

					expect( isNull( loaded ) ).toBeFalse();
					expect( isNull( loaded.getCreatedBy() ) ).toBeTrue();
				} );

			} );

			describe( "renaming a page", function(){

				it( "moves its own path", function(){
					var site = newSite( "Fifteen" );
					var page = pages.createPage( siteId = site.getId(), title = "About" );

					pages.updatePage( pageId = page.getId(), slug = "who-we-are" );

					expect( pageRepo.findById( page.getId() ).getPath() ).toBe( "who-we-are" );
				} );

				it( "rewrites the paths of everything beneath it", function(){
					var site   = newSite( "Sixteen" );
					var about  = pages.createPage( siteId = site.getId(), title = "About" );
					var team   = pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );
					var person = pages.createPage( siteId = site.getId(), title = "Ada", parentId = team.getId() );

					expect( person.getPath() ).toBe( "about/team/ada" );

					pages.updatePage( pageId = about.getId(), slug = "who-we-are" );

					expect( pageRepo.findById( team.getId() ).getPath() ).toBe( "who-we-are/team" );
					expect( pageRepo.findById( person.getId() ).getPath() ).toBe( "who-we-are/team/ada" );
				} );

				it( "leaves other sites' identical paths alone", function(){
					var siteA = newSite( "Seventeen A" );
					var siteB = newSite( "Seventeen B" );

					var a     = pages.createPage( siteId = siteA.getId(), title = "About" );
					pages.createPage( siteId = siteA.getId(), title = "Team", parentId = a.getId() );

					var b     = pages.createPage( siteId = siteB.getId(), title = "About" );
					var bTeam = pages.createPage( siteId = siteB.getId(), title = "Team", parentId = b.getId() );

					pages.updatePage( pageId = a.getId(), slug = "renamed" );

					expect( pageRepo.findById( bTeam.getId() ).getPath() ).toBe( "about/team" );
				} );

				it( "refuses a rename that would collide", function(){
					var site = newSite( "Eighteen" );
					pages.createPage( siteId = site.getId(), title = "Contact" );
					var about = pages.createPage( siteId = site.getId(), title = "About" );

					expect( function(){
						pages.updatePage( pageId = about.getId(), slug = "contact" );
					} ).toThrow( type = "Pages.PathAlreadyExists" );
				} );

				it( "updates content and SEO fields without touching the path", function(){
					var site = newSite( "Nineteen" );
					var page = pages.createPage( siteId = site.getId(), title = "About" );

					pages.updatePage(
						pageId          = page.getId(),
						content         = "<p>Hello</p>",
						metaTitle       = "About our company",
						metaDescription = "Who we are."
					);

					var loaded = pageRepo.findById( page.getId() );
					expect( loaded.getContent() ).toBe( "<p>Hello</p>" );
					expect( loaded.getMetaTitle() ).toBe( "About our company" );
					expect( loaded.getPath() ).toBe( "about" );
				} );

			} );

			describe( "moving a page", function(){

				it( "reparents it and rewrites its subtree", function(){
					var site     = newSite( "Twenty" );
					var about    = pages.createPage( siteId = site.getId(), title = "About" );
					var company  = pages.createPage( siteId = site.getId(), title = "Company" );
					var team     = pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );
					var person   = pages.createPage( siteId = site.getId(), title = "Ada", parentId = team.getId() );

					pages.movePage( team.getId(), company.getId() );

					expect( pageRepo.findById( team.getId() ).getPath() ).toBe( "company/team" );
					expect( pageRepo.findById( person.getId() ).getPath() ).toBe( "company/team/ada" );
				} );

				it( "moves a page to the top level", function(){
					var site  = newSite( "Twentyone" );
					var about = pages.createPage( siteId = site.getId(), title = "About" );
					var team  = pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );

					pages.movePage( team.getId() );

					var moved = pageRepo.findById( team.getId() );
					expect( moved.isRoot() ).toBeTrue();
					expect( moved.getPath() ).toBe( "team" );
				} );

				it( "refuses to move a page beneath itself", function(){
					var site = newSite( "Twentytwo" );
					var page = pages.createPage( siteId = site.getId(), title = "About" );

					expect( function(){
						pages.movePage( page.getId(), page.getId() );
					} ).toThrow( type = "Pages.CircularHierarchy" );
				} );

				it( "refuses to move a page beneath its own descendant", function(){
					var site  = newSite( "Twentythree" );
					var about = pages.createPage( siteId = site.getId(), title = "About" );
					var team  = pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );
					var deep  = pages.createPage( siteId = site.getId(), title = "Ada", parentId = team.getId() );

					expect( function(){
						pages.movePage( about.getId(), deep.getId() );
					} ).toThrow( type = "Pages.CircularHierarchy" );

					// Nothing moved.
					expect( pageRepo.findById( about.getId() ).getPath() ).toBe( "about" );
				} );

				it( "refuses a new parent on another site", function(){
					var siteA = newSite( "Twentyfour A" );
					var siteB = newSite( "Twentyfour B" );
					var page  = pages.createPage( siteId = siteA.getId(), title = "About" );
					var other = pages.createPage( siteId = siteB.getId(), title = "Elsewhere" );

					expect( function(){
						pages.movePage( page.getId(), other.getId() );
					} ).toThrow( type = "Pages.CrossTenantParent" );
				} );

			} );

			describe( "publishing", function(){

				it( "starts as a draft and is not publicly resolvable", function(){
					var site = newSite( "Twentyfive" );
					var page = pages.createPage( siteId = site.getId(), title = "About" );

					expect( page.isDraft() ).toBeTrue();
					expect( isNull( pages.getPublishedPageByPath( site.getId(), "about" ) ) ).toBeTrue();
					// The editor's view still finds it.
					expect( isNull( pages.getPageByPath( site.getId(), "about" ) ) ).toBeFalse();
				} );

				it( "becomes publicly resolvable once published", function(){
					var site = newSite( "Twentysix" );
					var page = pages.createPage( siteId = site.getId(), title = "About" );

					pages.publishPage( page.getId() );

					var live = pages.getPublishedPageByPath( site.getId(), "about" );
					expect( isNull( live ) ).toBeFalse();
					expect( live.getId() ).toBe( page.getId() );
					expect( isNull( live.getPublishedAt() ) ).toBeFalse();
				} );

				it( "keeps the original publication date across a republish", function(){
					var site = newSite( "Twentyseven" );
					var page = pages.createPage( siteId = site.getId(), title = "About" );

					pages.publishPage( page.getId() );
					var first = pageRepo.findById( page.getId() ).getPublishedAt();

					pages.unpublishPage( page.getId() );
					pages.publishPage( page.getId() );
					var second = pageRepo.findById( page.getId() ).getPublishedAt();

					// Both read back from the database, so this tests the rule
					// rather than how a datetime survives a round trip.
					expect( dateTimeFormat( second, "iso" ) ).toBe( dateTimeFormat( first, "iso" ) );
				} );

				it( "hides a page again when unpublished", function(){
					var site = newSite( "Twentyeight" );
					var page = pages.createPage( siteId = site.getId(), title = "About" );

					pages.publishPage( page.getId() );
					pages.unpublishPage( page.getId() );

					expect( isNull( pages.getPublishedPageByPath( site.getId(), "about" ) ) ).toBeTrue();
				} );

				it( "archives without deleting", function(){
					var site = newSite( "Twentynine" );
					var page = pages.createPage( siteId = site.getId(), title = "About" );

					pages.archivePage( page.getId() );

					expect( pageRepo.findById( page.getId() ).isArchived() ).toBeTrue();
					expect( isNull( pages.getPublishedPageByPath( site.getId(), "about" ) ) ).toBeTrue();
				} );

				it( "lists only published pages for the public", function(){
					var site = newSite( "Thirty" );
					var one  = pages.createPage( siteId = site.getId(), title = "One" );
					pages.createPage( siteId = site.getId(), title = "Two" );
					pages.publishPage( one.getId() );

					expect( pages.getPagesForSite( site.getId() ).len() ).toBe( 2 );
					expect( pages.getPublishedPagesForSite( site.getId() ).len() ).toBe( 1 );
				} );

			} );

			describe( "resolving a path", function(){

				it( "ignores leading and trailing slashes and casing", function(){
					var site = newSite( "Thirtyone" );
					var about = pages.createPage( siteId = site.getId(), title = "About" );
					var team  = pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );

					for ( var candidate in [ "about/team", "/about/team", "about/team/", "/About/Team/" ] ) {
						var found = pages.getPageByPath( site.getId(), candidate );
						expect( isNull( found ) ).toBeFalse();
						expect( found.getId() ).toBe( team.getId() );
					}
				} );

				it( "does not resolve a path belonging to another site", function(){
					var siteA = newSite( "Thirtytwo A" );
					var siteB = newSite( "Thirtytwo B" );
					pages.createPage( siteId = siteA.getId(), title = "About" );

					expect( isNull( pages.getPageByPath( siteB.getId(), "about" ) ) ).toBeTrue();
				} );

				it( "returns null for an unknown path", function(){
					var site = newSite( "Thirtythree" );

					expect( isNull( pages.getPageByPath( site.getId(), "nowhere" ) ) ).toBeTrue();
				} );

			} );

			describe( "the tree", function(){

				it( "lists root pages in menu order", function(){
					var site = newSite( "Thirtyfour" );
					var b = pages.createPage( siteId = site.getId(), title = "Second", sortOrder = 2 );
					var a = pages.createPage( siteId = site.getId(), title = "First", sortOrder = 1 );

					var roots = pages.getRootPages( site.getId() );

					expect( roots.len() ).toBe( 2 );
					expect( roots[ 1 ].getId() ).toBe( a.getId() );
				} );

				it( "nests children under their parents", function(){
					var site   = newSite( "Thirtyfive" );
					var about  = pages.createPage( siteId = site.getId(), title = "About" );
					pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );
					pages.createPage( siteId = site.getId(), title = "History", parentId = about.getId() );

					var tree = pages.getTree( site.getId() );

					expect( tree.len() ).toBe( 1 );
					expect( tree[ 1 ].page.getTitle() ).toBe( "About" );
					expect( tree[ 1 ].children.len() ).toBe( 2 );
				} );

				it( "builds a breadcrumb from the root down to the page", function(){
					var site   = newSite( "Thirtysix" );
					var about  = pages.createPage( siteId = site.getId(), title = "About" );
					var team   = pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );
					var person = pages.createPage( siteId = site.getId(), title = "Ada", parentId = team.getId() );

					var trail = pages.getBreadcrumb( person.getId() );

					expect( trail.len() ).toBe( 3 );
					expect( trail[ 1 ].getTitle() ).toBe( "About" );
					expect( trail[ 2 ].getTitle() ).toBe( "Team" );
					expect( trail[ 3 ].getTitle() ).toBe( "Ada" );
				} );

				it( "finds every descendant of a page", function(){
					var site  = newSite( "Thirtyseven" );
					var about = pages.createPage( siteId = site.getId(), title = "About" );
					var team  = pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );
					pages.createPage( siteId = site.getId(), title = "Ada", parentId = team.getId() );
					pages.createPage( siteId = site.getId(), title = "Unrelated" );

					expect( pages.getDescendants( about.getId() ).len() ).toBe( 2 );
				} );

				it( "reorders siblings", function(){
					var site = newSite( "Thirtyeight" );
					var a = pages.createPage( siteId = site.getId(), title = "Alpha" );
					var b = pages.createPage( siteId = site.getId(), title = "Beta" );

					pages.reorderPages( [ b.getId(), a.getId() ] );

					var roots = pages.getRootPages( site.getId() );
					expect( roots[ 1 ].getId() ).toBe( b.getId() );
				} );

			} );

			describe( "deleting", function(){

				it( "deletes a leaf page", function(){
					var site = newSite( "Thirtynine" );
					var page = pages.createPage( siteId = site.getId(), title = "About" );

					pages.deletePage( page.getId() );

					expect( isNull( pageRepo.findById( page.getId() ) ) ).toBeTrue();
				} );

				it( "refuses to delete a page with children by accident", function(){
					var site  = newSite( "Forty" );
					var about = pages.createPage( siteId = site.getId(), title = "About" );
					pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );

					expect( function(){
						pages.deletePage( about.getId() );
					} ).toThrow( type = "Pages.PageHasChildren" );

					expect( isNull( pageRepo.findById( about.getId() ) ) ).toBeFalse();
				} );

				it( "deletes the subtree when asked outright", function(){
					var site   = newSite( "Fortyone" );
					var about  = pages.createPage( siteId = site.getId(), title = "About" );
					var team   = pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );
					var person = pages.createPage( siteId = site.getId(), title = "Ada", parentId = team.getId() );

					pages.deletePage( about.getId(), true );

					expect( isNull( pageRepo.findById( about.getId() ) ) ).toBeTrue();
					expect( isNull( pageRepo.findById( team.getId() ) ) ).toBeTrue();
					expect( isNull( pageRepo.findById( person.getId() ) ) ).toBeTrue();
				} );

				it( "removes every page when the site goes", function(){
					var site   = newSite( "Fortytwo" );
					var about  = pages.createPage( siteId = site.getId(), title = "About" );
					pages.createPage( siteId = site.getId(), title = "Team", parentId = about.getId() );

					queryExecute( "DELETE FROM sites WHERE id = :id", { id : site.getId() } );

					expect( pages.getPagesForSite( site.getId() ).len() ).toBe( 0 );
				} );

			} );

			describe( "the home page", function(){

				it( "records and returns a site's home page", function(){
					var site = newSite( "Fortythree" );
					var page = pages.createPage( siteId = site.getId(), title = "Welcome" );

					pages.setHomePage( site.getId(), page.getId() );

					expect( pages.getHomePage( site.getId() ).getId() ).toBe( page.getId() );
				} );

				it( "stores it as a site setting, keeping Core free of page knowledge", function(){
					var site = newSite( "Fortyfour" );
					var page = pages.createPage( siteId = site.getId(), title = "Welcome" );

					pages.setHomePage( site.getId(), page.getId() );

					expect( settings.getValue( site.getId(), "pages.homePageId", "" ) ).toBe( page.getId() );
				} );

				it( "returns null when none is set", function(){
					expect( isNull( pages.getHomePage( newSite( "Fortyfive" ).getId() ) ) ).toBeTrue();
				} );

				it( "refuses a page from another site", function(){
					var siteA = newSite( "Fortysix A" );
					var siteB = newSite( "Fortysix B" );
					var page  = pages.createPage( siteId = siteB.getId(), title = "Welcome" );

					expect( function(){
						pages.setHomePage( siteA.getId(), page.getId() );
					} ).toThrow( type = "Pages.CrossTenantPage" );
				} );

				it( "clears the setting when the home page is deleted", function(){
					var site = newSite( "Fortyseven" );
					var page = pages.createPage( siteId = site.getId(), title = "Welcome" );

					pages.setHomePage( site.getId(), page.getId() );
					pages.deletePage( page.getId() );

					expect( isNull( pages.getHomePage( site.getId() ) ) ).toBeTrue();
					expect( settings.getValue( site.getId(), "pages.homePageId", "" ) ).toBe( "" );
				} );

			} );

			describe( "module permissions", function(){

				it( "registers its own permissions into Core's catalogue", function(){
					var slugs = roles.getAllPermissions().map( ( p ) => p.getSlug() );

					expect( slugs ).toInclude( "pages.view" );
					expect( slugs ).toInclude( "pages.create" );
					expect( slugs ).toInclude( "pages.publish" );
				} );

				it( "gives a site owner the page permissions when roles are seeded", function(){
					var site = newSite( "Fortyeight" );
					roles.seedDefaultRolesForSite( site.getId() );

					var owner = roles.getRoleBySlugForSite( "owner", site.getId() );

					expect( roles.getPermissions( owner.getId() ) ).toInclude( "pages.publish" );
				} );

			} );

		} );
	}

	private function newSite( required string name ){
		return sites.createSite(
			name = arguments.name,
			slug = PREFIX & sites.slugify( arguments.name ) & "-" & createUUID().left( 8 )
		);
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :prefix", { prefix : PREFIX & "%" } );
		queryExecute(
			"DELETE FROM users WHERE site_id IS NULL AND email LIKE :prefix",
			{ prefix : PREFIX & "%" }
		);
	}

}
