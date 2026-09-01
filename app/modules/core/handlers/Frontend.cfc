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
	property name="navigation"    inject="NavigationService@core";
	property name="redirects"     inject="RedirectService@core";
	property name="seo"           inject="SeoService@core";
	property name="branding"      inject="SiteBrandingService@core";
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

		var resolution = javacast( "null", "" );

		// A public form posting back to its own URL. Handled before the GET
		// lookup, so a module can answer with a result page or the form again
		// carrying errors.
		if ( event.getHTTPMethod() == "POST" ) {
			resolution = resolvers.resolveSubmission( site.getId(), path, arguments.rc );

			if ( !isNull( resolution ) && len( resolution.redirectTo ) ) {
				// Redirect after post, so a refresh does not send it twice.
				relocate( uri = resolution.redirectTo );
				return;
			}
		}

		if ( isNull( resolution ) ) {
			resolution = resolvers.resolve( site.getId(), path );
		}

		if ( isNull( resolution ) ) {
			// Nothing serves this path now — but something may have, before an
			// editor renamed it. A link someone already published should keep
			// working rather than becoming a 404.
			var moved = redirects.find( site.getId(), path );

			if ( !isNull( moved ) ) {
				relocate( uri = "/" & moved.toPath, statusCode = moved.statusCode );
				return;
			}

			return renderNotFound( event, site, theme, path );
		}

		event.setHTTPHeader(
			statusCode = resolution.statusCode,
			statusText = resolution.statusCode == 200 ? "OK" : "Not Found"
		);

		var viewArgs   = resolution.args;
		viewArgs.site  = site;
		// Views get the theme too, not just layouts: a view that needs an icon
		// or a background image should build its URL the same way a layout does.
		viewArgs.theme = theme;

		var body = themeService.renderView( theme, resolution.view, viewArgs );

		return themeService.renderLayout(
			theme = theme,
			body  = body,
			args  = {
				site            : site,
				title           : len( resolution.title ) ? resolution.title : site.getName(),
				metaDescription : resolution.metaDescription,
				// Asked of the registry, not taken from the resolution: the menu
				// is the site's, not the property of whichever module answered
				// this URL.
				navigation      : navigation.getNavigationFor( site.getId() ),
				path            : path,
				// Canonical, robots and the social tags, with whatever the
				// resolver left out filled in from the site's own defaults. A
				// theme emits these; it does not work them out.
				seo             : seo.metadataFor( site, path, resolution ),
				// Logo and brand tokens. Passed to every layout render so a
				// theme can rely on `args.branding` existing rather than
				// testing for it, and so two sites can share one theme and
				// still not look identical.
				branding        : branding.brandingFor( site.getId() )
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
				// A 404 keeps the site's menu, so a reader can get somewhere.
				navigation      : navigation.getNavigationFor( arguments.site.getId() ),
				path            : arguments.path,
				// `statusCode` is what makes SeoService mark this `noindex`: a
				// 404 rendered in the site's theme still looks like a page, and
				// without this a crawler would happily index it as one.
				seo             : seo.metadataFor(
					site       = arguments.site,
					path       = arguments.path,
					resolution = { "statusCode" : 404 }
				),
				// A 404 is still this client's site, so it keeps their logo.
				branding        : branding.brandingFor( arguments.site.getId() )
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
