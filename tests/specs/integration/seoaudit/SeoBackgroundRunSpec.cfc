/**
 * Starting a run in the background, and what happens when one dies.
 *
 * Threads are where this module can fail in ways nothing else catches: `cgi` is
 * empty on the other side of `cfthread`, an exception in there is invisible to
 * the caller, and a thread killed by a restart cannot mark its own row failed.
 * Each of those is asserted here rather than assumed.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-seobg-";

	function beforeAll(){
		super.beforeAll();

		variables.sites  = getInstance( "SiteService@core" );
		variables.pages  = getInstance( "PageService@pages" );
		variables.audits = getInstance( "SeoAuditService@seoaudit" );
		variables.repo   = getInstance( "SeoAuditRepository@seoaudit" );

		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Background runs", function(){

			beforeEach( function(){
				setup();
				clearRuns();
			} );

			it( "returns at once, with a row already recording the run", function(){
				var audit = audits.start( siteId = site.getId(), siteName = site.getName() );

				expect( audit.getId() ).toBeGT( 0 );
				expect( audit.isRunning() ).toBeTrue();

				waitForFinish( audit.getId() );
			} );

			it( "finishes the run and records findings", function(){
				var started  = audits.start( siteId = site.getId(), siteName = site.getName() );
				var finished = waitForFinish( started.getId() );

				expect( finished.isFinished() ).toBeTrue( "did not finish: " & finished.getNote() );

				// The thread has to carry the fetch base URL across, because
				// `cgi` is empty inside it. If that broke, every URL would come
				// back unreachable and this would be zero.
				expect( finished.getUrlCount() ).toBeGT( 1, "nothing was fetched: " & finished.getNote() );
				expect( audits.getIssues( finished.getId(), site.getId() ) ).notToBeEmpty();
			} );

			it( "refuses a second run while one is going", function(){
				// Two concurrent crawls double the load a site puts on itself
				// for no extra information.
				var first = audits.start( siteId = site.getId(), siteName = site.getName() );

				expect( function(){
					audits.start( siteId = site.getId(), siteName = site.getName() );
				} ).toThrow( type = "SeoAudit.AlreadyRunning" );

				waitForFinish( first.getId() );
			} );

			it( "allows another run once the first has finished", function(){
				var first = audits.start( siteId = site.getId(), siteName = site.getName() );

				waitForFinish( first.getId() );

				var second = audits.start( siteId = site.getId(), siteName = site.getName() );

				expect( second.getId() ).notToBe( first.getId() );

				waitForFinish( second.getId() );
			} );

			describe( "a run that stopped without saying so", function(){

				it( "is marked failed once its heartbeat goes stale", function(){
					// A thread killed by a restart leaves the row `running`.
					// Without this the report polls for ever and every later
					// audit of the site is refused.
					var stuck = audits.createRun( site.getId() );

					backdate( stuck.getId(), 60 );

					var cleared = audits.reconcileStalled( site.getId() );
					var reread  = audits.getAudit( stuck.getId(), site.getId() );

					expect( cleared ).toBe( 1 );
					expect( reread.isFailed() ).toBeTrue();
					expect( reread.getNote() ).toInclude( "stopped without reporting" );
				} );

				it( "stops blocking the next run", function(){
					var stuck = audits.createRun( site.getId() );

					backdate( stuck.getId(), 60 );

					// `start` reconciles first, so this must not throw.
					var next = audits.start( siteId = site.getId(), siteName = site.getName() );

					expect( next.getId() ).notToBe( stuck.getId() );

					waitForFinish( next.getId() );
				} );

				it( "leaves a run that is merely slow alone", function(){
					// The window is what tells dead from slow. A run started a
					// moment ago is slow.
					var fresh = audits.createRun( site.getId() );

					expect( audits.reconcileStalled( site.getId() ) ).toBe( 0 );
					expect( audits.getAudit( fresh.getId(), site.getId() ).isRunning() ).toBeTrue();

					clearRuns();
				} );

			} );

			it( "reports progress as it goes, without inventing a total", function(){
				// A crawl discovers URLs from the pages it has already fetched,
				// so there is no denominator. Two honest counts, no percentage.
				var started  = audits.start( siteId = site.getId(), siteName = site.getName() );
				var finished = waitForFinish( started.getId() );

				expect( finished.getUrlCount() ).toBeGT( 0 );
				expect( finished.getQueuedCount() ).toBeGTE( 0 );
			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * Polls the row until the run stops. Polling rather than joining the
	 * thread, because the thread is spawned inside the service and its name is
	 * not the caller's business.
	 */
	private function waitForFinish( required numeric auditId, numeric seconds = 60 ){
		var deadline = getTickCount() + ( arguments.seconds * 1000 );

		while ( getTickCount() < deadline ) {
			var audit = audits.getAudit( arguments.auditId, site.getId() );

			if ( !isNull( audit ) && !audit.isRunning() ) {
				return audit;
			}

			sleep( 250 );
		}

		return audits.getAudit( arguments.auditId, site.getId() );
	}

	/**
	 * Make a run look old, so the stall window applies to it.
	 */
	private function backdate( required numeric auditId, required numeric minutes ){
		queryExecute(
			"
			UPDATE seo_audits
			SET started_at = :stamp, heartbeat_at = :stamp
			WHERE id = :id
			",
			{
				id    : { value : arguments.auditId, cfsqltype : "cf_sql_bigint" },
				stamp : { value : dateAdd( "n", -arguments.minutes, now() ), cfsqltype : "cf_sql_timestamp" }
			}
		);

		return this;
	}

	private function clearRuns(){
		queryExecute(
			"DELETE FROM seo_audits WHERE site_id = :siteId",
			{ siteId : { value : site.getId(), cfsqltype : "cf_sql_bigint" } }
		);

		return this;
	}

	private function seed(){
		variables.site = sites.createSite( name = "SEO Background", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );

		var home = pages.createPage(
			siteId  = site.getId(),
			title   = "Home page of the background run test site",
			slug    = "home",
			content = "<p>" & repeatString( "Words on the home page. ", 40 ) & "</p>"
		);

		pages.publishPage( home.getId() );
		pages.setHomePage( site.getId(), home.getId() );

		var about = pages.createPage(
			siteId  = site.getId(),
			title   = "About the background run test site",
			slug    = "about",
			content = "<p>" & repeatString( "Words on the about page. ", 40 ) & "</p>"
		);

		pages.publishPage( about.getId() );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
