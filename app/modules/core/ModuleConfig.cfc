/**
 * CMS Core Module
 *
 * Holds the infrastructure every tenant site and every feature module depends on.
 * Core must never depend on a feature module (Pages, Blog, News, Contact, ...);
 * the dependency arrow always points inwards, towards Core.
 *
 * Implemented so far (Group 1): multi-tenancy — sites, domains, settings,
 * domain resolution and the request-scoped TenantContext.
 */
component {

	this.title       = "CMS Core";
	this.author      = "myCFCMS";
	this.description = "Core CMS infrastructure. Group 1 delivers the multi-tenancy foundation.";
	this.version     = "1.0.0";

	// Gives us the `core.` mapping and `@core` WireBox namespace.
	this.cfmapping      = "core";
	this.modelNamespace = "core";
	this.autoMapModels  = true;

	// Core is infrastructure, not a routable area. It exposes no entry point.
	this.entryPoint        = "";
	this.inheritEntryPoint = false;

	this.dependencies = [ "qb", "BCrypt" ];

	function configure(){
		settings = {
			// Domains that should never be treated as a tenant hostname.
			// Requests on these hosts simply resolve to no tenant.
			"ignoredDomains" : [],

			// BCrypt cost for new password hashes. Higher is slower to hash and
			// slower to attack; raise it as hardware improves.
			"passwordWorkFactor" : 12,

			// Theme used when a site names none, or names one that is not
			// installed. Must exist under /themes.
			"defaultTheme" : "default",

			// Site setting key holding a site's chosen theme.
			"themeSettingKey" : "theme"
		};

		/**
		 * Feature modules and application code can listen to these instead of
		 * re-resolving the tenant themselves.
		 */
		interceptorSettings = {
			customInterceptionPoints : [ "onTenantResolved", "onTenantNotResolved" ]
		};

		interceptors = [
			{
				class : "#moduleMapping#.interceptors.TenantInterceptor",
				name  : "TenantInterceptor"
			}
		];
	}

}
