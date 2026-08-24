/**
 * Media — per-site uploaded files.
 *
 * Owns the library and its admin screens. The public `/media/...` URL is served
 * by Core, because Core's router owns the public URL space and a module should
 * not have to reach into it.
 *
 * Depends on Core alone, like every other feature module.
 */
component {

	this.title       = "Media";
	this.author      = "myCFCMS";
	this.description = "Per-site media library.";
	this.version     = "1.0.0";

	this.cfmapping      = "media";
	this.modelNamespace = "media";
	this.autoMapModels  = true;

	this.entryPoint        = "admin/media";
	this.inheritEntryPoint = false;

	this.dependencies = [ "core" ];

	function configure(){
		settings = {
			// Outside the webroot on purpose. Point this at a mounted volume in
			// production; nothing else needs to change.
			"mediaRoot"      : "/storage/media",
			// 10MB. Large enough for a photograph, small enough that a careless
			// upload cannot fill a disk.
			"maxUploadBytes" : 10485760
		};

		routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];
	}

	function onLoad(){
		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.register(
				label      = "Media",
				href       = "/admin/media",
				permission = "media.view",
				order      = 26,
				group      = "CMS"
			);

		// `[image id="12"]`, so an author can place a library image where the
		// editor cannot reach — and so the alt text is read from the library at
		// render time rather than copied into the content.
		var shortcode = wirebox.getInstance( "MediaShortcode@media" );

		wirebox
			.getInstance( "ShortcodeRegistry@core" )
			.register( tag = shortcode.TAG, id = "MediaShortcode@media", description = shortcode.DESCRIPTION );
	}

	function onUnload(){
		wirebox.getInstance( "AdminNavigationRegistry@core" ).unregister( "/admin/media" );
		wirebox.getInstance( "ShortcodeRegistry@core" ).unregister( "image" );
	}

}
