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
			"themeSettingKey" : "theme",

			// AntiSamy policy used to sanitise author content. ColdFusion's
			// bundled policy strips headings and tables, so the CMS ships its own.
			"sanitizerPolicy" : "/resources/security/antisamy-cms.xml",

			// Mail delivery: `off` records only, `log` also writes the body to
			// the log, `send` actually delivers. Defaults to `off` because no
			// SMTP is configured — turning it on before that would fail every
			// send rather than recording it for later.
			"mailMode" : "off",
			"mailFrom" : "no-reply@localhost"
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
			},
			{
				class : "#moduleMapping#.interceptors.ModuleRouteOrderInterceptor",
				name  : "ModuleRouteOrderInterceptor"
			},
			// Registered after the ordering interceptor on purpose: both listen
			// to `afterAspectsLoad`, and this one inserts into the table the
			// other has just reordered.
			{
				class : "#moduleMapping#.interceptors.ApiRouteInterceptor",
				name  : "ApiRouteInterceptor"
			}
		];
	}

	/**
	 * Core's own shortcodes.
	 *
	 * Registered here rather than in the models themselves so the whole set a
	 * site understands can be read off the ModuleConfigs, exactly like content
	 * resolvers, navigation, sitemaps and link targets.
	 */
	function onLoad(){
		var shortcodes = wirebox.getInstance( "ShortcodeRegistry@core" );
		var handler    = wirebox.getInstance( "SiteShortcodes@core" );

		for ( var definition in handler.TAGS ) {
			shortcodes.register(
				tag         = definition.tag,
				id          = "SiteShortcodes@core",
				description = definition.description
			);
		}
	}

	function onUnload(){
		var shortcodes = wirebox.getInstance( "ShortcodeRegistry@core" );

		for ( var definition in wirebox.getInstance( "SiteShortcodes@core" ).TAGS ) {
			shortcodes.unregister( definition.tag );
		}
	}

}
