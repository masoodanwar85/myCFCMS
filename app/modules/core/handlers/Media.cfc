/**
 * Serves uploaded files.
 *
 * Files live outside the webroot, so something has to hand them out. Doing it
 * here rather than dropping them under `public/` buys two things: a file is
 * only reachable from the domain of the site that owns it, and an upload that
 * somehow got past validation sits somewhere the web server will not execute.
 *
 * The cost is a ColdFusion request per file. Filenames carry a random suffix
 * and never change, so the response is marked immutable and a browser asks once
 * — but a busy public site should still put a reverse proxy or CDN in front of
 * this path. See the note in the docs.
 *
 * Lives in Core rather than the Media module because the URL is `/media/...`,
 * not `/admin/media/...`, and Core's router owns the public URL space.
 */
component extends="coldbox.system.EventHandler" {

	property name="mediaService"  inject="MediaService@media";
	property name="tenantContext" inject="TenantContext@core";

	function serve( event, rc, prc ){
		if ( !tenantContext.hasCurrentTenant() ) {
			return missing( event );
		}

		var site = tenantContext.getCurrentTenant();
		var item = mediaService.getByPath( site.getId(), requestedPath( event, rc ) );

		// Unknown, or belonging to another site: the same answer either way, so
		// a 404 never confirms that a file exists somewhere else.
		if ( isNull( item ) ) {
			return missing( event );
		}

		var path = mediaService.absolutePath( site.getId(), item.getStoredPath() );

		if ( !fileExists( path ) ) {
			log.warn( "Media #item.getId()# is recorded but its file is missing: #path#" );
			return missing( event );
		}

		// Content-Type and Content-Length are left to `content file=` below.
		// Setting them here as well produced a charset-appended type and a
		// duplicated length, and the response failed.
		event.setHTTPHeader( name = "Cache-Control", value = "public, max-age=31536000, immutable" );

		// Stops a browser second-guessing the type and running something as
		// script because it looked like script.
		event.setHTTPHeader( name = "X-Content-Type-Options", value = "nosniff" );

		// A PDF opened inline can host script in some readers; images are safe
		// inline and are what most of this serves.
		if ( !item.isImage() ) {
			event.setHTTPHeader(
				name  = "Content-Disposition",
				value = 'attachment; filename="' & item.getOriginalFilename() & '"'
			);
		}

		event.noLayout().noRender();

		// `cfcontent(...)`, not the tag-in-script form: `content file=...`
		// parses as a reference to an undefined variable named `content`.
		cfcontent( file = path, type = item.getMimeType() );
	}

	/**
	 * The file path being asked for.
	 *
	 * Taken from the routed URL rather than a route parameter: a trailing
	 * wildcard placed *after* a literal segment — `/media/:path*` — arrives as
	 * an rc key literally named `path*`, alongside a mangled one per extra
	 * segment. Only an unprefixed `/:path*` populates `rc.path` cleanly, so
	 * this reads the URL and strips the prefix itself.
	 */
	private string function requestedPath( event, rc ){
		if ( len( arguments.rc.path ?: "" ) ) {
			return arguments.rc.path;
		}

		var routed = reReplace( arguments.event.getCurrentRoutedURL(), "^/+", "", "one" );

		return reReplace( reReplaceNoCase( routed, "^media/", "", "one" ), "/+$", "", "all" );
	}

	private function missing( event ){
		event.setHTTPHeader( statusCode = 404, statusText = "Not Found" );
		event.noLayout().noRender();

		return;
	}

}
