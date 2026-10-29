/**
 * The Pages REST resource, over real HTTP events.
 *
 * `ApiBoundarySpec` covers the boundary — tokens, tenancy, permissions, the
 * error envelope. This covers what the resource actually *does*, and most of it
 * exists because of one bug: the handler accepted `title`, `slug`, `content`,
 * `metaTitle`, `metaDescription` and `sortOrder` and silently dropped every
 * other field a page has. A client could PATCH a canonical URL, get `200` back
 * with the old value in the body, and have no way to tell it had been ignored.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-pagesapi-";

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
		describe( "The Pages API", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "the SEO and display fields", function(){

				it( "stores a canonical URL and reads it back", function(){
					var page   = newPage( "Canonical" );
					var result = patch( page, { canonicalUrl : "https://example.test/elsewhere" } );

					expect( result.status ).toBe( 200 );
					expect( result.body.data.canonicalUrl ).toBe( "https://example.test/elsewhere" );

					// And again on a fresh read, not just in the write's echo.
					expect( get( page ).body.data.canonicalUrl ).toBe( "https://example.test/elsewhere" );
				} );

				it( "turns robots off when told false", function(){
					// The trap this whole field list is built around: `false` is
					// a real value, and a handler using `rc.x ?: default` or a
					// truthiness test makes these two impossible to switch off.
					var page   = newPage( "Noindex" );
					var result = patch( page, { robotsIndex : false, robotsFollow : false } );

					expect( result.body.data.robotsIndex ).toBeFalse();
					expect( result.body.data.robotsFollow ).toBeFalse();
				} );

				it( "leaves a field alone when the request does not mention it", function(){
					// What makes this a PATCH. A client fixing a title must not
					// blank the canonical somebody else set.
					var page = newPage( "Partial" );

					patch( page, { canonicalUrl : "https://example.test/keep" } );
					patch( page, { title : "Renamed" } );

					var after = get( page ).body.data;

					expect( after.title ).toBe( "Renamed" );
					expect( after.canonicalUrl ).toBe( "https://example.test/keep" );
				} );

				it( "applies a theme template", function(){
					var page = newPage( "Templated" );

					expect( patch( page, { template : "example" } ).body.data.template ).toBe( "example" );
				} );

				it( "cleans a template name rather than refusing the save", function(){
					// A name that resolves to nothing falls back to the page
					// view, which is not worth refusing a save over — but it
					// must not be able to address a file outside `templates/`.
					var page = newPage( "Traversal" );

					expect( patch( page, { template : "../../secrets" } ).body.data.template ).toBe( "secrets" );
				} );

				it( "stores a featured image and the inheritance switch", function(){
					var page   = newPage( "Featured" );
					var result = patch( page, {
						featuredImage        : "/media/2026/10/banner.png",
						inheritFeaturedImage : false
					} );

					expect( result.body.data.featuredImage ).toBe( "/media/2026/10/banner.png" );
					expect( result.body.data.inheritFeaturedImage ).toBeFalse();
				} );

				it( "accepts the fields on create, not only on update", function(){
					var result = call( "/api/v1/pages", "POST", {
						title        : "Created with SEO",
						slug         : PREFIX & "created-seo",
						metaTitle    : "A meta title",
						canonicalUrl : "/somewhere",
						ogType       : "article",
						showHeading  : false
					}, ownerToken );

					expect( result.status ).toBe( 201 );
					expect( result.body.data.canonicalUrl ).toBe( "/somewhere" );
					expect( result.body.data.ogType ).toBe( "article" );
					expect( result.body.data.showHeading ).toBeFalse();
				} );

				it( "refuses an address that is neither absolute nor site-relative", function(){
					var page   = newPage( "Bad URL" );
					var result = patch( page, { canonicalUrl : "javascript:alert(1)" } );

					expect( result.status ).toBe( 422 );
					expect( result.body.error.code ).toBe( "invalid" );
				} );

				it( "falls back to a known value for an unrecognised enum", function(){
					// `ogType` is a short list. An unknown one is corrected
					// rather than refused, which is the service's choice and is
					// asserted here so a client can rely on it.
					var page = newPage( "Enum" );

					expect( patch( page, { ogType : "not-a-type" } ).body.data.ogType ).toBe( "website" );
				} );

			} );

			describe( "raw markup", function(){

				it( "is ignored for a token whose user may not write it", function(){
					// `content.unfiltered` is what lets HTML bypass the
					// sanitiser, and the API must not be the lenient way in.
					var page   = newPage( "Raw refused" );
					var result = patch( page, { jsonLd : '{"@type":"Thing"}' }, editorToken );

					expect( result.status ).toBe( 200 );
					expect( result.body.data.jsonLd ).toBe( "" );
				} );

				it( "is stored for a token whose user may", function(){
					var page   = newPage( "Raw allowed" );
					var result = patch( page, { jsonLd : '{"@type":"Thing"}' } );

					expect( result.body.data.jsonLd ).toBe( '{"@type":"Thing"}' );
				} );

			} );

			describe( "moving a page", function(){

				it( "reparents and rewrites the path", function(){
					var child = newPage( "Mover" );

					var result = patch( child, { parentId : parent.getId() } );

					expect( result.status ).toBe( 200 );
					expect( result.body.data.parentId ).toBe( parent.getId() );
					expect( result.body.data.path ).toBe( parent.getSlug() & "/" & result.body.data.slug );
				} );

				it( "promotes to the top level when given 0", function(){
					var child  = newPage( "Promote", parent.getId() );
					var result = patch( child, { parentId : 0 } );

					expect( result.body.data.parentId ).toBe( 0 );
					expect( result.body.data.path ).toBe( result.body.data.slug );
				} );

				it( "leaves the page where it is when parentId is absent", function(){
					// An absent key on a PATCH means "do not touch", and moving
					// rewrites every descendant's path and leaves redirects
					// behind — much too expensive to do by accident.
					var child = newPage( "Stays", parent.getId() );

					var result = patch( child, { title : "Still nested" } );

					expect( result.body.data.parentId ).toBe( parent.getId() );
				} );

				it( "refuses to move a page beneath its own child", function(){
					var child = newPage( "Loop child", parent.getId() );

					var result = patch( parent, { parentId : child.getId() } );

					expect( result.status ).toBe( 422 );
				} );

			} );

			describe( "the projections", function(){

				it( "keeps the collection lean", function(){
					// Twenty extra fields per row on a fifty-page tree is a
					// response nobody asked for.
					var row = call( "/api/v1/pages", "GET", {}, ownerToken ).body.data[ 1 ];

					expect( row ).notToHaveKey( "canonicalUrl" );
					expect( row ).notToHaveKey( "jsonLd" );
				} );

				it( "reports an unset date as an empty string, not null", function(){
					var data = get( newPage( "Dates" ) ).body.data;

					expect( data.publishFrom ).toBe( "" );
					expect( data.publishUntil ).toBe( "" );
				} );

				it( "round-trips a schedule", function(){
					var page   = newPage( "Scheduled" );
					var result = patch( page, { publishFrom : "2026-11-01 09:00:00" } );

					expect( result.body.data.publishFrom ).toInclude( "2026-11-01" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function newPage( required string title, numeric parentId ){
		var attributes = {
			siteId  : site.getId(),
			title   : arguments.title,
			slug    : PREFIX & createUUID().lCase().left( 8 ),
			content : "<p>Body copy.</p>"
		};

		if ( !isNull( arguments.parentId ) ) {
			attributes.parentId = arguments.parentId;
		}

		return pages.createPage( argumentCollection = attributes );
	}

	private struct function patch( required any page, required struct body, string token = "" ){
		var params = duplicate( arguments.body );
		params.id  = arguments.page.getId();

		return call(
			"/api/v1/pages/" & arguments.page.getId(),
			"PATCH",
			params,
			len( arguments.token ) ? arguments.token : ownerToken
		);
	}

	private struct function get( required any page ){
		return call(
			"/api/v1/pages/" & arguments.page.getId(),
			"GET",
			{ id : arguments.page.getId() },
			ownerToken
		);
	}

	private struct function call(
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

		// Named `apiRequest` nowhere here because this helper is the only
		// caller — but note `request` is a CFML scope, so a method of that name
		// could not be called at all.
		var event = this.request(
			route   = arguments.uri,
			params  = arguments.params,
			headers = headers,
			method  = arguments.method
		);

		var body = event.getRenderedContent();

		return {
			"status" : event.getStatusCode(),
			"body"   : isJSON( body ) ? deserializeJSON( body ) : {}
		};
	}

	private function seed(){
		variables.site = sites.createSite( name = "Pages API", slug = PREFIX & "one" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "o@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		// A user who may edit pages but not post raw HTML — the distinction the
		// raw-markup specs above turn on. The seeded `editor` role carries
		// almost nothing, so the permissions are granted explicitly rather than
		// relying on what that role happens to contain.
		variables.editor = users.createUser( site.getId(), "Editor", "e@#PREFIX#one.test", "demo-password-123" );

		var editorRole = roles.getRoleBySlugForSite( "editor", site.getId() );
		roles.grantPermissions( editorRole.getId(), [ "pages.view", "pages.update" ] );
		users.assignRole( editor.getId(), editorRole.getId() );

		variables.parent = pages.createPage(
			siteId = site.getId(),
			title  = "Parent",
			slug   = PREFIX & "parent"
		);

		variables.ownerToken  = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "Owner" ).getPlainToken();
		variables.editorToken = tokens.issue( siteId = site.getId(), userId = editor.getId(), name = "Editor" ).getPlainToken();
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
