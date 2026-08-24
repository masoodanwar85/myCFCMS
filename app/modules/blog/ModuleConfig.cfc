/**
 * Blog — the second feature module.
 *
 * Built to find out whether the seams from Groups 3-5 hold. It adds public
 * URLs, admin screens, navigation and permissions, and Core did not change to
 * accommodate any of it:
 *
 *   - public URLs      -> ContentResolverRegistry  (Group 4)
 *   - admin screens    -> its own entry point + SecuredHandler (Group 5)
 *   - admin navigation -> AdminNavigationRegistry  (Group 5)
 *   - permissions      -> its own migration into Core's catalogue (Group 2)
 *
 * It depends on Core alone, and knows nothing of Pages.
 */
component {

	this.title       = "Blog";
	this.author      = "myCFCMS";
	this.description = "Per-site blog posts and categories.";
	this.version     = "1.0.0";

	this.cfmapping      = "blog";
	this.modelNamespace = "blog";
	this.autoMapModels  = true;

	// As with Pages: no public entry point — the content resolver serves those
	// URLs — but the module owns its own admin area.
	this.entryPoint        = "admin/blog";
	this.inheritEntryPoint = false;

	this.dependencies = [ "core" ];

	function configure(){
		settings = {
			// Public URL prefix for the archive and posts.
			"basePath"     : "blog",
			// Posts shown on an archive page.
			"postsPerPage" : 10,
			// Title used for the archive.
			"archiveTitle" : "Blog"
		};

		routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];
	}

	function onLoad(){
		// Lower number than Pages' 100, so `/blog` reaches the archive even if a
		// page happens to use that slug.
		wirebox
			.getInstance( "ContentResolverRegistry@core" )
			.register( "BlogContentResolver@blog", 50 );

		// A single "Blog" entry in the public menu, so the archive is findable.
		wirebox
			.getInstance( "SiteNavigationRegistry@core" )
			.register( "BlogNavigationProvider@blog", 50 );

		wirebox
			.getInstance( "SitemapRegistry@core" )
			.register( "BlogSitemapProvider@blog", 50 );

		// And what a menu item may point at, so an editor can link to this
		// module's content without Core knowing the content exists.
		wirebox
			.getInstance( "LinkTargetRegistry@core" )
			.register( "BlogLinkTargetProvider@blog", 50 );

		// `[recent-posts count="3"]`. The shortcode that proves the seam: a
		// page can list posts without knowing the Blog module exists, and
		// removing the module removes the capability with it.
		var shortcode = wirebox.getInstance( "BlogShortcode@blog" );

		wirebox
			.getInstance( "ShortcodeRegistry@core" )
			.register( tag = shortcode.TAG, id = "BlogShortcode@blog", description = shortcode.DESCRIPTION );

		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.register(
				label      = "Blog",
				href       = "/admin/blog",
				permission = "blog.view",
				order      = 40,
				group      = "Modules"
			);
	}

	function onUnload(){
		wirebox
			.getInstance( "ContentResolverRegistry@core" )
			.unregister( "BlogContentResolver@blog" );

		wirebox
			.getInstance( "SiteNavigationRegistry@core" )
			.unregister( "BlogNavigationProvider@blog" );

		wirebox
			.getInstance( "SitemapRegistry@core" )
			.unregister( "BlogSitemapProvider@blog" );

		wirebox
			.getInstance( "LinkTargetRegistry@core" )
			.unregister( "BlogLinkTargetProvider@blog" );

		wirebox.getInstance( "ShortcodeRegistry@core" ).unregister( "recent-posts" );

		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.unregister( "/admin/blog" );
	}

}
