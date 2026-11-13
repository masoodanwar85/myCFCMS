/**
 * The API change log.
 *
 * Asserted through the API rather than against `ChangeLogService` directly,
 * because the thing worth proving is not that the service can insert a row —
 * it is that **every write endpoint actually calls it**, with a `before` taken
 * at the one moment the previous state still existed. A service with perfect
 * coverage and a handler that forgot to call it logs nothing.
 *
 * The media upload's entry is asserted in `MediaApiSpec`, where the real
 * multipart request lives.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-changelog-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();

		variables.tokens  = getInstance( "ApiTokenService@core" );
		variables.sites   = getInstance( "SiteService@core" );
		variables.users   = getInstance( "UserService@core" );
		variables.roles   = getInstance( "RoleService@core" );
		variables.pages   = getInstance( "PageService@pages" );
		variables.auth    = getInstance( "AuthenticationService@core" );
		variables.changes = getInstance( "ChangeLogService@core" );

		cleanup();
		seed();
	}

	function afterAll(){
		auth.logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The API change log", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "what the endpoints record", function(){

				it( "records a page created through the API", function(){
					var before = count();

					var created = call( "/api/v1/pages", "POST", {
						title   : "Logged on create",
						slug    : PREFIX & "created",
						content : "<p>Body.</p>"
					} );

					expect( created.status ).toBe( 201 );
					expect( count() ).toBe( before + 1 );

					var entry = latest();

					expect( entry.getAction() ).toBe( "create" );
					expect( entry.getResourceType() ).toBe( "page" );
					expect( entry.getResourceId() ).toBe( created.body.data.id );

					// Who, and with which credential. Both, because a site may
					// have several tokens acting as the same user.
					expect( entry.getUserId() ).toBe( owner.getId() );
					expect( entry.getTokenId() ).toBeNumeric();

					// Nothing existed before, so the create's own fields are
					// all "changed" — which is how the log reads as a record of
					// what it set.
					expect( entry.getBeforeJson() ).toBe( "{}" );
					expect( entry.changedFields() ).toInclude( "title" );
				} );

				it( "records only the fields an update actually changed", function(){
					// The reason the `before` snapshot is taken in the handler
					// before anything is written: a log that said "forty fields
					// changed" on every PATCH would be unreadable.
					var page = newPage( "Original title" );

					patch( page, { title : "Changed title" } );

					var entry = latest();

					expect( entry.getAction() ).toBe( "update" );
					expect( entry.changedFields() ).toInclude( "title" );
					expect( entry.changedFields() ).notToInclude( "slug" );
					expect( entry.changedFields() ).notToInclude( "content" );
				} );

				it( "keeps the previous value, not just the field name", function(){
					var page = newPage( "The value it had" );

					patch( page, { metaTitle : "A new meta title" } );

					var entry = latest();
					var was   = deserializeJSON( entry.getBeforeJson() );

					expect( was.title ).toBe( "The value it had" );
					expect( deserializeJSON( entry.getAfterJson() ).metaTitle ).toBe( "A new meta title" );
				} );

				it( "records publishing as its own action, not as an update", function(){
					// "Who published this" is the question asked of the log most
					// often, and answering it should not mean diffing two
					// snapshots to spot a `status` field.
					var page = newPage( "Published through the API" );

					call( "/api/v1/pages/" & page.getId() & "/publish", "POST", { id : page.getId() } );

					var entry = latest();

					expect( entry.getAction() ).toBe( "publish" );
					expect( deserializeJSON( entry.getAfterJson() ).status ).toBe( "published" );
				} );

				it( "records unpublishing separately as well", function(){
					var page = newPage( "Then hidden again" );

					call( "/api/v1/pages/" & page.getId() & "/publish", "POST", { id : page.getId() } );
					call( "/api/v1/pages/" & page.getId() & "/unpublish", "POST", { id : page.getId() } );

					expect( latest().getAction() ).toBe( "unpublish" );
				} );

				it( "keeps what a deleted page said, which is the only record left of it", function(){
					var page = newPage( "About to be deleted" );

					call( "/api/v1/pages/" & page.getId(), "DELETE", { id : page.getId() } );

					var entry = latest();

					expect( entry.getAction() ).toBe( "delete" );
					expect( entry.getAfterJson() ).toBe( "{}" );
					expect( deserializeJSON( entry.getBeforeJson() ).title ).toBe( "About to be deleted" );

					// And the entry survives the row it describes.
					expect( isNull( pages.getPageById( page.getId() ) ) ).toBeTrue();
					expect( entry.getResourceId() ).toBe( page.getId() );
				} );

				it( "records nothing for a read", function(){
					// A log of every GET would be an access log: much larger, a
					// different thing, and it would bury the entries that say
					// somebody changed something.
					var before = count();

					call( "/api/v1/pages", "GET" );
					call( "/api/v1/pages/" & newPageId(), "GET" );

					expect( count() ).toBe( before );
				} );

				it( "records nothing for a refused request", function(){
					var before = count();

					var refused = call(
						"/api/v1/pages",
						"POST",
						{ title : "Should not be logged", slug : PREFIX & "refused" },
						readOnlyToken
					);

					expect( refused.status ).toBe( 403 );
					expect( count() ).toBe( before );
				} );

			} );

			describe( "reading it", function(){

				it( "is scoped to one site", function(){
					// A tenant must not be able to read what happened on
					// another, even though both wrote through the same handler.
					newPage( "On the first site" );
					call( "/api/v1/pages", "POST", { title : "Logged here", slug : PREFIX & "here" } );

					expect( changes.countForSite( other.getId() ) ).toBe( 0 );
					expect( changes.countForSite( site.getId() ) ).toBeGT( 0 );
				} );

				it( "narrows to one resource type", function(){
					expect( changes.countForSite( site.getId(), "media" ) ).toBe( 0 );
					expect( changes.countForSite( site.getId(), "page" ) ).toBe(
						changes.countForSite( site.getId() )
					);
				} );

				it( "narrows to one thing's history", function(){
					var page = newPage( "Changed twice" );

					patch( page, { title : "Once" } );
					patch( page, { title : "Twice" } );

					expect( changes.countForSite( site.getId(), "page", page.getId() ) ).toBe( 2 );
				} );

				it( "names the user and the token without a second query", function(){
					call( "/api/v1/pages", "POST", { title : "Attributed", slug : PREFIX & "attributed" } );

					var entry = latest();

					expect( entry.getUserName() ).toBe( "Owner" );
					expect( entry.getTokenName() ).toBe( "Owner token" );
				} );

			} );

			describe( "a log that cannot be written", function(){

				it( "does not fail the request that already succeeded", function(){
					// By the time the entry is written the page exists. Refusing
					// the response would tell the client the change did not
					// happen when it did — and a client that retried would
					// create it twice.
					var broken = createMock( "core.models.api.ChangeLogService" );

					broken.$property( "wirebox", "variables", getWireBox() );
					broken.$property(
						"log",
						"variables",
						createStub().$( "error" ).$( "warn" )
					);
					broken.$property(
						"repository",
						"variables",
						createStub().$( method = "create", throwException = true, throwType = "Database" )
					);

					// Returns rather than throwing, which is the whole contract,
					// and returns nothing — so a caller cannot mistake a failed
					// entry for a written one.
					var written = broken.record(
						siteId       = site.getId(),
						action       = "create",
						resourceType = "page"
					);

					expect( isNull( written ) ).toBeTrue();
				} );

			} );

			describe( "the screen", function(){

				beforeEach( function(){
					auth.logout();
					getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
					auth.startSessionFor( variables.owner, variables.site.getId() );
				} );

				afterEach( function(){
					auth.logout();
				} );

				it( "renders, which a template error would otherwise only show in production", function(){
					call( "/api/v1/pages", "POST", { title : "Shown on the screen", slug : PREFIX & "screen" } );

					var html = render( "/admin/api-activity" );

					expect( html ).toInclude( "API activity" );
					expect( html ).toInclude( "Owner token" );
					expect( html ).toInclude( "create" );
				} );

				it( "renders with an empty log, which is how every site starts", function(){
					getInstance( "TenantContext@core" ).setCurrentTenant( variables.other );
					auth.logout();
					auth.startSessionFor( variables.otherOwner, variables.other.getId() );

					var event = this.request(
						route   = "/admin/api-activity",
						headers = { "Host" : "#PREFIX#two.test" },
						method  = "GET"
					);

					var html = event.getRenderedContent() & ( event.getHandlerResults() ?: "" );

					expect( html ).toInclude( "Nothing has been changed through the API yet" );
				} );

				it( "refuses somebody without api.tokens.manage", function(){
					auth.logout();
					getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
					auth.startSessionFor( variables.reader, variables.site.getId() );

					// SecuredHandler refuses by redirecting, so the body is a
					// redirect rather than the screen.
					var html = render( "/admin/api-activity" );

					expect( html ).notToInclude( "Owner token" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private numeric function count(){
		return changes.countForSite( site.getId() );
	}

	private function latest(){
		var found = changes.getForSite( siteId = site.getId(), limit = 1 );

		expect( found.len() ).toBe( 1, "nothing was logged" );

		return found[ 1 ];
	}

	private function newPage( required string title ){
		return pages.createPage(
			siteId  = site.getId(),
			title   = arguments.title,
			slug    = PREFIX & createUUID().lCase().left( 8 ),
			content = "<p>Body copy.</p>"
		);
	}

	private numeric function newPageId(){
		return newPage( "Read only" ).getId();
	}

	private struct function patch( required any page, required struct body ){
		var params = duplicate( arguments.body );
		params.id  = arguments.page.getId();

		return call( "/api/v1/pages/" & arguments.page.getId(), "PATCH", params );
	}

	private struct function call(
		required string uri,
		string method = "GET",
		struct params = {},
		string token  = ""
	){
		setup();

		var headers = {
			"Host"          : "#PREFIX#one.test",
			"Authorization" : "Bearer " & ( len( arguments.token ) ? arguments.token : ownerToken )
		};

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

	private string function render( required string uri ){
		setup();

		var event = this.request(
			route   = arguments.uri,
			headers = { "Host" : "#PREFIX#one.test" },
			method  = "GET"
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.site = sites.createSite( name = "Change log", slug = PREFIX & "one" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.other = sites.createSite( name = "Change log other", slug = PREFIX & "two" );
		sites.addDomain( other.getId(), "#PREFIX#two.test", true );
		roles.seedDefaultRolesForSite( other.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "o@#PREFIX#one.test", PASSWORD );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.otherOwner = users.createUser( other.getId(), "Other owner", "o@#PREFIX#two.test", PASSWORD );
		users.assignRole( otherOwner.getId(), roles.getRoleBySlugForSite( "owner", other.getId() ).getId() );

		// Can read pages and nothing else — for the "a refused request is not
		// logged" assertion, and for the screen's own permission.
		variables.reader = users.createUser( site.getId(), "Reader", "r@#PREFIX#one.test", PASSWORD );

		var readerRole = roles.createRole( siteId = site.getId(), name = "Page reader" );
		roles.grantPermissions( readerRole.getId(), [ "pages.view" ] );
		users.assignRole( reader.getId(), readerRole.getId() );

		variables.ownerToken = tokens
			.issue( siteId = site.getId(), userId = owner.getId(), name = "Owner token" )
			.getPlainToken();

		variables.readOnlyToken = tokens
			.issue( siteId = site.getId(), userId = reader.getId(), name = "Reader token" )
			.getPlainToken();
	}

	private function cleanup(){
		// Entries go with the site by cascade, which is also asserted above by
		// the delete spec surviving its page.
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
