/**
 * `GET /api/v1/themes` — what this site can be made to look like.
 *
 * Read-only, and it will stay that way. A theme is a directory of `.cfm`
 * templates deployed with the application, so "create a theme" is a deploy and
 * not an API call; the one thing that *is* tenant data — which theme a site
 * renders through — is a site setting, and changing it belongs with the rest of
 * the site's configuration rather than here.
 *
 * Lives in Core because themes do: `ThemeService` is Core's, and a theme is
 * what Core renders a module's content *into*.
 *
 * ## What a client is actually looking for
 *
 * The layout choice a page can make is its **template** — `page.template`,
 * which names a file under the theme's `templates/` directory and is what
 * `PATCH /api/v1/pages/:id { "template" : "..." }` sets. So each theme here
 * carries its `templates` array, and that array is the list of layouts a page
 * may be given. The theme's `views/` are not offered: Core asks a theme for
 * `page` and `404` by name and a page cannot opt into one.
 */
component extends="core.models.api.ApiHandler" {

	property name="themeService" inject="ThemeService@core";

	// Reading the theme list tells a client nothing about the site's content,
	// only about what is installed — the same thing the theme picker on the
	// settings screen shows, and the same permission it needs.
	variables.permissions = {
		"index"  : "site.view",
		"show"   : "site.view",
		"$every" : "site.view"
	};

	/**
	 * `GET /api/v1/themes`
	 *
	 * Every installed theme, with its templates, and `active` marking the one
	 * this site renders through. Not paged: an installation has a handful of
	 * themes, and they arrive by deploy rather than by growth.
	 */
	function index( event, rc, prc ){
		var activeSlug = activeSlugFor( prc );
		var themes     = themeService.getInstalledThemes();

		return respond(
			event = event,
			data  = themes.map( ( theme ) => toStruct( theme, theme.getSlug() == activeSlug ) ),
			meta  = { "total" : themes.len(), "active" : activeSlug }
		);
	}

	/**
	 * `GET /api/v1/themes/:slug`
	 *
	 * The id in the URL is the slug. A theme has no numeric key — it is a
	 * directory — and inventing one would be a surrogate nobody could guess
	 * from a deploy.
	 */
	function show( event, rc, prc ){
		// Normalised before the existence check, so a slug that tries to climb
		// out of the themes root is stripped rather than looked up.
		var slug = themeService.normalizeSlug( rc.id ?: "" );

		if ( !themeService.themeExists( slug ) ) {
			return fail( event, 404, "not_found", "No theme [#slug#] is installed." );
		}

		return respond(
			event = event,
			data  = toStruct( themeService.getTheme( slug ), slug == activeSlugFor( prc ) )
		);
	}

	/* --------------------------------------------------------------------- */

	/**
	 * The slug of the theme this site renders through.
	 *
	 * Asked of the service rather than read from the setting, so a site pointed
	 * at a theme that is no longer deployed reports the fallback it will
	 * actually render with — the same answer the front controller gets.
	 */
	private string function activeSlugFor( required struct prc ){
		return themeService.getThemeForSite( arguments.prc.currentSite.getId() ).getSlug();
	}

	private struct function toStruct( required any theme, required boolean isActive ){
		var out = arguments.theme.getMemento();

		out[ "active" ]    = arguments.isActive;
		out[ "templates" ] = arguments.theme.templates();

		return out;
	}

}
