/**
 * The Media REST resource.
 *
 * Two halves, for two reasons.
 *
 * The reads go through `this.request()` like every other API spec, against rows
 * written straight to the repository — `index` and `show` never open the file,
 * so there is nothing a real upload would prove.
 *
 * The **upload** cannot be driven that way at all. `MediaService.upload()` calls
 * `fileUpload()`, which reads the *real* multipart request; a framework-driven
 * event has none, so it would only ever answer "no file was received". So those
 * specs make a genuine HTTP request back to the server this suite is running
 * on, with `cfhttp`, and the `Host` header picks the tenant. That is also the
 * only way to cover the boundary bug they exist for: a multipart body arrives
 * as a byte array on Adobe ColdFusion, and `ApiHandler.readBody` used to call
 * `trim()` on it — so every upload died before reaching this handler, whatever
 * endpoint it was aimed at.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-mediaapi-";

	// The upload specs need a real server to post to. Read here rather than in
	// `beforeAll` because it decides whether those specs are registered at all,
	// and `skip` is evaluated while the suite is being built.
	variables.OVER_HTTP = len( cgi.server_port ?: "" ) > 0;

	function beforeAll(){
		super.beforeAll();

		variables.tokens  = getInstance( "ApiTokenService@core" );
		variables.sites   = getInstance( "SiteService@core" );
		variables.users   = getInstance( "UserService@core" );
		variables.roles   = getInstance( "RoleService@core" );
		variables.library = getInstance( "MediaService@media" );
		variables.repo    = getInstance( "MediaRepository@media" );

		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The Media API", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "the library", function(){

				it(
					title = "lists this site's files",
					skip  = !OVER_HTTP,
					body  = function(){
						var result = call( "/api/v1/media" );

						expect( result.status ).toBe( 200 );
						expect( result.body.data.len() ).toBe( 3 );
						expect( result.body.meta.total ).toBe( 3 );
				} );

				it( "narrows to one kind", function(){
						// A client inserting an `<img>` wants images and a client
						// placing a download link wants documents; neither is served
						// by being handed the whole library.
						var images = call( "/api/v1/media", { kind : "image" } );

						expect( images.body.meta.total ).toBe( 2 );
						expect( images.body.data.map( ( item ) => item.kind ) ).toBe( [ "image", "image" ] );

						expect( call( "/api/v1/media", { kind : "document" } ).body.meta.total ).toBe( 1 );
				} );

				it( "returns nothing for a kind that does not exist", function(){
						// Rather than ignoring the filter and handing back the whole
						// library, which is an answer a client would act on.
						var result = call( "/api/v1/media", { kind : "sculpture" } );

						expect( result.status ).toBe( 200 );
						expect( result.body.data ).toBeEmpty();
				} );

				it( "pages, and says how to walk the pages", function(){
						var result = call( "/api/v1/media", { perPage : 2 } );

						expect( result.body.data.len() ).toBe( 2 );
						expect( result.body.meta.totalPages ).toBe( 2 );
						expect( result.body.meta.hasNext ).toBeTrue();

						var second = call( "/api/v1/media", { perPage : 2, page : 2 } );

						expect( second.body.data.len() ).toBe( 1 );
						expect( second.body.meta.hasNext ).toBeFalse();
				} );

				it( "carries the URL a page would reference", function(){
						// The field that actually matters: it is what goes into a
						// page's `featuredImage` or `ogImage`.
						var row = call( "/api/v1/media", { kind : "document" } ).body.data[ 1 ];

						expect( row.url ).toBe( "/media/" & PREFIX & "brochure.pdf" );
				} );

			} );

			describe( "one item", function(){

				it( "is readable by id", function(){
						var result = call( "/api/v1/media/" & pdfRow.getId() );

						expect( result.status ).toBe( 200 );
						expect( result.body.data.id ).toBe( pdfRow.getId() );
						expect( result.body.data.kind ).toBe( "document" );
				} );

				it( "answers 404 for an id that does not exist", function(){
						expect( call( "/api/v1/media/999999999" ).status ).toBe( 404 );
				} );

				it( "answers 404 for another site's file, not 403", function(){
						// The same answer as "does not exist", so the API cannot be
						// used to find out which ids are in use on other tenants.
						var result = call( "/api/v1/media/" & elsewhere.getId() );

						expect( result.status ).toBe( 404 );
						expect( result.body.error.code ).toBe( "not_found" );
				} );

			} );

			describe( "the boundary", function(){

				it( "needs a token", function(){
						expect( call( "/api/v1/media", {}, "" ).status ).toBe( 401 );
				} );

				it( "refuses a token without media.view", function(){
						expect( call( "/api/v1/media", {}, strangerToken ).status ).toBe( 403 );
				} );

				it( "is readable by the agent role", function(){
						expect( call( "/api/v1/media", {}, agentToken ).status ).toBe( 200 );
				} );

				it( "exposes no verb but GET on an item", function(){
						// `media.delete` and `media.update` are both withheld from
						// the agent role, so the resource is registered without
						// those verbs rather than carrying endpoints no token can
						// use. Asserted against the built routes, because "the
						// handler has no `remove` method" would still leave the
						// route pointing at an inherited one.
						var member = getInstance( "ApiRouteRegistry@core" )
							.buildRoutes()
							.filter( ( route ) => route.pattern == "/api/v1/media/:id" );

						expect( member.len() ).toBe( 1 );
						expect( member[ 1 ].actions ).toHaveKey( "GET" );
						expect( member[ 1 ].actions ).notToHaveKey( "DELETE" );
						expect( member[ 1 ].actions ).notToHaveKey( "PATCH" );
						expect( member[ 1 ].actions ).notToHaveKey( "PUT" );
				} );

			} );

			describe( "uploading", function(){

				it( "accepts a real multipart POST and stores the file", function(){
						var result = post( pngFile( "logo.png" ), { altText : "A small square" } );

						expect( result.status ).toBe( 201 );
						expect( result.body.data.kind ).toBe( "image" );
						expect( result.body.data.altText ).toBe( "A small square" );
						expect( result.body.data.url ).toInclude( ".png" );

						// And it is genuinely in the library, not merely echoed back.
						expect( isNull( library.getById( result.body.data.id ) ) ).toBeFalse();

						// And the change log recorded it. Asserted here rather
						// than in `ChangeLogSpec` because this is the only place
						// a real multipart upload happens.
						var logged = getInstance( "ChangeLogService@core" )
							.getForSite( siteId = site.getId(), limit = 1, resourceType = "media" );

						expect( logged.len() ).toBe( 1, "the upload was not logged" );
						expect( logged[ 1 ].getAction() ).toBe( "upload" );
						expect( logged[ 1 ].getResourceId() ).toBe( result.body.data.id );
					}
				);

				it(
					title = "refuses a file whose bytes are not what its name claims",
					skip  = !OVER_HTTP,
					body  = function(){
						// A `.png` full of text. The extension allow-list passes it
						// and the content check does not.
						var result = post( textFile( "trojan.png", "<?php echo 1; ?>" ) );

						expect( result.status ).toBe( 422 );
						expect( result.body.error.code ).toBe( "content_mismatch" );

						// The message is written to be shown to whoever tried, and
						// this is the half of the mapping that matters:
						// `failFromException` would answer 500 and withhold it,
						// because `Media.ContentMismatch` matches none of the type
						// shapes it knows.
						expect( result.body.error.message ).toInclude( "not a readable image" );
					}
				);

				it(
					title = "refuses an extension that is not on the allow-list",
					skip  = !OVER_HTTP,
					body  = function(){
						// SVG, specifically: it is an image, and it is excluded on
						// purpose because it is XML that can carry script and would
						// be served from the site's own origin.
						var result = post( textFile( "icon.svg", "<svg xmlns='http://www.w3.org/2000/svg'/>" ) );

						expect( result.status ).toBe( 415 );
						expect( result.body.error.code ).toBe( "unsupported_type" );
					}
				);

				it(
					title = "refuses a request with no file part at all",
					skip  = !OVER_HTTP,
					body  = function(){
						var result = postFields( { altText : "Nothing attached" } );

						expect( result.status ).toBe( 400 );
						expect( result.body.error.code ).toBe( "no_file" );
					}
				);

				it(
					title = "refuses a token without media.upload",
					skip  = !OVER_HTTP,
					body  = function(){
						// `media.view` alone is not enough, and the refusal lands in
						// `preHandler` — before `fileUpload()` writes anything to
						// staging.
						expect( post( pngFile( "refused.png" ), {}, viewerToken ).status ).toBe( 403 );
					}
				);

				it(
					title = "is accepted from the agent role",
					skip  = !OVER_HTTP,
					body  = function(){
						// `media.upload` is one of the nine permissions that role
						// carries, and `upload_media` is the MCP tool that needs it.
						var result = post( pngFile( "by-agent.png" ), { title : "Agent upload" }, agentToken );

						expect( result.status ).toBe( 201 );
						expect( result.body.data.title ).toBe( "Agent upload" );
					}
				);

			} );

		} );
	}

	/* -------------------------------------------------------- framework calls */

	private struct function call(
		required string uri,
		struct params = {},
		string token,
		string method = "GET"
	){
		setup();

		var headers = { "Host" : "#PREFIX#one.test" };
		var bearer  = isNull( arguments.token ) ? ownerToken : arguments.token;

		if ( len( bearer ) ) {
			headers[ "Authorization" ] = "Bearer " & bearer;
		}

		// Named `given`, not `params`: ColdFusion rejects a local that reuses an
		// argument's name outright.
		var given = duplicate( arguments.params );

		// `:id` reaches the handler through `rc` in a framework-driven request,
		// so it has to be passed as a parameter as well as sitting in the route.
		if ( reFind( "/\d+$", arguments.uri ) ) {
			given.id = listLast( arguments.uri, "/" );
		}

		var event = this.request(
			route   = arguments.uri,
			params  = given,
			headers = headers,
			method  = arguments.method
		);

		var body = event.getRenderedContent();

		return {
			"status" : event.getStatusCode(),
			"body"   : isJSON( body ) ? deserializeJSON( body ) : {}
		};
	}

	/* ----------------------------------------------------------- real uploads */

	private struct function post( required string path, struct fields = {}, string token ){
		return upload( arguments.path, arguments.fields, arguments.token ?: ownerToken );
	}

	private struct function postFields( required struct fields, string token ){
		return upload( "", arguments.fields, arguments.token ?: ownerToken );
	}

	/**
	 * A genuine `multipart/form-data` POST to the running server.
	 *
	 * The `Host` header is what selects the tenant, so this reaches the
	 * throwaway site rather than whichever one answers on 127.0.0.1.
	 */
	private struct function upload( required string path, required struct fields, required string token ){
		var response = "";
		var endpoint = "http://127.0.0.1:" & cgi.server_port & "/api/v1/media";

		cfhttp( url = endpoint, method = "post", result = "response", timeout = 30 ) {
			cfhttpparam( type = "header", name = "Host", value = "#PREFIX#one.test" );
			cfhttpparam( type = "header", name = "Authorization", value = "Bearer " & arguments.token );

			for ( var field in arguments.fields ) {
				cfhttpparam( type = "formfield", name = field, value = arguments.fields[ field ] );
			}

			if ( len( arguments.path ) ) {
				cfhttpparam( type = "file", name = "file", file = arguments.path );
			} else {
				// Still a multipart request — a form-encoded POST would be
				// testing something else entirely and would never reach
				// `fileUpload()`.
				cfhttpparam( type = "file", name = "notAFile", file = textFile( "decoy.txt", "x" ) );
			}
		}

		return {
			// `"201 Created"`, so the code is the first token.
			"status" : val( listFirst( response.statusCode ?: "0", " " ) ),
			"body"   : isJSON( response.fileContent ?: "" ) ? deserializeJSON( response.fileContent ) : {}
		};
	}

	/**
	 * A real 2x2 PNG. Real because `verifyContent` hands an image to the image
	 * reader rather than checking a prefix, so no handmade bytes would pass.
	 */
	private string function pngFile( required string name ){
		var path = scratch() & "/" & arguments.name;

		imageWrite( imageNew( "", 2, 2, "rgb", "ffffff" ), path );

		return path;
	}

	private string function textFile( required string name, required string content ){
		var path = scratch() & "/" & arguments.name;

		fileWrite( path, arguments.content );

		return path;
	}

	private string function scratch(){
		var dir = getTempDirectory() & "/" & PREFIX & "fixtures";

		if ( !directoryExists( dir ) ) {
			directoryCreate( dir );
		}

		return dir;
	}

	/* --------------------------------------------------------------- fixtures */

	private function seed(){
		variables.site = sites.createSite( name = "Media API", slug = PREFIX & "one" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.other = sites.createSite( name = "Media API Other", slug = PREFIX & "two" );
		sites.addDomain( other.getId(), "#PREFIX#two.test", true );
		roles.seedDefaultRolesForSite( other.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "o@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.agent = users.createUser( site.getId(), "Agent", "a@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( agent.getId(), roles.getRoleBySlugForSite( "agent", site.getId() ).getId() );

		// May look, may not upload — the pair `media.upload` separates.
		variables.viewer = users.createUser( site.getId(), "Viewer", "v@#PREFIX#one.test", "demo-password-123" );

		var viewerRole = roles.createRole( siteId = site.getId(), name = "Viewer only" );
		roles.grantPermissions( viewerRole.getId(), [ "media.view" ] );
		users.assignRole( viewer.getId(), viewerRole.getId() );

		// And a user with no media permissions at all, for the 403. The stock
		// editor role carries none, which is what makes it the right fixture.
		variables.stranger = users.createUser( site.getId(), "Stranger", "s@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( stranger.getId(), roles.getRoleBySlugForSite( "editor", site.getId() ).getId() );

		variables.ownerToken    = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "Owner" ).getPlainToken();
		variables.agentToken    = tokens.issue( siteId = site.getId(), userId = agent.getId(), name = "Agent" ).getPlainToken();
		variables.viewerToken   = tokens.issue( siteId = site.getId(), userId = viewer.getId(), name = "Viewer" ).getPlainToken();
		variables.strangerToken = tokens.issue( siteId = site.getId(), userId = stranger.getId(), name = "Stranger" ).getPlainToken();

		// Rows rather than uploads: the read endpoints never open the file.
		row( site.getId(), "photo-one.jpg", "image/jpeg", "jpg", "image" );
		row( site.getId(), "photo-two.png", "image/png", "png", "image" );
		variables.pdfRow    = row( site.getId(), "brochure.pdf", "application/pdf", "pdf", "document" );
		variables.elsewhere = row( other.getId(), "not-yours.pdf", "application/pdf", "pdf", "document" );
	}

	private function row(
		required numeric siteId,
		required string name,
		required string mime,
		required string extension,
		required string kind
	){
		return repo.create(
			getInstance( "MediaItem@media" )
				.setSiteId( arguments.siteId )
				.setFilename( PREFIX & arguments.name )
				.setOriginalFilename( arguments.name )
				.setStoredPath( PREFIX & arguments.name )
				.setExtension( arguments.extension )
				.setMimeType( arguments.mime )
				.setKind( arguments.kind )
				.setByteSize( 1024 )
		);
	}

	private function cleanup(){
		// The rows go with the site, by cascade. The files the upload specs
		// actually wrote do not, so they are removed by hand — a media
		// directory nobody owns would otherwise accumulate on every run.
		if ( structKeyExists( variables, "site" ) ) {
			var dir = getDirectoryFromPath( library.absolutePath( site.getId(), "x" ) );

			if ( directoryExists( dir ) ) {
				directoryDelete( dir, true );
			}
		}

		if ( directoryExists( scratch() ) ) {
			directoryDelete( scratch(), true );
		}

		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
