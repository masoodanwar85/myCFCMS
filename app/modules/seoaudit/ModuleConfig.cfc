/**
 * On-page SEO audits — what a crawler would find wrong with this site.
 *
 * The module fetches every public URL of a site over loopback HTTP, parses the
 * response, and records what each registered check finds. Reading the *rendered*
 * page rather than the database is the whole design: the faults that matter
 * most do not exist until the page is rendered.
 *
 * Two `<h1>` is the clearest example. The theme emits one when a page's
 * `showHeading` is on, and an author may write another in the content — a
 * combination this CMS deliberately allows. Neither row in `pages` is wrong on
 * its own, and nothing in the database says the page has two headings. The HTML
 * says it plainly.
 *
 * The same goes for shortcodes (`[image]` and `[file]` become `<img>` and `<a>`
 * at render time), inherited featured images, and the module landing pages —
 * `/faq`, `/contact` and the rest are served by content resolvers and have no
 * row in `pages` at all, so a database audit would never look at them while
 * reporting a confident page count.
 */
component {

	this.title       = "SEO Audit";
	this.author      = "myCFCMS";
	this.description = "Finds on-page SEO problems across every public URL of a site.";
	this.version     = "1.0.0";

	this.cfmapping      = "seoaudit";
	this.modelNamespace = "seoaudit";
	this.autoMapModels  = true;

	this.entryPoint        = "admin/seo";
	this.inheritEntryPoint = false;

	this.dependencies = [ "core" ];

	function configure(){
		settings = {
			// How many URLs one run will fetch. A run is one HTTP request per
			// URL, so this is the ceiling on how long it can take and how much
			// work it can make for the server.
			"maxUrls" : 250,

			// Seconds to wait for any one page. A slow page is a finding in its
			// own right, but a hung one must not hold the run open.
			"timeout" : 15,

			// Where to fetch from. Empty means "derive it", which resolves to
			// loopback on the port serving the current request — see
			// `PageFetcher`. Set it when the server cannot reach itself that
			// way, e.g. behind a proxy that terminates TLS elsewhere.
			"fetchBaseUrl" : "",

			// Thresholds. Here rather than in the checks so a site with house
			// rules can move them without editing code.
			"titleMin"        : 30,
			"titleMax"        : 60,
			"descriptionMin"  : 70,
			"descriptionMax"  : 160,
			"thinContent"     : 300,

			// How many of one page's own links a single-page audit will probe
			// for breakage. Much smaller than `maxUrls` because this one runs
			// *in the request*: the caller is waiting, and a page with a large
			// navigation would otherwise turn one audit into fifty sequential
			// fetches. Links beyond the budget are left unjudged rather than
			// reported as unknown.
			"pageLinkBudget" : 25,

			// A run whose heartbeat is older than this is treated as dead. A
			// thread killed by a restart cannot mark its own row failed, and
			// without a window like this the row stays "running" for ever and
			// blocks every later audit of the site.
			"stallMinutes"    : 15
		};

		routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];
	}

	function onLoad(){
		// Reads and starts; no delete, because nothing asks to remove a run
		// over the API and a report is the record of what was true. `page` is a
		// collection action rather than a member one: it audits a URL, not an
		// existing run.
		wirebox
			.getInstance( "ApiRouteRegistry@core" )
			.resource(
				name              = "seo-audits",
				module            = "seoaudit",
				handler           = "Api",
				only              = "index,show,create",
				collectionActions = "page"
			);

		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.register(
				label      = "SEO",
				href       = "/admin/seo",
				permission = "seo.view",
				order      = 70,
				group      = "Modules"
			);

		// Checks are registered rather than hard-coded so another module can
		// contribute one about its own content without this module learning
		// that the module exists — the same seam as every other registry here.
		var registry = wirebox.getInstance( "SeoCheckRegistry@seoaudit" );

		for ( var check in [
			"StatusCheck",
			"TitleCheck",
			"DescriptionCheck",
			"HeadingCheck",
			"ImageAltCheck",
			"CanonicalCheck",
			"RobotsCheck",
			"OpenGraphCheck",
			"StructuredDataCheck",
			"ContentLengthCheck",
			"UrlShapeCheck"
		] ) {
			registry.register( "#check#@seoaudit" );
		}

		// Checks that need the whole crawl rather than one page. A separate
		// registry because the contract is different: these are handed every
		// page the run collected, and answer about the set.
		var crawlRegistry = wirebox.getInstance( "SeoCrawlCheckRegistry@seoaudit" );

		for ( var crawlCheck in [
			"BrokenLinkCheck",
			"DuplicateContentCheck",
			"SitemapReconciliationCheck"
		] ) {
			crawlRegistry.register( "#crawlCheck#@seoaudit" );
		}
	}

	function onUnload(){
		wirebox.getInstance( "ApiRouteRegistry@core" ).unregister( "seo-audits" );
		wirebox.getInstance( "AdminNavigationRegistry@core" ).unregister( "/admin/seo" );
	}

}
