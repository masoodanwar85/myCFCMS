/**
 * The SEO audit REST resource.
 *
 * The single-page endpoint is audited against **real pages over real HTTP**,
 * the same way `SeoAuditRunSpec` does it: the handler resolves a loopback
 * address and spoofs `Host` to reach the throwaway tenant, so a failure here is
 * a real failure and not a test artefact. That is also the only way to prove
 * the thing the endpoint exists for — that every registered check runs against
 * what the theme actually rendered.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-seoapi-";

	function beforeAll(){
		super.beforeAll();

		variables.tokens  = getInstance( "ApiTokenService@core" );
		variables.sites   = getInstance( "SiteService@core" );
		variables.users   = getInstance( "UserService@core" );
		variables.roles   = getInstance( "RoleService@core" );
		variables.pages   = getInstance( "PageService@pages" );
		variables.audits  = getInstance( "SeoAuditService@seoaudit" );

		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The SEO audit API", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "auditing one page", function(){

				it( "fetches the live page and answers with its findings", function(){
					var result = auditPage( "good-page-about-estate-planning" );

					expect( result.status ).toBe( 200 );
					expect( result.body.data.statusCode ).toBe(
						200,
						"the server could not fetch itself: " & ( result.body.data.error ?: "" )
					);
					expect( result.body.data.findings ).toBeArray();
					expect( result.body.data.url ).toInclude( PREFIX & "one.test" );
				} );

				it( "says nothing loud about a page that is written properly", function(){
					// The assertion that keeps the endpoint worth calling. A
					// check that fires on a good page makes every report
					// ignorable.
					var found = checkIds( auditPage( "good-page-about-estate-planning" ) );

					for ( var noisy in [
						"title.missing", "title.tooShort", "description.missing",
						"heading.noH1", "heading.multipleH1", "image.missingAlt",
						"content.thin", "robots.noindex", "link.broken"
					] ) {
						expect( found ).notToInclude( noisy, "fired on a well-formed page: " & noisy );
					}
				} );

				it( "runs the new robots check against the rendered page", function(){
					// `robotsIndex` is a column, but what matters is the tag the
					// theme emitted — which is the whole reason this module
					// reads HTML.
					expect( checkIds( auditPage( "hidden-from-search" ) ) ).toInclude( "robots.noindex" );
				} );

				it( "runs the new structured data check", function(){
					expect( checkIds( auditPage( "good-page-about-estate-planning" ) ) )
						.toInclude( "structuredData.missing" );
				} );

				it( "probes the page's own links and reports the broken one", function(){
					var result = auditPage( "page-with-a-dead-link" );

					expect( result.body.data.checkedLinks ).toBeGT( 0, "no links were probed" );
					expect( checkIds( result ) ).toInclude( "link.broken" );
				} );

				it( "leaves the links alone when told not to check them", function(){
					// One fetch per link is the expensive half of this endpoint,
					// so a caller that only wants the markup checks can say so.
					var result = auditPage( "page-with-a-dead-link", { checkLinks : false } );

					expect( result.body.data.checkedLinks ).toBe( 0 );
					expect( checkIds( result ) ).notToInclude( "link.broken" );
				} );

				it( "audits the home page when given no path", function(){
					// An empty path is a real URL, not a missing argument.
					var result = auditPage( "" );

					expect( result.status ).toBe( 200 );
					expect( result.body.data.path ).toBe( "" );
				} );

				it( "reports an unreachable URL as a finding, not as its own 404", function(){
					// The audit did its job; the answer is "this page is
					// broken". A 404 from the endpoint would leave a client
					// unable to tell that from "no such endpoint".
					var result = auditPage( "nothing-is-served-here" );

					expect( result.status ).toBe( 200 );
					expect( result.body.data.statusCode ).toBe( 404 );
					expect( checkIds( result ).len() ).toBeGT( 0 );
				} );

				it( "counts the findings by severity in the meta block", function(){
					var result = auditPage( "hidden-from-search" );
					var counted = result.body.meta.errors
						+ result.body.meta.warnings
						+ result.body.meta.notices;

					expect( counted ).toBe( result.body.data.findings.len() );
				} );

				it( "needs seo.run, not seo.view", function(){
					// It makes one HTTP request per link. Reading last night's
					// report is free; this is not.
					expect( auditPage( "good-page-about-estate-planning", {}, viewerToken ).status ).toBe( 403 );
				} );

				it( "is allowed for the agent role", function(){
					expect(
						auditPage( "good-page-about-estate-planning", {}, agentToken ).status
					).toBe( 200 );
				} );

			} );

			describe( "the runs collection", function(){

				it( "lists this site's runs", function(){
					clearRuns();

					var finished = audits.createRun( site.getId() );
					audits.execute( auditId = finished.getId(), siteId = site.getId() );

					var result = call( "/api/v1/seo-audits" );

					expect( result.status ).toBe( 200 );
					expect( result.body.data.len() ).toBe( 1 );
					expect( result.body.data[ 1 ].status ).toBe( "finished" );
				} );

				it( "starts a run and answers 202, because the findings are not in the response", function(){
					clearRuns();

					var result = call( "/api/v1/seo-audits", {}, ownerToken, "POST" );

					expect( result.status ).toBe( 202 );
					expect( result.body.data.id ).toBeNumeric();
					expect( result.body.meta.maxUrls ).toBeGT( 0 );

					// A client polls this id; the run itself is on a thread.
					expect( isNull( audits.getAudit( result.body.data.id, site.getId() ) ) ).toBeFalse();
				} );

				it( "refuses a second run while one is going, with a 409", function(){
					// Two concurrent crawls double the load the site puts on
					// itself for no extra information. A row is created directly
					// rather than racing a real run, so this is deterministic.
					clearRuns();
					audits.createRun( site.getId() );

					var result = call( "/api/v1/seo-audits", {}, ownerToken, "POST" );

					expect( result.status ).toBe( 409 );
					expect( result.body.error.code ).toBe( "conflict" );

					clearRuns();
				} );

				it( "needs seo.run to start one", function(){
					expect( call( "/api/v1/seo-audits", {}, viewerToken, "POST" ).status ).toBe( 403 );
				} );

				it( "is readable with seo.view alone", function(){
					expect( call( "/api/v1/seo-audits", {}, viewerToken ).status ).toBe( 200 );
				} );

			} );

			describe( "one run", function(){

				it( "carries the findings and both groupings", function(){
					clearRuns();

					var run = audits.createRun( site.getId() );
					audits.execute( auditId = run.getId(), siteId = site.getId(), siteName = site.getName() );

					var result = call( "/api/v1/seo-audits/" & run.getId() );

					expect( result.status ).toBe( 200 );
					expect( result.body.data.status ).toBe( "finished" );
					expect( result.body.data.findings.len() ).toBeGT( 0 );

					// The same two readings the admin report is built from:
					// "what is wrong with this site" and "what do I fix here".
					expect( result.body.data.byCheck ).toBeArray();
					expect( result.body.data.byPath ).toBeArray();
					expect( result.body.data.byCheck.len() ).toBeGT( 0 );

					var first = result.body.data.findings[ 1 ];

					for ( var key in [ "path", "url", "pageId", "checkId", "severity", "message", "detail" ] ) {
						expect( first ).toHaveKey( key );
					}
				} );

				it( "answers 404 for a run that does not exist", function(){
					expect( call( "/api/v1/seo-audits/999999999" ).status ).toBe( 404 );
				} );

				it( "answers 404 for another site's run, not 403", function(){
					var theirs = audits.createRun( other.getId() );

					expect( call( "/api/v1/seo-audits/" & theirs.getId() ).status ).toBe( 404 );
				} );

			} );

			describe( "the routes", function(){

				it( "puts the collection action above the member pattern", function(){
					// Otherwise `/seo-audits/page` matches `/seo-audits/:id` and
					// the handler is asked for a run whose id is "page".
					var patterns = getInstance( "ApiRouteRegistry@core" )
						.buildRoutes()
						.map( ( route ) => route.pattern );

					var action = patterns.find( "/api/v1/seo-audits/page" );
					var member = patterns.find( "/api/v1/seo-audits/:id" );

					expect( action ).toBeGT( 0, "the collection action was never registered" );
					expect( action ).toBeLT( member );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private struct function auditPage( required string path, struct options = {}, string token ){
		var params = duplicate( arguments.options );
		params.path = arguments.path;

		return call( "/api/v1/seo-audits/page", params, arguments.token ?: ownerToken, "POST" );
	}

	private array function checkIds( required struct result ){
		// Assigned first: ACF will not accept a member call chained off a
		// parenthesised elvis expression.
		var findings = arguments.result.body.data.findings ?: [];

		return findings.map( ( finding ) => finding.checkId );
	}

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

		var given = duplicate( arguments.params );

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

	/**
	 * Remove every run on the test site.
	 *
	 * Called before each spec that cares about how many runs exist, because a
	 * background run left behind by the 202 spec would otherwise make the next
	 * one answer 409.
	 */
	private function clearRuns(){
		audits.reconcileStalled( site.getId() );

		for ( var audit in audits.getAuditsForSite( site.getId(), 100 ) ) {
			audits.deleteAudit( audit.getId(), site.getId() );
		}

		return this;
	}

	private function seed(){
		variables.site = sites.createSite( name = "SEO API", slug = PREFIX & "one" );

		// Primary, so canonical URLs can be built and the site-level finding
		// about a missing primary domain does not fire on every assertion.
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.other = sites.createSite( name = "SEO API Other", slug = PREFIX & "two" );
		sites.addDomain( other.getId(), "#PREFIX#two.test", true );

		variables.owner = users.createUser( site.getId(), "Owner", "o@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.agent = users.createUser( site.getId(), "Agent", "a@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( agent.getId(), roles.getRoleBySlugForSite( "agent", site.getId() ).getId() );

		// May read a report, may not start one — the split both the admin and
		// this resource are built around.
		variables.viewer = users.createUser( site.getId(), "Viewer", "v@#PREFIX#one.test", "demo-password-123" );

		var viewerRole = roles.createRole( siteId = site.getId(), name = "Report reader" );
		roles.grantPermissions( viewerRole.getId(), [ "seo.view" ] );
		users.assignRole( viewer.getId(), viewerRole.getId() );

		variables.ownerToken  = tokens.issue( siteId = site.getId(), userId = owner.getId(), name = "Owner" ).getPlainToken();
		variables.agentToken  = tokens.issue( siteId = site.getId(), userId = agent.getId(), name = "Agent" ).getPlainToken();
		variables.viewerToken = tokens.issue( siteId = site.getId(), userId = viewer.getId(), name = "Viewer" ).getPlainToken();

		// A home page, and the setting that makes `/` serve it. Without one the
		// theme's own link to `/` is a 404, and every page on the site would
		// legitimately be reported for linking to a URL that does not work —
		// true, and nothing to do with the page being audited.
		var home = pages.createPage(
			siteId          = site.getId(),
			title           = "Wills and estates for families across Victoria",
			slug            = "home",
			metaTitle       = "Wills and estates for families across Victoria",
			metaDescription = "Plain-English help with wills, probate and estate administration "
				& "for families who own property in Victoria.",
			content         = "<p>" & repeatString( "What we do and who we do it for. ", 40 ) & "</p>"
		);

		publish( home );
		pages.setHomePage( site.getId(), home.getId() );

		// A page nothing should be reported about.
		publish( pages.createPage(
			siteId          = site.getId(),
			title           = "Estate planning advice for Victorian families",
			slug            = "good-page-about-estate-planning",
			metaTitle       = "Estate planning advice for Victorian families",
			metaDescription = "How to plan your estate in Victoria, what a will needs to cover, "
				& "and when to review it. Written for families with property and dependants.",
			content         = "<p>" & repeatString( "Estate planning is the process of arranging your affairs. ", 60 ) & "</p>"
		) );

		// Indexing switched off, so the theme emits `<meta name="robots">`.
		publish( pages.createPage(
			siteId          = site.getId(),
			title           = "A page deliberately kept out of search results",
			slug            = "hidden-from-search",
			metaTitle       = "A page deliberately kept out of search results",
			metaDescription = "Not for search engines, but still a page somebody can reach and read "
				& "if they are given the address by hand.",
			content         = "<p>" & repeatString( "Copy on a page that search engines are asked to skip. ", 40 ) & "</p>",
			seo             = { robotsIndex : false }
		) );

		// Links at a URL nothing serves, so the link probe sees the 404 and
		// attributes it to this page.
		publish( pages.createPage(
			siteId          = site.getId(),
			title           = "A page that links somewhere that is gone",
			slug            = "page-with-a-dead-link",
			metaTitle       = "A page that links somewhere that is gone",
			metaDescription = "Carries one link to an address that nothing answers on, which is what "
				& "the single-page link probe is here to notice.",
			content         = '<p><a href="/zzt-this-page-does-not-exist">A dead link</a></p><p>'
				& repeatString( "Supporting copy so the page is not thin. ", 40 ) & "</p>"
		) );
	}

	private function publish( required any page ){
		return pages.publishPage( arguments.page.getId() );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
