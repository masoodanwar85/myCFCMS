/**
 * The Pages screen folds its sub-pages.
 *
 * The table is flat and always has been — columns must line up across every
 * level, so the tree cannot be nested markup. Folding therefore depends on each
 * row carrying its own parentage, and on the whole tree being present in the
 * HTML so a browser without JavaScript can still reach every page.
 *
 * That second property is the one worth guarding: collapsing in the markup
 * would look identical in a browser and leave a no-script client with only the
 * top level and no way down.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-fold-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();
		variables.sites = getInstance( "SiteService@core" );
		variables.pages = getInstance( "PageService@pages" );
		variables.roles = getInstance( "RoleService@core" );
		variables.users = getInstance( "UserService@core" );
		variables.auth  = getInstance( "AuthenticationService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		auth.logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The page tree", function(){

			beforeEach( function(){
				setup();
				auth.logout();
				signIn( variables.owner );
			} );

			afterEach( function(){
				auth.logout();
			} );

			it( "renders every page, at every depth", function(){
				var html = screen();

				expect( html ).toInclude( "Top Level" );
				expect( html ).toInclude( "Middle" );
				expect( html ).toInclude( "Deepest" );
			} );

			/**
			 * The fold is applied by script on load. Hiding rows in the markup
			 * would leave a browser without JavaScript showing top-level pages
			 * only, with nothing to click to reach the rest.
			 */
			it( "ships the tree unfolded, so it works without JavaScript", function(){
				// Matched against `<tr ...>` rather than the whole page: the
				// class name appears in the script's own source too, and a bare
				// substring search finds that and passes for the wrong reason.
				expect( screen() ).notToMatch( "<tr[^>]*is-folded" );
			} );

			it( "gives every row its own id and its parent's", function(){
				var html = screen();

				expect( html ).toInclude( 'data-page-id="' & middle.getId() & '"' );
				expect( html ).toInclude( 'data-parent="' & top.getId() & '"' );
			} );

			it( "marks a top-level page as having no parent", function(){
				expect( screen() ).toInclude( 'data-parent="0"' );
			} );

			it( "gives a page with children a toggle, closed to begin with", function(){
				var html = screen();

				expect( html ).toInclude( "tree-toggle" );
				expect( html ).toInclude( 'aria-expanded="false"' );
			} );

			/**
			 * A leaf gets a spacer of the same width instead, or its title would
			 * sit a toggle's width left of every other title at that depth.
			 */
			it( "gives a page with no children a spacer rather than a toggle", function(){
				expect( screen() ).toInclude( "tree-leaf" );
			} );

			it( "says how many sub-pages a branch holds", function(){
				// Top Level has exactly one child.
				expect( screen() ).toMatch( 'title="1 sub-page"' );
			} );

			it( "marks the table for the script to find", function(){
				expect( screen() ).toInclude( "data-page-tree" );
			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private string function screen(){
		setup();

		var event = this.get( route = "/admin/pages", headers = { "Host" : "#PREFIX#one.test" } );

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function signIn( required any user ){
		getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
		auth.startSessionFor( arguments.user, variables.site.getId() );

		return this;
	}

	private function seed(){
		variables.site = sites.createSite( name = "Fold Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );

		roles.seedDefaultRolesForSite( site.getId() );
		variables.owner = users.createUser( site.getId(), "Owner", "owner@fold.test", PASSWORD );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.top    = pages.createPage( siteId = site.getId(), title = "Top Level",  slug = "zzt-top" );
		variables.middle = pages.createPage( siteId = site.getId(), title = "Middle",     slug = "zzt-middle", parentId = top.getId() );
		variables.deep   = pages.createPage( siteId = site.getId(), title = "Deepest",    slug = "zzt-deep",   parentId = middle.getId() );

		// A sibling with no children, so the leaf case is exercised.
		pages.createPage( siteId = site.getId(), title = "Standalone", slug = "zzt-standalone" );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
