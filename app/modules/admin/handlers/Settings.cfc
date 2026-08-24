/**
 * Site configuration: the tenant's own record, its theme, and its domains.
 *
 * Three different permissions guard three different kinds of change, because
 * they carry very different risk. Editing a site's name is routine; removing
 * its last active domain takes the whole site offline.
 */
component extends="core.models.security.SecuredHandler" {

	property name="siteService"      inject="SiteService@core";
	property name="themeService"     inject="ThemeService@core";
	property name="siteSettingsRepo" inject="SiteSettingsRepository@core";
	property name="seoService"       inject="SeoService@core";

	variables.permissions = {
		"index"         : "site.view",
		"update"        : "site.update",
		"theme"         : "site.settings.manage",
		"addDomain"     : "site.domains.manage",
		"removeDomain"  : "site.domains.manage",
		"primaryDomain" : "site.domains.manage",
		"toggleDomain"  : "site.domains.manage",
		"seo"           : "seo.manage",
		"$every"        : "site.view"
	};

	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		prc.pageTitle = "Settings";
		prc.domains   = siteService.getDomains( siteId );
		prc.themes    = themeService.getInstalledThemes();
		prc.theme     = themeService.getThemeForSite( siteId );
		prc.settings  = siteSettingsRepo.getAllForSite( siteId );

		prc.canUpdate  = authorization.can( prc.currentUser, "site.update" );
		prc.canDomains = authorization.can( prc.currentUser, "site.domains.manage" );
		prc.canTheme   = authorization.can( prc.currentUser, "site.settings.manage" );
		prc.canSeo     = authorization.can( prc.currentUser, "seo.manage" );

		// Shown rather than merely stored, so an editor can see the address the
		// canonical tags and the sitemap will actually use — which is the
		// site's primary domain, not whichever one they happen to be on.
		prc.seoBaseUrl   = seoService.baseUrl( siteId );
		prc.seoIndexable = seoService.isIndexable( siteId );

		event.setView( view = "settings/index", module = "admin" );
	}

	function update( event, rc, prc ){
		var site = prc.currentSite;

		try {
			if ( !siteService.isValidStatus( rc.status ?: site.getStatus() ) ) {
				throw( type = "Admin.InvalidInput", message = "Unknown site status." );
			}

			// Taking the site you are administering offline is a real choice,
			// but doing it by accident from a settings form is not.
			if ( ( rc.status ?: "" ) == "inactive" && ( rc.confirmOffline ?: "" ) != "yes" ) {
				return done( "/admin/settings", "Tick the confirmation to take this site offline.", "error" );
			}

			site.setName( trim( rc.name ?: site.getName() ) );
			site.setStatus( rc.status ?: site.getStatus() );
			site.setTimezone( trim( rc.timezone ?: site.getTimezone() ) );
			site.setLocale( trim( rc.locale ?: site.getLocale() ) );

			if ( !len( site.getName() ) ) {
				throw( type = "Admin.InvalidInput", message = "A site requires a name." );
			}

			getInstance( "SiteRepository@core" ).update( site );
		} catch ( any e ) {
			return done( "/admin/settings", e.message, "error" );
		}

		return done( "/admin/settings", "Site settings saved." );
	}

	function theme( event, rc, prc ){
		try {
			themeService.setThemeForSite( prc.currentSite.getId(), rc.theme ?: "" );
		} catch ( any e ) {
			return done( "/admin/settings", e.message, "error" );
		}

		return done( "/admin/settings", "Theme changed." );
	}

	/**
	 * Search-engine settings.
	 *
	 * All four are stored as ordinary site settings rather than columns on
	 * `sites`: they are a handful of optional strings, and adding a migration
	 * for each would be a table change every time somebody wants another
	 * social-preview field.
	 */
	function seo( event, rc, prc ){
		var siteId = prc.currentSite.getId();

		try {
			// A checkbox that is off posts nothing at all, so absence is a
			// deliberate `false` here rather than "leave it alone".
			siteSettingsRepo.put( siteId, seoService.KEY_INDEXABLE, ( rc.indexable ?: "" ) == "on" ? "true" : "false" );
			siteSettingsRepo.put( siteId, seoService.KEY_BASE_URL, trim( rc.baseUrl ?: "" ) );
			siteSettingsRepo.put( siteId, seoService.KEY_DESCRIPTION, trim( rc.defaultDescription ?: "" ) );
			siteSettingsRepo.put( siteId, seoService.KEY_IMAGE, trim( rc.defaultImage ?: "" ) );
		} catch ( any e ) {
			return done( "/admin/settings", e.message, "error" );
		}

		return done( "/admin/settings", "Search engine settings saved." );
	}

	function addDomain( event, rc, prc ){
		try {
			siteService.addDomain(
				siteId    = prc.currentSite.getId(),
				domain    = rc.domain ?: "",
				isPrimary = ( rc.isPrimary ?: "" ) == "yes"
			);
		} catch ( any e ) {
			return done( "/admin/settings", e.message, "error" );
		}

		return done( "/admin/settings", "Domain added." );
	}

	function primaryDomain( event, rc, prc ){
		try {
			siteService.makeDomainPrimary( prc.currentSite.getId(), rc.domain ?: "" );
		} catch ( any e ) {
			return done( "/admin/settings", e.message, "error" );
		}

		return done( "/admin/settings", "Primary domain changed." );
	}

	function toggleDomain( event, rc, prc ){
		var target = requireSiteDomain( rc.id ?: 0, prc );

		// Deactivating the only way in would make the site unreachable, admin
		// included, with no way to undo it through the admin.
		if ( target.getIsActive() && activeDomainCount( prc ) <= 1 ) {
			return done( "/admin/settings", "A site needs at least one active domain.", "error" );
		}

		getInstance( "SiteDomainRepository@core" ).setActive( target.getId(), !target.getIsActive() );

		return done( "/admin/settings", "Domain updated." );
	}

	function removeDomain( event, rc, prc ){
		var target = requireSiteDomain( rc.id ?: 0, prc );

		if ( siteService.getDomains( prc.currentSite.getId() ).len() <= 1 ) {
			return done( "/admin/settings", "A site needs at least one domain.", "error" );
		}

		getInstance( "SiteDomainRepository@core" ).delete( target.getId() );

		return done( "/admin/settings", "Domain removed." );
	}

	private numeric function activeDomainCount( required struct prc ){
		return siteService
			.getDomains( arguments.prc.currentSite.getId() )
			.filter( ( d ) => d.getIsActive() )
			.len();
	}

	private function requireSiteDomain( required numeric domainId, required struct prc ){
		var matches = siteService
			.getDomains( arguments.prc.currentSite.getId() )
			.filter( ( d ) => d.getId() == domainId );

		if ( !matches.len() ) {
			throw( type = "Admin.NotFoundHere", message = "No domain [#arguments.domainId#] on this site." );
		}

		return matches[ 1 ];
	}

}
