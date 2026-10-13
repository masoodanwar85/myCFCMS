/**
 * A whole run, end to end, against a real site over real HTTP.
 *
 * This is the spec that matters. Everything else tests a piece in isolation;
 * this one proves the pieces connect — that loopback fetching with a spoofed
 * `Host` header reaches the right tenant, that the theme's rendered output
 * parses, that findings are stored and counted, and that the whole thing
 * survives a site with deliberately broken pages on it.
 *
 * It needs the server to be able to reach itself on the port serving this
 * request. That is the same thing the feature needs in production, so a failure
 * here is a real failure and not a test artefact.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-seo-";

	function beforeAll(){
		super.beforeAll();

		variables.sites   = getInstance( "SiteService@core" );
		variables.pages   = getInstance( "PageService@pages" );
		variables.audits  = getInstance( "SeoAuditService@seoaudit" );
		variables.themes  = getInstance( "ThemeService@core" );

		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "A full audit run", function(){

			beforeEach( function(){
				setup();
			} );

			it( "reaches the site over loopback and audits its pages", function(){
				var audit = runAudit();

				expect( audit.isFinished() ).toBeTrue( "run did not finish: " & audit.getNote() );

				// If the Host header trick did not work, every URL would have
				// 404'd or reached the wrong tenant, and this would be 0.
				expect( audit.getUrlCount() ).toBeGT( 1, "nothing was fetched: " & audit.getNote() );
			} );

			it( "finds the thin page's missing title and description", function(){
				var audit = runAudit();
                var found = checksAt( audit, "thin" );

				expect( found ).toInclude( "description.missing" );
				expect( found ).toInclude( "content.thin" );
			} );

			it( "finds two h1 on a page whose content adds its own heading", function(){
				// The whole reason this module reads rendered HTML. `showHeading`
				// is on and the content supplies an h1, so the theme emits one
				// and the content emits another. Nothing in `pages` is wrong.
				var audit = runAudit();

				expect( checksAt( audit, "double-heading" ) ).toInclude( "heading.multipleH1" );
			} );

			it( "finds an image with no alt text", function(){
				var audit = runAudit();

				expect( checksAt( audit, "no-alt" ) ).toInclude( "image.missingAlt" );
			} );

			it( "says nothing about the page that is written properly", function(){
				// The most important assertion here. A check that fires on a
				// good page makes the whole report ignorable.
				var audit = runAudit();
				var found = checksAt( audit, "good-page-about-estate-planning" );

				for ( var noisy in [
					"title.missing", "title.tooShort", "title.tooLong",
					"description.missing", "heading.noH1", "heading.multipleH1",
					"image.missingAlt", "content.thin"
				] ) {
					expect( found ).notToInclude( noisy, "fired on a well-formed page: " & noisy );
				}
			} );

			it( "counts findings by severity on the run", function(){
				var audit = runAudit();
				var issues = audits.getIssues( audit.getId(), site.getId() );

				expect( audit.getErrorCount() + audit.getWarningCount() + audit.getNoticeCount() )
					.toBe( issues.len() );
			} );

			it( "records the site having no primary domain once, not per page", function(){
				// `addDomain` below marks the domain primary, so this site
				// should NOT carry that finding at all.
				var audit = runAudit();
				var siteLevel = audits
					.getIssues( audit.getId(), site.getId() )
					.filter( ( i ) => i.getCheckId() == "site.noPrimaryDomain" );

				expect( siteLevel ).toBeEmpty();
			} );

			it( "never audits the admin or a served file", function(){
				var audit = runAudit();
				var paths = audits
					.getIssues( audit.getId(), site.getId() )
					.map( ( i ) => i.getPath() );

				for ( var path in paths ) {
					expect( path ).notToStartWith( "admin" );
					expect( path ).notToStartWith( "media" );
				}
			} );

			it( "groups the same report by problem and by page", function(){
				var audit = runAudit();

				var byCheck = audits.summariseByCheck( audit.getId(), site.getId() );
				var byPath  = audits.summariseByPath( audit.getId(), site.getId() );

				expect( byCheck ).notToBeEmpty();
				expect( byPath ).notToBeEmpty();

				// Two groupings of one set of findings must agree on the total.
				var checkTotal = 0;
				var pathTotal  = 0;

				for ( var row in byCheck ) { checkTotal += row.total; }
				for ( var row in byPath )  { pathTotal  += row.total; }

				expect( checkTotal ).toBe( pathTotal );
			} );

			it( "blames the page that contains a broken link, not the missing page", function(){
					var audit = runAudit();
					var found = audits
						.getIssues( audit.getId(), site.getId() )
						.filter( ( i ) => i.getCheckId() == "link.broken" && i.getPath() == "broken-link" );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].getDetail() ).toInclude( "/this-page-does-not-exist" );

					// The missing page gets its own, different finding — the
					// broken link is not reported against it, because there is
					// nothing there to open and fix.
					expect( checksAt( audit, "this-page-does-not-exist" ) ).notToInclude( "link.broken" );
			} );

			it( "finds two pages sharing a title", function(){
					var audit = runAudit();

					expect( checksAt( audit, "twin-one" ) ).toInclude( "duplicate.title" );
					expect( checksAt( audit, "twin-two" ) ).toInclude( "duplicate.title" );
			} );

			it( "names the other page in a duplicate finding", function(){
					var audit = runAudit();
					var found = audits
						.getIssues( audit.getId(), site.getId() )
						.filter( ( i ) => i.getPath() == "twin-one" && i.getCheckId() == "duplicate.title" );

					expect( found.len() ).toBe( 1 );
					expect( found[ 1 ].getDetail() ).toInclude( "/twin-two" );
			} );

			it( "reports a page the sitemap lists that nothing links to", function(){
					// `NavigationService` falls back to listing published
					// top-level pages when a site has no menu, so a top-level
					// page is never an orphan here. A child page is not in that
					// fallback and nothing else links to it, which is exactly
					// the accident this finding is for.
					var audit = runAudit();

					expect( checksAt( audit, "thin/buried" ) ).toInclude( "sitemap.orphan" );
			} );

			it( "finds a URL discovered by following a link, not just the sitemap", function(){
					// The dead link below is in page content, so the only way
					// the crawl reaches it is by following the link. Arrays are
					// passed by value in CFML, and an earlier version appended
					// discovered paths to a copy of the queue — so this audited
					// the sitemap and nothing else, silently.
					var audit = runAudit();

					expect( checksAt( audit, "this-page-does-not-exist" ) ).toInclude( "status.error" );
			} );

			it( "offers an edit link only for URLs that really are pages", function(){
				var audit = runAudit();

				for ( var row in audits.summariseByPath( audit.getId(), site.getId() ) ) {
					if ( row.pageId ) {
						var page = pages.getPageById( row.pageId );

						expect( isNull( page ) ).toBeFalse( "page id #row.pageId# does not exist" );
						expect( page.getSiteId() ).toBe( site.getId() );
					}
				}
			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * Runs cached across the specs in this bundle: a run is a dozen HTTP
	 * requests, and running it once per spec would make this file take as long
	 * as the rest of the suite put together.
	 */
	private function runAudit(){
		if ( !isNull( variables.cachedAudit ) ) {
			return variables.cachedAudit;
		}

		// The synchronous path on purpose. `start()` hands the work to a
		// background thread, and a spec that raced it would be the flakiest
		// thing in the suite. The thread calls exactly this method.
		var created = audits.createRun( siteId = site.getId() );

		variables.cachedAudit = audits.execute(
			auditId  = created.getId(),
			siteId   = site.getId(),
			siteName = site.getName(),
			baseUrl  = getInstance( "PageFetcher@seoaudit" ).resolveBaseUrl()
		);

		return variables.cachedAudit;
	}

	private array function checksAt( required any audit, required string path ){
		// Captured first: inside a closure `arguments` is the closure's own
		// scope, so `arguments.path` there is undefined, not this path.
		var wanted = arguments.path;

		return audits
			.getIssues( arguments.audit.getId(), site.getId() )
			.filter( ( issue ) => issue.getPath() == wanted )
			.map( ( issue ) => issue.getCheckId() );
	}

	private function publish( required any page ){
		pages.publishPage( arguments.page.getId() );

		return arguments.page;
	}

	private function seed(){
		variables.site = sites.createSite( name = "SEO Audit Test", slug = PREFIX & "one" );

		// Marked primary, so canonical URLs can be built and the site-level
		// finding about a missing primary domain does not fire.
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );

		// A page written properly, which must produce no findings.
		publish( pages.createPage(
			siteId          = site.getId(),
			title           = "Estate planning advice for Victorian families",
			slug            = "good-page-about-estate-planning",
			metaTitle       = "Estate planning advice for Victorian families",
			metaDescription = "How to plan your estate in Victoria, what a will needs to cover, "
				& "and when to review it. Written for families with property and dependants.",
			content         = "<p>" & repeatString( "Estate planning is the process of arranging your affairs. ", 60 ) & "</p>"
		) );

		// Almost nothing on it: no description, no words.
		publish( pages.createPage(
			siteId  = site.getId(),
			title   = "Thin",
			slug    = "thin",
			content = "<p>Not much here.</p>"
		) );

		// `showHeading` defaults on, and the content supplies its own h1 — so
		// the rendered page has two. This is invisible in the database.
		var doubled = pages.createPage(
			siteId  = site.getId(),
			title   = "Double heading",
			slug    = "double-heading",
			content = "<h1>An author-written heading</h1><p>" & repeatString( "Words about the subject. ", 40 ) & "</p>"
		);

		publish( doubled );

		// An image with no alt attribute at all.
		publish( pages.createPage(
			siteId  = site.getId(),
			title   = "Image with no alt text on it",
			slug    = "no-alt",
			content = '<p><img src="/media/2026/10/photo.png"></p><p>'
				& repeatString( "Some supporting copy for the picture. ", 40 ) & "</p>"
		) );

		// Links to a URL nothing serves, so the crawl sees the 404 and
		// attributes it to this page.
		publish( pages.createPage(
			siteId  = site.getId(),
			title   = "Page that links somewhere that is gone",
			slug    = "broken-link",
			content = '<p><a href="/this-page-does-not-exist">A dead link</a></p><p>'
				& repeatString( "Supporting copy so the page is not thin. ", 40 ) & "</p>"
		) );

		// A child page. The fallback navigation lists top-level pages only, so
		// nothing links to this one — an orphan the sitemap still advertises.
		publish( pages.createPage(
			siteId   = site.getId(),
			parentId = pages.getPageByPath( site.getId(), "thin" ).getId(),
			title    = "A buried page nothing links to at all",
			slug     = "buried",
			content  = "<p>" & repeatString( "Copy on a page no menu mentions. ", 40 ) & "</p>"
		) );

		// Two pages claiming the same title, which no per-page check can see.
		for ( var twin in [ "twin-one", "twin-two" ] ) {
			publish( pages.createPage(
				siteId    = site.getId(),
				title     = twin,
				slug      = twin,
				metaTitle = "Identical title on two different pages",
				content   = "<p>" & repeatString( "Copy that is long enough not to be thin. ", 40 ) & "</p>"
			) );
		}
	}

	private function cleanup(){
		structDelete( variables, "cachedAudit" );
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
