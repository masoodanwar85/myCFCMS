/**
 * A theme: a directory of layouts and views a site renders through.
 *
 * State only. It knows where its templates live and which ones exist; it does
 * not render anything itself.
 */
component accessors="true" {

	property name="slug"        type="string";
	property name="title"       type="string";
	property name="version"     type="string";
	property name="description" type="string";

	// Mapped path, e.g. "/themes/default". Not a filesystem path, because
	// ColdBox renders templates through mappings.
	property name="mappedPath"  type="string";

	// Absolute filesystem path, used only for existence checks.
	property name="diskPath"    type="string";

	/**
	 * The mapped path of one of this theme's views, for the renderer.
	 */
	string function viewPath( required string view ){
		return variables.mappedPath & "/views/" & arguments.view;
	}

	string function layoutPath( required string layout = "main" ){
		return variables.mappedPath & "/layouts/" & arguments.layout;
	}

	/**
	 * The public URL of one of this theme's static files.
	 *
	 * Static assets do NOT live beside the templates. `/themes` is outside the
	 * webroot on purpose — a layout is a `.cfm`, and a themes directory exposed
	 * to the web server would make `layouts/main.cfm` directly requestable and,
	 * behind mod_jk, executable. So the templates stay out and the CSS, JS and
	 * fonts go in, under `/assets/themes/<slug>/`, where the web server hands
	 * them out itself with no ColdFusion request at all.
	 *
	 *     <link rel="stylesheet" href="#args.theme.assetUrl( 'css/theme.css' )#">
	 *
	 * The path is cleaned rather than escaped: this builds a URL from a value a
	 * theme author wrote, and `..` in it should never have been there.
	 */
	string function assetUrl( required string path ){
		var clean = reReplace( trim( arguments.path ), "^/+", "" );

		// No climbing out of the theme's own asset directory.
		clean = replace( clean, "..", "", "all" );
		clean = reReplace( clean, "/{2,}", "/", "all" );

		return "/assets/themes/" & variables.slug & "/" & clean;
	}

	/**
	 * Whether that file is actually deployed, for a theme that wants to degrade
	 * rather than emit a link to a 404.
	 */
	boolean function hasAsset( required string path ){
		return fileExists( assetDiskPath( arguments.path ) );
	}

	boolean function hasView( required string view ){
		return fileExists( variables.diskPath & "/views/" & arguments.view & ".cfm" );
	}

	boolean function hasLayout( required string layout = "main" ){
		return fileExists( variables.diskPath & "/layouts/" & arguments.layout & ".cfm" );
	}

	/**
	 * Where an asset sits on disk.
	 *
	 * Derived from the webroot rather than from `diskPath`, because assets live
	 * under `public/` and templates do not.
	 */
	string function assetDiskPath( required string path ){
		var clean = reReplace( trim( arguments.path ), "^/+", "" );
		clean = replace( clean, "..", "", "all" );

		return expandPath( "/public/assets/themes/" & variables.slug & "/" & clean );
	}

	struct function getMemento(){
		return {
			"slug"        : variables.slug,
			"title"       : variables.title,
			"version"     : variables.version ?: "",
			"description" : variables.description ?: ""
		};
	}

}
