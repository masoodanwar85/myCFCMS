/**
 * Which theme a site renders through, and the rendering itself.
 *
 * A theme is a directory under `/themes`, not a database row: themes are code
 * and templates, deployed with the application, and a client selects one rather
 * than authoring it. The selection *is* tenant data, so it lives in the site's
 * settings — which also means Core needs no new table for it.
 *
 * Rendering goes through ColdBox's `externalView`, because theme templates sit
 * outside the application's view conventions on purpose: a theme should be
 * droppable into `/themes` without touching the app.
 */
component singleton accessors="true" {

	property name="siteSettingsRepo" inject="SiteSettingsRepository@core";
	property name="settings"         inject="coldbox:moduleSettings:core";
	property name="renderer"         inject="provider:coldbox:renderer";
	property name="wirebox"          inject="wirebox";
	property name="log"              inject="logbox:logger:{this}";

	variables.THEMES_MAPPING = "/themes";

	/**
	 * The theme a site renders through.
	 *
	 * Falls back to the default theme — with a warning — when a site names a
	 * theme that is not installed. A missing theme should not take a client's
	 * whole site offline; it should render plainly and be noisy in the log.
	 */
	core.models.theme.Theme function getThemeForSite( required numeric siteId ){
		var slug = siteSettingsRepo.getValue( arguments.siteId, themeSettingKey(), "" );

		if ( !len( slug ) ) {
			slug = defaultThemeSlug();
		}

		if ( !themeExists( slug ) ) {
			log.warn( "Site [#arguments.siteId#] is set to theme [#slug#], which is not installed. Falling back to [#defaultThemeSlug()#]." );
			slug = defaultThemeSlug();
		}

		return getTheme( slug );
	}

	/**
	 * Record which theme a site should use.
	 *
	 * @throws Theme.NotInstalled when no such theme directory exists.
	 */
	function setThemeForSite( required numeric siteId, required string themeSlug ){
		var slug = normalizeSlug( arguments.themeSlug );

		if ( !themeExists( slug ) ) {
			throw(
				type    = "Theme.NotInstalled",
				message = "There is no theme [#slug#] installed under #variables.THEMES_MAPPING#."
			);
		}

		siteSettingsRepo.put( arguments.siteId, themeSettingKey(), slug );

		return this;
	}

	/**
	 * @throws Theme.NotInstalled
	 */
	core.models.theme.Theme function getTheme( required string themeSlug ){
		var slug = normalizeSlug( arguments.themeSlug );

		if ( !themeExists( slug ) ) {
			throw(
				type    = "Theme.NotInstalled",
				message = "There is no theme [#slug#] installed under #variables.THEMES_MAPPING#."
			);
		}

		var disk     = themeDiskPath( slug );
		var manifest = readManifest( disk );

		return wirebox
			.getInstance( "Theme@core" )
			.setSlug( slug )
			.setTitle( manifest.name ?: slug )
			.setVersion( manifest.version ?: "" )
			.setDescription( manifest.description ?: "" )
			.setMappedPath( variables.THEMES_MAPPING & "/" & slug )
			.setDiskPath( disk );
	}

	boolean function themeExists( required string themeSlug ){
		var slug = normalizeSlug( arguments.themeSlug );

		return len( slug ) && directoryExists( themeDiskPath( slug ) );
	}

	/**
	 * Every installed theme, for a theme picker.
	 */
	array function getInstalledThemes(){
		var root = expandPath( variables.THEMES_MAPPING );

		if ( !directoryExists( root ) ) {
			return [];
		}

		return directoryList( root, false, "name" )
			.filter( ( name ) => directoryExists( root & "/" & name ) )
			.sort( "textnocase" )
			.map( ( name ) => getTheme( name ) );
	}

	/* ---------------------------------------------------------------------
	 * Rendering
	 * ------------------------------------------------------------------ */

	/**
	 * Render one of a theme's views.
	 *
	 * @throws Theme.ViewMissing when the theme does not provide that view.
	 */
	string function renderView(
		required core.models.theme.Theme theme,
		required string view,
		struct args = {}
	){
		if ( !arguments.theme.hasView( arguments.view ) ) {
			throw(
				type    = "Theme.ViewMissing",
				message = "Theme [#arguments.theme.getSlug()#] has no view [#arguments.view#].",
				detail  = "Expected #arguments.theme.getDiskPath()#/views/#arguments.view#.cfm"
			);
		}

		return renderer.externalView( view = arguments.theme.viewPath( arguments.view ), args = arguments.args );
	}

	/**
	 * Render one of a theme's page templates.
	 *
	 * The same mechanism as `renderView`, pointed at `templates/` instead of
	 * `views/`. Kept as its own method rather than a flag on that one because
	 * the two answer to different contracts: Core asks a theme for `page` and
	 * `404` by name and a theme must supply them, while a template is whatever
	 * a theme chooses to offer and a page opts into.
	 *
	 * @throws Theme.TemplateMissing when the theme does not provide it.
	 */
	string function renderTemplate(
		required core.models.theme.Theme theme,
		required string template,
		struct args = {}
	){
		if ( !arguments.theme.hasTemplate( arguments.template ) ) {
			throw(
				type    = "Theme.TemplateMissing",
				message = "Theme [#arguments.theme.getSlug()#] has no template [#arguments.template#].",
				detail  = "Expected #arguments.theme.getDiskPath()#/templates/#arguments.template#.cfm"
			);
		}

		return renderer.externalView(
			view = arguments.theme.templatePath( arguments.template ),
			args = arguments.args
		);
	}

	/**
	 * Wrap already-rendered content in the theme's layout.
	 *
	 * The layout receives the content as `args.body`, rather than the theme
	 * having to know how to fetch it. That keeps a theme a pair of dumb
	 * templates with no knowledge of the request.
	 *
	 * @throws Theme.LayoutMissing
	 */
	string function renderLayout(
		required core.models.theme.Theme theme,
		required string body,
		struct args    = {},
		string layout  = "main"
	){
		if ( !arguments.theme.hasLayout( arguments.layout ) ) {
			throw(
				type    = "Theme.LayoutMissing",
				message = "Theme [#arguments.theme.getSlug()#] has no layout [#arguments.layout#].",
				detail  = "Expected #arguments.theme.getDiskPath()#/layouts/#arguments.layout#.cfm"
			);
		}

		var layoutArgs = duplicate( arguments.args );
		layoutArgs.body  = arguments.body;
		layoutArgs.theme = arguments.theme;

		return renderer.externalView( view = arguments.theme.layoutPath( arguments.layout ), args = layoutArgs );
	}

	/* ---------------------------------------------------------------------
	 * Helpers
	 * ------------------------------------------------------------------ */

	string function themeSettingKey(){
		return settings.themeSettingKey ?: "theme";
	}

	string function defaultThemeSlug(){
		return settings.defaultTheme ?: "default";
	}

	/**
	 * Slugs address a directory, so anything that could climb out of the themes
	 * root is stripped rather than escaped.
	 */
	string function normalizeSlug( required string themeSlug ){
		return reReplace( lCase( trim( arguments.themeSlug ) ), "[^a-z0-9_-]", "", "all" );
	}

	private string function themeDiskPath( required string themeSlug ){
		return expandPath( variables.THEMES_MAPPING & "/" & arguments.themeSlug );
	}

	private struct function readManifest( required string diskPath ){
		var file = arguments.diskPath & "/theme.json";

		if ( !fileExists( file ) ) {
			return {};
		}

		try {
			var parsed = deserializeJSON( fileRead( file ) );
			return isStruct( parsed ) ? parsed : {};
		} catch ( any e ) {
			log.warn( "Theme manifest at [#file#] is not valid JSON: #e.message#" );
			return {};
		}
	}

}
