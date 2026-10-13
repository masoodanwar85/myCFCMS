/**
 * The SEO audit screens, at /admin/seo.
 *
 * Extends Core's SecuredHandler, so it depends on Core alone.
 *
 * `view` and `run` are separate permissions because they cost different
 * things: reading last night's report is free, and starting a run fetches every
 * public URL of the site.
 */
component extends="core.models.security.SecuredHandler" {

	property name="auditService" inject="SeoAuditService@seoaudit";
	property name="settings"     inject="coldbox:moduleSettings:seoaudit";

	variables.permissions = {
		"index"  : "seo.view",
		"show"   : "seo.view",
		"run"    : "seo.run",
		"remove" : "seo.run",
		"$every" : "seo.view"
	};

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		// A run killed by a restart cannot mark its own row failed, so a stuck
		// row is cleared here rather than being left to poll for ever.
		auditService.reconcileStalled( siteId );

		prc.pageTitle = "SEO";
		prc.audits    = auditService.getAuditsForSite( siteId );
		prc.audit     = auditService.getLatestForSite( siteId );
		prc.canRun    = authorization.can( prc.currentUser, "seo.run" );
		prc.maxUrls   = val( settings.maxUrls ?: 250 );

		loadReport( prc, siteId );

		event.setView( view = "admin/index", module = "seoaudit" );
	}

	/**
	 * An earlier run, so two reports can be compared by opening both.
	 */
	function show( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		auditService.reconcileStalled( siteId );

		var audit = auditService.getAudit( val( rc.id ?: 0 ), siteId );

		if ( isNull( audit ) ) {
			return done( "/admin/seo", "That audit does not exist on this site.", "error" );
		}

		prc.pageTitle = "SEO audit";
		prc.audits    = auditService.getAuditsForSite( siteId );
		prc.audit     = audit;
		prc.canRun    = authorization.can( prc.currentUser, "seo.run" );
		prc.maxUrls   = val( settings.maxUrls ?: 250 );

		loadReport( prc, siteId );

		event.setView( view = "admin/index", module = "seoaudit" );
	}

	/**
	 * Start a run and redirect straight to its report, which then follows along
	 * as it progresses. The run itself happens on a background thread.
	 */
	function run( event, rc, prc ){
		var audit = "";

		try {
			audit = auditService.start(
				siteId   = prc.currentSite.getId(),
				siteName = prc.currentSite.getName(),
				runBy    = prc.currentUser.getId()
			);
		} catch ( SeoAudit.AlreadyRunning e ) {
			return done( "/admin/seo", e.message, "error" );
		} catch ( any e ) {
			return done( "/admin/seo", e.message, "error" );
		}

		return done( "/admin/seo/show/" & audit.getId(), "Audit started." );
	}

	function remove( event, rc, prc ){
		auditService.deleteAudit( val( rc.id ?: 0 ), prc.currentSite.getId() );

		return done( "/admin/seo", "Audit deleted." );
	}

	/**
	 * The two ways of reading one report: grouped by problem, and grouped by
	 * page. Both are wanted and for different jobs — "what is wrong with this
	 * site" is answered by the first, "what do I fix on this page" by the
	 * second.
	 */
	private function loadReport( required struct prc, required numeric siteId ){
		if ( isNull( arguments.prc.audit ) || !isObject( arguments.prc.audit ) ) {
			arguments.prc.issues    = [];
			arguments.prc.byCheck   = [];
			arguments.prc.byPath    = [];
			return this;
		}

		var auditId = arguments.prc.audit.getId();

		arguments.prc.issues  = auditService.getIssues( auditId, arguments.siteId );
		arguments.prc.byCheck = auditService.summariseByCheck( auditId, arguments.siteId );
		arguments.prc.byPath  = auditService.summariseByPath( auditId, arguments.siteId );

		return this;
	}

}
