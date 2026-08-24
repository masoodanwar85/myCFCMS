/**
 * The API request boundary, exercised through real HTTP events.
 *
 * `ApiHandler` is the API's equivalent of `SecuredHandler`, and the property
 * that matters most is the same one: **fail closed**. An action nobody declared
 * a permission for must be refused, not allowed.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-apib-";

	function beforeAll(){
		super.beforeAll();
		variables.tokens = getInstance( "ApiTokenService@core" );
		variables.sites  = getInstance( "SiteService@core" );
		variables.users  = getInstance( "UserService@core" );
		variables.roles  = getInstance( "RoleService@core" );
		variables.pages  = getInstance( "PageService@pages" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The API boundary", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "without credentials", function(){

				it( "refuses a protected endpoint with 401", function(){
					var result = call( "/api/v1/pages" );

					expect( result.status ).toBe( 401 );
					expect( result.body.error.code ).toBe( "unauthenticated" );
				} );

				it( "says how to authenticate", function(){
					// The part of a 401 most often left out.
					var event = apiRequest( "/api/v1/pages" );

					expect( event.getResponseHeaders() ).toHaveKey( "WWW-Authenticate" );
				} );

				it( "still serves the discovery root", function(){
					var result = call( "/api/v1" );

					expect( result.status ).toBe( 200 );
					expect( result.body.data.version ).toBe( "v1" );
				} );

			} );

			describe( "with a token", function(){

				it( "serves a collection in the documented envelope", function(){
					var result = call( "/api/v1/pages", "GET", {}, ownerToken );

					expect( result.status ).toBe( 200 );
					expect( result.body ).toHaveKey( "data" );
					expect( result.body ).toHaveKey( "meta" );
					expect( result.body.data ).toBeArray();
				} );

				it( "leaves page content out of a collection", function(){
					var result = call( "/api/v1/pages", "GET", {}, ownerToken );

					// A tree of pages with full HTML is a large response nobody
					// asked for.
					expect( result.body.data[ 1 ] ).notToHaveKey( "content" );
				} );

				it( "includes content for a single page", function(){
					var result = call( "/api/v1/pages/" & about.getId(), "GET", { id : about.getId() }, ownerToken );

					expect( result.status ).toBe( 200 );
					expect( result.body.data ).toHaveKey( "content" );
				} );

				it( "answers 404 for another site's page", function(){
					// The same answer as "does not exist", so the API cannot be
					// used to discover which ids are in use elsewhere.
					var result = call( "/api/v1/pages/" & foreign.getId(), "GET", { id : foreign.getId() }, ownerToken );

					expect( result.status ).toBe( 404 );
					expect( result.body.error.code ).toBe( "not_found" );
				} );

			} );

			describe( "permissions", function(){

				it( "refuses a token whose user lacks the permission", function(){
					var result = call( "/api/v1/pages", "POST", { title : "Nope" }, editorToken );

					expect( result.status ).toBe( 403 );
					expect( result.body.error.code ).toBe( "forbidden" );
				} );

				it( "allows what the user may do", function(){
					var result = call( "/api/v1/pages", "GET", {}, editorToken );

					expect( result.status ).toBe( 200 );
				} );

				it( "uses the same permissions as the admin, not a parallel set", function(){
					// An API authorised by `api.pages.read` rather than
					// `pages.view` is how an installation ends up with an API
					// that can do things the admin refuses.
					var declared = createMock( "pages.handlers.Api" ).$getProperty( "permissions", "variables" );

					for ( var action in declared ) {
						expect( declared[ action ] ).notToInclude(
							"api.",
							"[#action#] must be guarded by a content permission, not an API-specific one"
						);
					}
				} );

				it( "fails closed for an action with no declared permission", function(){
					var declared = createMock( "core.models.api.ApiHandler" ).$getProperty( "permissions", "variables" );

					// The default is an empty map: no action is permitted until
					// a handler says so.
					expect( declared ).toBeEmpty();
				} );

			} );

			describe( "the error envelope", function(){

				it( "is the same shape for every failure", function(){
					var refusals = [
						call( "/api/v1/pages" ),
						call( "/api/v1/pages", "GET", {}, "cms_nonsense" ),
						call( "/api/v1/pages/999999", "GET", { id : 999999 }, ownerToken )
					];

					for ( var refusal in refusals ) {
						expect( refusal.body ).toHaveKey( "error" );
						expect( refusal.body.error ).toHaveKey( "code" );
						expect( refusal.body.error ).toHaveKey( "message" );
						expect( refusal.body ).notToHaveKey( "data" );
					}
				} );

				it( "gives one answer for every reason a token is unusable", function(){
					// No such token, revoked, expired, deactivated user — a
					// client that can tell those apart can enumerate them.
					var unknown = call( "/api/v1/pages", "GET", {}, "cms_" & repeatString( "a", 64 ) );

					var revoked = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "Rev" );
					tokens.revoke( revoked.getId(), site.getId() );

					var refused = call( "/api/v1/pages", "GET", {}, revoked.getPlainToken() );

					expect( refused.body.error.message ).toBe( unknown.body.error.message );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * Named `apiRequest`, not `request`: `request` is a CFML scope, and a
	 * function of that name in a component cannot be called at all — the same
	 * trap `AdminSecuritySpec` records.
	 */
	private function apiRequest(
		required string uri,
		string method = "GET",
		struct params = {},
		string token  = ""
	){
		setup();

		var headers = { "Host" : "#PREFIX#one.test" };

		if ( len( arguments.token ) ) {
			headers[ "Authorization" ] = "Bearer " & arguments.token;
		}

		return this.request(
			route   = arguments.uri,
			params  = arguments.params,
			headers = headers,
			method  = arguments.method
		);
	}

	private struct function call(
		required string uri,
		string method = "GET",
		struct params = {},
		string token  = ""
	){
		var event = apiRequest( argumentCollection = arguments );
		var body  = event.getRenderedContent();

		return {
			"status" : event.getStatusCode(),
			"body"   : isJSON( body ) ? deserializeJSON( body ) : {}
		};
	}

	private function seed(){
		variables.site  = sites.createSite( name = "Api B One", slug = PREFIX & "one" );
		variables.other = sites.createSite( name = "Api B Two", slug = PREFIX & "two" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "o@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.editor   = users.createUser( site.getId(), "Editor", "e@#PREFIX#one.test", "demo-password-123" );
		var editorRole = roles.getRoleBySlugForSite( "editor", site.getId() );

		// The seeded `editor` role deliberately carries very little — it does
		// not include `pages.view`. Granting it here so this spec tests the
		// boundary rather than the default role's contents, which are a
		// separate decision with their own specs.
		roles.grantPermission( editorRole.getId(), "pages.view" );
		users.assignRole( editor.getId(), editorRole.getId() );

		variables.about = pages.createPage( siteId = site.getId(), title = "About", content = "<p>x</p>" );
		pages.publishPage( about.getId() );

		variables.foreign = pages.createPage( siteId = other.getId(), title = "Theirs" );

		variables.ownerToken  = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "Owner" ).getPlainToken();
		variables.editorToken = tokens.issue( siteId = site.getId(), userId = editor.getId(), name = "Editor" ).getPlainToken();
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
