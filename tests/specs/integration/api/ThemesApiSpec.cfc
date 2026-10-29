/**
 * `GET /api/v1/themes`, over real HTTP events.
 *
 * The resource exists so an automated client can find out which layout a page
 * may be given: `page.template` names a file under the active theme's
 * `templates/` directory, and nothing else in the API says what those names
 * are. So the assertions that matter are about `templates` and `active` — the
 * two things a client cannot work out for itself.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-themesapi-";

	function beforeAll(){
		super.beforeAll();

		variables.tokens = getInstance( "ApiTokenService@core" );
		variables.sites  = getInstance( "SiteService@core" );
		variables.users  = getInstance( "UserService@core" );
		variables.roles  = getInstance( "RoleService@core" );
		variables.themes = getInstance( "ThemeService@core" );

		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The Themes API", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "the collection", function(){

				it( "lists the installed themes", function(){
					var result = call( "/api/v1/themes" );

					expect( result.status ).toBe( 200 );
					expect( result.body.data ).toBeArray();
					expect( result.body.meta.total ).toBe( result.body.data.len() );

					expect( slugsIn( result ) ).toInclude( "default" );
				} );

				it( "leaves the shared partials directory out", function(){
					// `themes/common` holds templates the real themes include.
					// It has no layouts of its own and selecting it would render
					// nothing, so it is not a theme and must not be offered as
					// one.
					expect( slugsIn( call( "/api/v1/themes" ) ) ).notToInclude( "common" );
				} );

				it( "marks exactly one theme active", function(){
					var active = call( "/api/v1/themes" ).body.data.filter( ( theme ) => theme.active );

					expect( active.len() ).toBe( 1 );
				} );

				it( "names the active theme in the meta block" , function(){
					var result = call( "/api/v1/themes" );
					var active = result.body.data.filter( ( theme ) => theme.active )[ 1 ];

					expect( result.body.meta.active ).toBe( active.slug );
				} );

				it( "reports the fallback as active when the site names a theme that is not deployed", function(){
					// A site pointed at a removed theme renders with the
					// fallback, and this has to agree with that — a client told
					// the active theme is `gone-away` would then ask for its
					// templates and be given a 404.
					var settings = getInstance( "SiteSettingsRepository@core" );

					settings.put( site.getId(), themes.themeSettingKey(), "zzt-not-deployed" );

					try {
						var result = call( "/api/v1/themes" );

						expect( result.body.meta.active ).toBe( themes.defaultThemeSlug() );
						expect( slugsIn( result ) ).notToInclude( "zzt-not-deployed" );
					} finally {
						// Restored whatever the assertions did, so the specs
						// after this one are not reading a setting this one left
						// behind.
						settings.put( site.getId(), themes.themeSettingKey(), "" );
					}
				} );

				it( "carries each theme's templates", function(){
					var byDefault = call( "/api/v1/themes" )
						.body.data
						.filter( ( theme ) => theme.slug == "default" )[ 1 ];

					expect( byDefault.templates ).toBeArray();

					// The one template the default theme ships. Asserted by name
					// because this list is what a client sends back as
					// `template`, and PagesApiSpec applies that very value.
					expect( byDefault.templates ).toInclude( "example" );
				} );

			} );

			describe( "one theme", function(){

				it( "is addressed by slug", function(){
					var result = call( "/api/v1/themes/default" );

					expect( result.status ).toBe( 200 );
					expect( result.body.data.slug ).toBe( "default" );
					expect( result.body.data.title ).toBe( "Default" );
					expect( result.body.data.templates ).toInclude( "example" );
				} );

				it( "answers 404 for a theme that is not installed", function(){
					var result = call( "/api/v1/themes/no-such-theme" );

					expect( result.status ).toBe( 404 );
					expect( result.body.error.code ).toBe( "not_found" );
				} );

				it( "cannot be aimed outside the themes root", function(){
					// The slug addresses a directory, so `normalizeSlug` strips
					// everything but `[a-z0-9_-]` *before* the existence check.
					// `..` becomes the empty string, which is no theme, and the
					// answer is a plain 404 rather than a disclosure.
					expect( call( "/api/v1/themes/.." ).status ).toBe( 404 );
				} );

			} );

			describe( "the boundary", function(){

				it( "needs a token", function(){
					var result = call( "/api/v1/themes", "" );

					expect( result.status ).toBe( 401 );
				} );

				it( "is readable by the agent role", function(){
					// The role carries `site.view`, which is what this resource
					// asks for. Asserted here because the MCP server's
					// `list_layouts` is an agent-token call and nothing else
					// proves the two agree.
					expect( call( "/api/v1/themes", agentToken ).status ).toBe( 200 );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private array function slugsIn( required struct result ){
		return arguments.result.body.data.map( ( theme ) => theme.slug );
	}

	private struct function call( required string uri, string token ){
		setup();

		var headers = { "Host" : "#PREFIX#one.test" };
		var bearer  = isNull( arguments.token ) ? ownerToken : arguments.token;

		if ( len( bearer ) ) {
			headers[ "Authorization" ] = "Bearer " & bearer;
		}

		var event = this.request( route = arguments.uri, headers = headers, method = "GET" );
		var body  = event.getRenderedContent();

		return {
			"status" : event.getStatusCode(),
			"body"   : isJSON( body ) ? deserializeJSON( body ) : {}
		};
	}

	private function seed(){
		variables.site = sites.createSite( name = "Themes API", slug = PREFIX & "one" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "o@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.agent = users.createUser( site.getId(), "Agent", "a@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( agent.getId(), roles.getRoleBySlugForSite( "agent", site.getId() ).getId() );

		variables.ownerToken = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "Owner" ).getPlainToken();
		variables.agentToken = tokens.issue( siteId = site.getId(), userId = agent.getId(), name = "Agent" ).getPlainToken();
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
