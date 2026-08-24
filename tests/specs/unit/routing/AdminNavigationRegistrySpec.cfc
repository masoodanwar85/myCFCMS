/**
 * How the admin bar is assembled.
 *
 * The property that matters is the one that is easy to lose: a group must
 * disappear entirely when the signed-in user may reach nothing inside it.
 * An empty "Access" menu tells someone exactly what exists and that they are
 * not allowed near it, which is worse than not showing it at all.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	function beforeAll(){
		super.beforeAll();
	}

	function run(){
		describe( "AdminNavigationRegistry", function(){

			beforeEach( function(){
				variables.registry = freshRegistry();
				variables.user     = createStub();
			} );

			describe( "grouping", function(){

				it( "puts ungrouped sections at the top level", function(){
					registry.register( label = "Dashboard", href = "/admin", order = 10 );

					var entries = grouped( allowAll() );

					expect( entries.len() ).toBe( 1 );
					expect( entries[ 1 ].type ).toBe( "link" );
					expect( entries[ 1 ].label ).toBe( "Dashboard" );
				} );

				it( "collects sections sharing a group under one entry", function(){
					registry.register( label = "Pages", href = "/admin/pages", order = 20, group = "CMS" );
					registry.register( label = "Media", href = "/admin/media", order = 26, group = "CMS" );

					var entries = grouped( allowAll() );

					expect( entries.len() ).toBe( 1 );
					expect( entries[ 1 ].type ).toBe( "group" );
					expect( entries[ 1 ].label ).toBe( "CMS" );
					expect( entries[ 1 ].items.len() ).toBe( 2 );
				} );

				it( "orders members within a group", function(){
					registry.register( label = "Media", href = "/admin/media", order = 26, group = "CMS" );
					registry.register( label = "Pages", href = "/admin/pages", order = 20, group = "CMS" );

					var items = grouped( allowAll() )[ 1 ].items.map( ( i ) => i.label );

					expect( items[ 1 ] ).toBe( "Pages" );
					expect( items[ 2 ] ).toBe( "Media" );
				} );

				it( "positions a group by its lowest member, whatever order they arrive in", function(){
					// One ordering scheme rather than two: a module cannot
					// reposition a whole group by picking a low number, only
					// take a place within it.
					registry.register( label = "Users", href = "/admin/users", order = 60, group = "Access" );
					registry.register( label = "Media", href = "/admin/media", order = 26, group = "CMS" );
					registry.register( label = "Dashboard", href = "/admin", order = 10 );
					registry.register( label = "Pages", href = "/admin/pages", order = 20, group = "CMS" );

					var labels = grouped( allowAll() ).map( ( e ) => e.label );

					expect( labels ).toBe( [ "Dashboard", "CMS", "Access" ] );
				} );

			} );

			describe( "permission filtering", function(){

				it( "drops a section the user may not reach", function(){
					registry.register( label = "Pages", href = "/admin/pages", permission = "pages.view", order = 20, group = "CMS" );
					registry.register( label = "Media", href = "/admin/media", permission = "media.view", order = 26, group = "CMS" );

					var items = grouped( allowOnly( "media.view" ) )[ 1 ].items.map( ( i ) => i.label );

					expect( items ).toBe( [ "Media" ] );
				} );

				it( "hides a group whose every member is refused", function(){
					// The one that matters. An empty menu names what exists and
					// says you cannot have it.
					registry.register( label = "Users", href = "/admin/users", permission = "users.view", order = 60, group = "Access" );
					registry.register( label = "Roles", href = "/admin/roles", permission = "roles.view", order = 62, group = "Access" );
					registry.register( label = "Dashboard", href = "/admin", order = 10 );

					var labels = grouped( allowOnly( "nothing.at.all" ) ).map( ( e ) => e.label );

					expect( labels ).toBe( [ "Dashboard" ] );
					expect( labels ).notToInclude( "Access" );
				} );

				it( "keeps a group with one surviving member", function(){
					registry.register( label = "Users", href = "/admin/users", permission = "users.view", order = 60, group = "Access" );
					registry.register( label = "Roles", href = "/admin/roles", permission = "roles.view", order = 62, group = "Access" );

					var entries = grouped( allowOnly( "roles.view" ) );

					expect( entries.len() ).toBe( 1 );
					expect( entries[ 1 ].items.len() ).toBe( 1 );
					expect( entries[ 1 ].items[ 1 ].label ).toBe( "Roles" );
				} );

			} );

			describe( "registration", function(){

				it( "ignores a second registration of the same href", function(){
					registry.register( label = "Pages", href = "/admin/pages", group = "CMS" );
					registry.register( label = "Impostor", href = "/admin/pages", group = "Modules" );

					expect( registry.getSections().len() ).toBe( 1 );
					expect( registry.getSections()[ 1 ].label ).toBe( "Pages" );
				} );

				it( "lets a module remove its own section again", function(){
					registry.register( label = "Blog", href = "/admin/blog", group = "Modules" );
					registry.unregister( "/admin/blog" );

					expect( grouped( allowAll() ) ).toBeEmpty();
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * A registry of this spec's own.
	 *
	 * Never `getInstance( ... ).init()`: these registries are **singletons**,
	 * so reinitialising one empties the registrations every module made at
	 * load — and every spec that runs afterwards in the same suite sees an
	 * empty registry. It passes in isolation and breaks three unrelated
	 * bundles in a full run, which is the worst way for a test to be wrong.
	 */
	private any function freshRegistry(){
		return createMock( "core.models.routing.AdminNavigationRegistry" ).init();
	}

	private array function grouped( required any auth ){
		return registry.getGroupedSectionsFor( user, arguments.auth );
	}

	private any function allowAll(){
		return createStub().$( "can", true );
	}

	/**
	 * An authorization service that permits exactly one slug.
	 */
	private any function allowOnly( required string slug ){
		var wanted = arguments.slug;
		var auth   = createStub();

		auth.can = function( user, permissionSlug, siteId ){
			return arguments.permissionSlug == wanted;
		};

		return auth;
	}

}
