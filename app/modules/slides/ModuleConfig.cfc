/**
 * Slides — per-site hero banners: a background image, overlay HTML, and a
 * position. No public URL of its own. The home template and `[hero-slider]`
 * both ask the service; Core never learns what a slide is.
 */
component {

	this.title       = "Slides";
	this.author      = "myCFCMS";
	this.description = "Per-site hero slides with overlay HTML, for the home template and a shortcode.";
	this.version     = "1.0.0";

	this.cfmapping      = "slides";
	this.modelNamespace = "slides";
	this.autoMapModels  = true;

	this.entryPoint        = "admin/slides";
	this.inheritEntryPoint = false;

	this.dependencies = [ "core" ];

	function configure(){
		routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];
	}

	function onLoad(){
		var shortcode = wirebox.getInstance( "SlideShortcode@slides" );

		wirebox
			.getInstance( "ShortcodeRegistry@core" )
			.register( tag = shortcode.TAG, id = "SlideShortcode@slides", description = shortcode.DESCRIPTION );

		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.register(
				label      = "Slides",
				href       = "/admin/slides",
				permission = "slides.view",
				order      = 49,
				group      = "Modules"
			);
	}

	function onUnload(){
		wirebox.getInstance( "ShortcodeRegistry@core" ).unregister( "hero-slider" );
		wirebox.getInstance( "AdminNavigationRegistry@core" ).unregister( "/admin/slides" );
	}

}
