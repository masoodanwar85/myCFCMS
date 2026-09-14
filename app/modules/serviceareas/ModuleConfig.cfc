/**
 * Service Areas — services, towns, and which towns a service covers.
 *
 * Public Legal Services navigation is untouched. This module has no content
 * resolver and no public menu entry. The Service Locations page template
 * reads from it; editors manage rows under /admin/serviceareas.
 */
component {

	this.title       = "Service Areas";
	this.author      = "myCFCMS";
	this.description = "Per-site services and locations for the Service Locations page.";
	this.version     = "1.0.0";

	this.cfmapping      = "serviceareas";
	this.modelNamespace = "serviceareas";
	this.autoMapModels  = true;

	this.entryPoint        = "admin/serviceareas";
	this.inheritEntryPoint = false;

	this.dependencies = [ "core" ];

	function configure(){
		routes = [ { pattern : "/:action?/:id?", handler : "Admin" } ];
	}

	function onLoad(){
		wirebox
			.getInstance( "AdminNavigationRegistry@core" )
			.register(
				label      = "Service areas",
				href       = "/admin/serviceareas",
				permission = "serviceareas.view",
				order      = 46,
				group      = "Modules"
			);
	}

	function onUnload(){
		wirebox.getInstance( "AdminNavigationRegistry@core" ).unregister( "/admin/serviceareas" );
	}

}
