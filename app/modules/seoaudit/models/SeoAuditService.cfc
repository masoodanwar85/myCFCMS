/**
 * Running an audit.
 *
 * Fetch a URL, parse it, ask every registered check what is wrong with it, add
 * any internal links it found to the queue, repeat until the queue empties or
 * the budget runs out. Write the findings once at the end.
 *
 * ## Why this runs in the request, for now
 *
 * A run is one HTTP request per URL, so a hundred-page site is a hundred
 * sequential fetches — seconds, not milliseconds. That is too slow to be
 * comfortable in a request/response cycle, and the honest fix is a background
 * thread with the run row as its progress record. That is the next step; this
 * step keeps it synchronous and bounded by `maxUrls` so it cannot run away,
 * and the admin screen says how long it took.
 *
 * ## Why findings are written in one go
 *
 * Six hundred inserts is most of what a run would otherwise cost. They are
 * accumulated and written as a single statement, which also means a run that
 * dies partway leaves no half-written report — the audit row stays `running`
 * and is visibly incomplete rather than quietly wrong.
 */
component singleton accessors="true" {

	property name="repository" inject="SeoAuditRepository@seoaudit";
	property name="discovery"  inject="UrlDiscovery@seoaudit";
	property name="fetcher"    inject="PageFetcher@seoaudit";
	property name="checks"      inject="SeoCheckRegistry@seoaudit";
	property name="crawlChecks" inject="SeoCrawlCheckRegistry@seoaudit";
	property name="analytics"  inject="AnalyticsService@core";
	property name="domains"    inject="SiteDomainRepository@core";
	property name="settings"   inject="coldbox:moduleSettings:seoaudit";
	property name="wirebox"    inject="wirebox";
	property name="log"        inject="logbox:logger:{this}";

	/**
	 * Audit one site.
	 *
	 * @siteId   The site to audit.
	 * @siteName Used by checks that compare a title against it.
	 * @runBy    The acting user, for the record.
	 */
	/**
	 * Start a run in the background and return its record immediately.
	 *
	 * This is what the admin screen calls. A run is one HTTP request per URL,
	 * so a site with a hundred pages takes long enough that holding the
	 * request open is the wrong shape — the browser waits on a blank tab, a
	 * proxy may time out and kill it halfway, and nothing can be shown about
	 * what is happening.
	 *
	 * Two things have to be settled *here*, on the request thread, because they
	 * are unavailable on the other side of `cfthread`:
	 *
	 *   - **The fetch base URL**, which reads `cgi.server_port`. `cgi` is empty
	 *     in a thread, so a run that derived it there would fetch port 80 and
	 *     report every page as unreachable.
	 *   - **Whether a run is already going**, because two concurrent crawls
	 *     double the load a site puts on itself for no extra information.
	 *
	 * @throws SeoAudit.AlreadyRunning
	 */
	seoaudit.models.SeoAudit function start(
		required numeric siteId,
		string siteName = "",
		numeric runBy
	){
		reconcileStalled( arguments.siteId );

		var existing = repository.findRunningForSite( arguments.siteId );

		if ( !isNull( existing ) ) {
			throw(
				type    = "SeoAudit.AlreadyRunning",
				message = "An audit of this site is already running. Wait for it to finish, or delete it."
			);
		}

		var audit = isNull( arguments.runBy )
			? createRun( arguments.siteId )
			: createRun( arguments.siteId, arguments.runBy );

		var target = fetcher.resolveTarget( arguments.siteId );

		var work = {
			"auditId"    : audit.getId(),
			"siteId"     : arguments.siteId,
			"siteName"   : arguments.siteName,
			"baseUrl"    : target.baseUrl,
			"hostHeader" : target.hostHeader
		};

		// `attributes` rather than closure capture: a thread does not share the
		// spawning request's variables scope, and reading them from it is
		// undefined behaviour the moment the request ends.
		thread
			name       = "seoaudit-#audit.getId()#-#createUUID()#"
			action     = "run"
			work       = work
		{
			// Nothing outside this block can see an exception raised in here,
			// so the thread is responsible for recording its own failure.
			var service = application.cbController.getWireBox().getInstance( "SeoAuditService@seoaudit" );

			service.execute(
				auditId    = attributes.work.auditId,
				siteId     = attributes.work.siteId,
				siteName   = attributes.work.siteName,
				baseUrl    = attributes.work.baseUrl,
				hostHeader = attributes.work.hostHeader
			);
		}

		return audit;
	}

	/**
	 * Create the row a run will report into, without starting one.
	 *
	 * Separate from `start()` so the two callers share it: the admin screen,
	 * which then hands the work to a thread, and anything that wants to run
	 * synchronously and wait — a spec, or a command-line task.
	 */
	seoaudit.models.SeoAudit function createRun( required numeric siteId, numeric runBy ){
		var audit = wirebox
			.getInstance( "SeoAudit@seoaudit" )
			.setSiteId( arguments.siteId )
			.setStatus( "running" );

		if ( !isNull( arguments.runBy ) ) {
			audit.setRunBy( arguments.runBy );
		}

		return repository.createAudit( audit );
	}

	/**
	 * Perform a run against an audit row that already exists.
	 *
	 * Public because the background thread calls it on a freshly resolved
	 * instance of this service, and because a caller that genuinely wants to
	 * wait — a spec, a CLI task — should be able to.
	 */
	seoaudit.models.SeoAudit function execute(
		required numeric auditId,
		required numeric siteId,
		string siteName   = "",
		string baseUrl    = "",
		string hostHeader = ""
	){
		var audit = repository.findAuditById( arguments.auditId, arguments.siteId );

		if ( isNull( audit ) ) {
			throw( type = "SeoAudit.NotFound", message = "No audit [#arguments.auditId#] on this site." );
		}

		var budget    = max( 1, val( settings.maxUrls ?: 250 ) );
		var seeds     = discovery.seedFor( arguments.siteId );
		var pageIndex = discovery.pageIndexFor( arguments.siteId );
		var hosts     = discovery.domainsFor( arguments.siteId );

		// Which URLs came from the sitemap, so the reconciliation check can
		// tell an orphan from a page that was only ever discovered by a link.
		var seeded = {};

		for ( var seed in seeds ) {
			seeded[ seed ] = true;
		}

		var queue    = duplicate( seeds );
		var seen     = {};
		var findings = [];
		var crawled  = [];
		var fetched  = 0;
		var notes    = [];

		try {
			while ( arrayLen( queue ) && fetched < budget ) {
				var path = discovery.normalisePath( queue[ 1 ] );

				arrayDeleteAt( queue, 1 );

				if ( structKeyExists( seen, path ) ) {
					continue;
				}

				seen[ path ] = true;
				fetched++;

				var result = fetcher.fetch( arguments.siteId, path, arguments.baseUrl, arguments.hostHeader );
				var doc    = wirebox.getInstance( "HtmlDocument@seoaudit" ).loadHtml( result.body );

				var context = {
					"siteId"      : arguments.siteId,
					"siteName"    : arguments.siteName,
					"path"        : path,
					"absoluteUrl" : fetcher.publicUrl( arguments.siteId, path ),
					"statusCode"  : result.statusCode,
					"location"    : result.location,
					"fetchError"  : result.error,
					"elapsedMs"   : result.elapsedMs
				};

				var rendered = result.statusCode == 200 && doc.isParsed();
				var produced = rendered ? checks.inspect( doc, context ) : statusOnly( doc, context );
				var pageId   = pageIdFor( pageIndex, path );

				for ( var finding in produced ) {
					var row = {
						"path"     : path,
						"checkId"  : finding.checkId,
						"severity" : finding.severity,
						"message"  : finding.message,
						"detail"   : finding.detail
					};

					// Set only when the path really is a page. Assigning null
					// to a struct key does not create it on Adobe, so the key
					// is omitted rather than nulled — and `addIssues` reads a
					// missing key as SQL NULL.
					if ( pageId ) {
						row.pageId = pageId;
					}

					findings.append( row );
				}

				// What the crawl-wide checks will need afterwards. Collected
				// here because the parsed document is thrown away at the end of
				// this iteration — keeping a hundred DOMs in memory to ask them
				// two questions later would be the expensive way round.
				var outbound = rendered ? internalLinks( doc, hosts ) : [];

				crawled.append( {
					"path"        : path,
					"statusCode"  : result.statusCode,
					"title"       : rendered ? doc.title() : "",
					"description" : rendered ? doc.metaByName( "description" ) : "",
					"canonical"   : rendered ? doc.linkByRel( "canonical" ) : "",
					"links"       : outbound,
					"seeded"      : structKeyExists( seeded, path )
				} );

				if ( rendered ) {
					queue = enqueueLinks( queue, seen, outbound, budget );
				}

				// Progress, so the report can say what is happening. Every
				// fifth URL rather than every one: a run of two hundred URLs
				// would otherwise spend two hundred writes telling somebody who
				// refreshes every three seconds something they cannot read that
				// fast.
				if ( fetched % 5 == 0 || !arrayLen( queue ) ) {
					repository.touchProgress( arguments.auditId, fetched, arrayLen( queue ) );
				}
			}

			if ( arrayLen( queue ) ) {
				notes.append( "Stopped at the #budget# URL limit; #arrayLen( queue )# more were waiting." );
			}

			// The crawl-wide pass: broken links, duplicate titles, orphans.
			findings.append(
				attributeCrawlFindings(
					crawlChecks.inspect( crawled, { "siteId" : arguments.siteId, "siteName" : arguments.siteName } ),
					pageIndex
				),
				true
			);

			findings.append( unreachableFinding( crawled, arguments.baseUrl ), true );
			findings.append( siteLevelFindings( arguments.siteId ), true );

			repository.addIssues( arguments.auditId, arguments.siteId, findings );

			audit
				.setStatus( "finished" )
				.setUrlCount( fetched )
				.setQueuedCount( arrayLen( queue ) )
				.setErrorCount( countBy( findings, "error" ) )
				.setWarningCount( countBy( findings, "warning" ) )
				.setNoticeCount( countBy( findings, "notice" ) )
				.setNote( notes.toList( " " ) );

			repository.finishAudit( audit );
		} catch ( any e ) {
			// The run is marked failed rather than left looking finished with
			// partial results, which would be read as "the site is fine".
			log.error( "SEO audit for site [#arguments.siteId#] failed: #e.message# #e.detail ?: ''#", e );

			// The detail as well as the message. A note reading "Error
			// Executing Database Query" tells whoever reads the report nothing
			// they can act on.
			audit
				.setStatus( "failed" )
				.setUrlCount( fetched )
				.setQueuedCount( arrayLen( queue ) )
				.setNote( left( trim( "Stopped after an error: " & e.message & " " & ( e.detail ?: "" ) ), 500 ) );

			repository.finishAudit( audit );
		}

		return audit;
	}

	/**
	 * Mark as failed any run that stopped without saying so.
	 *
	 * A thread killed by a restart, a deployment or an out-of-memory cannot
	 * update its own row, so the row stays `running` and the report polls for
	 * ever. A run whose heartbeat is older than the stall window is dead
	 * whatever it says about itself.
	 *
	 * Called when the screen loads and before a new run starts, so a stuck row
	 * never blocks the next audit.
	 */
	numeric function reconcileStalled( required numeric siteId ){
		return repository.failStalledRuns(
			arguments.siteId,
			max( 1, val( settings.stallMinutes ?: 15 ) )
		);
	}

	/* -------------------------------------------------------------- reads */

	function getLatestForSite( required numeric siteId ){
		return repository.findLatestForSite( arguments.siteId );
	}

	function getAudit( required numeric auditId, required numeric siteId ){
		return repository.findAuditById( arguments.auditId, arguments.siteId );
	}

	array function getAuditsForSite( required numeric siteId, numeric limit = 20 ){
		return repository.findAuditsForSite( arguments.siteId, arguments.limit );
	}

	array function getIssues( required numeric auditId, required numeric siteId ){
		return repository.findIssuesForAudit( arguments.auditId, arguments.siteId );
	}

	array function summariseByCheck( required numeric auditId, required numeric siteId ){
		return repository.summariseByCheck( arguments.auditId, arguments.siteId );
	}

	array function summariseByPath( required numeric auditId, required numeric siteId ){
		return repository.summariseByPath( arguments.auditId, arguments.siteId );
	}

	function deleteAudit( required numeric auditId, required numeric siteId ){
		return repository.deleteAudit( arguments.auditId, arguments.siteId );
	}

	/* ---------------------------------------------------------- internals */

	/**
	 * One finding explaining a run where almost nothing answered.
	 *
	 * A site the server cannot fetch produces one identical error per URL — a
	 * report of 173 "this URL answers with an error" tells you the audit is
	 * broken and nothing about the site. This says it once, in front, with the
	 * address that was tried and the status that came back, so the next step is
	 * obvious instead of a guess.
	 *
	 * The threshold is deliberately high. A site where a quarter of the pages
	 * 404 has a real problem worth reporting page by page; a site where nearly
	 * every page fails with the same status has a fetching problem.
	 */
	private array function unreachableFinding( required array crawled, required string baseUrl ){
		if ( arrayLen( arguments.crawled ) < 3 ) {
			return [];
		}

		var failed = arguments.crawled.filter( ( page ) => page.statusCode != 200 );

		if ( arrayLen( failed ) / arrayLen( arguments.crawled ) < 0.9 ) {
			return [];
		}

		var codes = {};

		for ( var page in failed ) {
			codes[ page.statusCode ] = true;
		}

		var shown = structKeyArray( codes ).toList( ", " );

		return [ {
			"path"     : "",
			"checkId"  : "site.unreachable",
			"severity" : "error",
			"message"  : "The audit could not fetch this site: #arrayLen( failed )# of #arrayLen( arguments.crawled )# URLs failed. "
				& "This is almost certainly how the server reaches itself, not a problem with the pages.",
			"detail"   : "Tried #len( arguments.baseUrl ) ? arguments.baseUrl : "a derived address"#"
				& " — HTTP #shown#."
				& " A 400 on every URL usually means plain HTTP was sent to an HTTPS port."
				& " Set the SEO audit's fetchBaseUrl to the address this server can reach itself on."
		} ];
	}

	/**
	 * Findings about the site rather than about a page.
	 *
	 * Reported once. Repeating "this site has no Google tag" on all hundred
	 * pages would be true and useless.
	 */
	private array function siteLevelFindings( required numeric siteId ){
		var found = [];

		if ( isNull( domains.findPrimaryForSite( arguments.siteId ) ) ) {
			found.append( {
				"path"     : "",
				"checkId"  : "site.noPrimaryDomain",
				"severity" : "error",
				"message"  : "This site has no primary domain, so canonical URLs and sitemap entries cannot be built.",
				"detail"   : "Set one under the site's domains."
			} );
		}

		try {
			if ( !len( analytics.analyticsFor( arguments.siteId ).tagId ?: "" ) ) {
				found.append( {
					"path"     : "",
					"checkId"  : "site.noAnalytics",
					"severity" : "notice",
					"message"  : "No Google tag is configured, so nothing is measuring whether any of this works.",
					"detail"   : "Settings → Analytics."
				} );
			}
		} catch ( any e ) {
			log.warn( "SEO audit could not read the analytics setting: #e.message#" );
		}

		return found;
	}

	/**
	 * Only the status check, for a URL that did not render. Asked of the
	 * registry rather than the check directly so a replaced status check is
	 * still the one that answers.
	 */
	private array function statusOnly( required any document, required struct context ){
		try {
			return wirebox.getInstance( "StatusCheck@seoaudit" ).inspect( arguments.document, arguments.context );
		} catch ( any e ) {
			return [ {
				"checkId"  : "status.unreachable",
				"severity" : "error",
				"message"  : "This URL could not be fetched.",
				"detail"   : arguments.context.fetchError ?: ""
			} ];
		}
	}

	/**
	 * The internal, auditable paths this page links to, de-duplicated.
	 *
	 * Extracted once per page and reused for both jobs that need it — adding to
	 * the crawl queue, and letting the broken-link check see what pointed where.
	 * Parsing the links twice would be the same work done twice.
	 */
	private array function internalLinks( required any document, required array hosts ){
		var seen  = {};
		var paths = [];

		for ( var link in arguments.document.links() ) {
			var path = discovery.pathFromLink( link.href, arguments.hosts );

			// Null means "not a link worth auditing". An empty string means
			// the home page, which is.
			if ( isNull( path ) || structKeyExists( seen, path ) ) {
				continue;
			}

			seen[ path ] = true;
			paths.append( path );
		}

		return paths;
	}

	/**
	 * The queue with any newly discovered paths added.
	 *
	 * **Returns the queue rather than mutating the argument.** Arrays are
	 * passed by value in CFML, so a function that appends to `arguments.queue`
	 * appends to a copy and the caller keeps the array it had. That is exactly
	 * what happened here: every discovered link was silently dropped, the crawl
	 * only ever audited what the sitemap already listed, and nothing failed —
	 * because the fixtures were all in the sitemap too.
	 *
	 * Structs *are* by reference, which is why `seen` worked and made the bug
	 * harder to see.
	 *
	 * Queued, not fetched here, so the crawl stays breadth-first and the
	 * sitemap's own URLs are all audited before the budget is spent on
	 * discovered ones.
	 */
	private array function enqueueLinks(
		required array queue,
		required struct seen,
		required array paths,
		required numeric budget
	){
		var pending = arguments.queue;

		for ( var path in arguments.paths ) {
			if ( arrayLen( pending ) + structCount( arguments.seen ) >= arguments.budget * 2 ) {
				// The queue is already longer than the run can use. Growing it
				// further costs memory for URLs that will never be fetched.
				return pending;
			}

			if ( structKeyExists( arguments.seen, path ) || arrayFindNoCase( pending, path ) ) {
				continue;
			}

			pending.append( path );
		}

		return pending;
	}

	/**
	 * Give each crawl-wide finding the page id of the path it was attributed
	 * to, so the report can offer the same "edit this page" link it does for a
	 * per-page finding.
	 */
	private array function attributeCrawlFindings( required array findings, required struct pageIndex ){
		var rows = [];

		for ( var finding in arguments.findings ) {
			var row = {
				"path"     : finding.path,
				"checkId"  : finding.checkId,
				"severity" : finding.severity,
				"message"  : finding.message,
				"detail"   : finding.detail
			};

			var pageId = pageIdFor( arguments.pageIndex, finding.path );

			if ( pageId ) {
				row.pageId = pageId;
			}

			rows.append( row );
		}

		return rows;
	}

	private numeric function pageIdFor( required struct index, required string path ){
		if ( !structKeyExists( arguments.index, arguments.path ) ) {
			return 0;
		}

		var target = arguments.index[ arguments.path ];

		// Only a page id belongs in `page_id`. A blog post's id in that column
		// would read as a page that does not exist.
		return target.type == "pages.page" ? val( target.id ) : 0;
	}

	private numeric function countBy( required array findings, required string severity ){
		var wanted = arguments.severity;

		return arguments.findings.filter( ( finding ) => finding.severity == wanted ).len();
	}

}
