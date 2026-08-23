/**
 * The public front controller.
 *
 * Completes the flow the earlier groups set up:
 *
 *   Request -> domain -> TenantContext -> path -> content resolver -> theme -> HTML
 *
 * TenantInterceptor has already run by the time this executes, so the tenant is
 * either resolved or definitively absent. This handler owns the two decisions
 * Group 1 deliberately postponed: what an unknown domain sees, and what a known
 * domain with an unknown path sees.
 *
 * It knows nothing about pages. Content comes from whichever module claims the
 * path through ContentResolverRegistry.
 */
component extends="coldbox.system.EventHandler" {

	property name="tenantContext" inject="TenantContext@core";
	property name="resolvers"     inject="ContentResolverRegistry@core";
	property name="themeService"  inject="ThemeService@core";
	property name="settings"      inject="coldbox:moduleSettings:core";

	/**
	 * Serve any public URL.
	 */
	function index( event, rc, prc ){
		// No tenant: the host does not match an active domain of an active site.
		// There is no theme to render through, because a theme is a property of
		// a site, so this is Core's own plain response.
		if ( !tenantContext.hasCurrentTenant() ) {
			event.setHTTPHeader( statusCode = 404, statusText = "Not Found" );
			prc.requestedHost = cgi.http_host ?: "";
			// These are complete documents, not fragments: a tenant-less request
			// has no theme, and the application layout is not a site's chrome.
			event.noLayout().setView( view = "frontend/unknownDomain", module = "core" );
			return;
		}

		var site  = tenantContext.getCurrentTenant();
		var path  = requestedPath( event, rc );
		var theme = themeService.getThemeForSite( site.getId() );

		prc.currentSite  = site;
		prc.currentTheme = theme;

		var resolution = resolvers.resolve( site.getId(), path );

		if ( isNull( resolution ) ) {
			return renderNotFound( event, site, theme, path );
		}

		event.setHTTPHeader(
			statusCode = resolution.statusCode,
			statusText = resolution.statusCode == 200 ? "OK" : "Not Found"
		);

		var viewArgs  = resolution.args;
		viewArgs.site = site;

		var body = themeService.renderView( theme, resolution.view, viewArgs );

		return themeService.renderLayout(
			theme = theme,
			body  = body,
			args  = {
				site            : site,
				title           : len( resolution.title ) ? resolution.title : site.getName(),
				metaDescription : resolution.metaDescription,
				navigation      : resolution.navigation,
				path            : path
			}
		);
	}

	/**
	 * A known site, but nothing answers for this path.
	 *
	 * Rendered in the site's own theme, so a client's 404 looks like their site.
	 * If the theme does not supply a 404 view, fall back to Core's plain one
	 * rather than turning a missing page into a server error.
	 */
	private function renderNotFound( event, site, theme, path ){
		event.setHTTPHeader( statusCode = 404, statusText = "Not Found" );

		if ( !theme.hasView( "404" ) ) {
			event.getPrivateCollection().requestedPath = arguments.path;
			event.noLayout().setView( view = "frontend/notFound", module = "core" );
			return;
		}

		var body = themeService.renderView(
			theme = arguments.theme,
			view  = "404",
			args  = { site : arguments.site, path : arguments.path }
		);

		return themeService.renderLayout(
			theme = arguments.theme,
			body  = body,
			args  = {
				site            : arguments.site,
				title           : "Page not found",
				metaDescription : "",
				navigation      : [],
				path            : arguments.path
			}
		);
	}

	/**
	 * The path this request is asking for, without leading or trailing slashes.
	 *
	 * Comes from the catch-all route's `path` parameter; falls back to the CGI
	 * path so the handler still behaves if reached another way.
	 */
	private string function requestedPath( event, rc ){
		var path = rc.path ?: "";

		if ( !len( path ) ) {
			path = event.getCurrentRoutedURL();
		}

		return reReplace( lCase( trim( path ) ), "^/+|/+$", "", "all" );
	}

}
