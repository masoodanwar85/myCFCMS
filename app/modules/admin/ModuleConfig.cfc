/**
 * The admin shell.
 *
 * Serves `/admin` on each tenant's own domain: a client's staff sign in at
 * `client.com/admin`, and a platform super admin can sign in on any client's
 * domain. There is no separate central admin host, because the tenant is
 * already resolved from the domain and adding a second way to identify one
 * would be a second thing to keep in step.
 *
 * This module owns the shell — sign-in, the layout, the dashboard — and the
 * screens for Core's own concerns: users, roles and site settings. It does not
 * own screens for feature modules. Pages contributes its own, and Blog will do
 * the same, through AdminNavigationRegistry.
 */
component {

	this.title       = "Admin";
	this.author      = "myCFCMS";
	this.description = "Administration for a tenant site.";
	this.version     = "1.0.0";

	this.cfmapping      = "admin";
	this.modelNamespace = "admin";
	this.autoMapModels  = true;

	// Claims /admin. Module entry points are prepended to the routing table,
	// so this is matched ahead of the public catch-all.
	this.entryPoint        = "admin";
	this.inheritEntryPoint = false;

	this.dependencies = [ "core" ];

	function configure(){
		settings = {};


		/**
		 * Explicit per-handler routes rather than a `/:handler/:action?` catch-all.
		 * A catch-all here would claim `/admin/pages` before the Pages module's
		 * own admin entry point could, and which of the two won would depend on
		 * module load order.
		 */
		routes = [
			{ pattern : "/",                     handler : "Dashboard", action : "index" },
			{ pattern : "/login",                handler : "Auth",      action : "login" },
			{ pattern : "/auth/:action",         handler : "Auth" },
			{ pattern : "/users/:action?/:id?",  handler : "Users" },
			{ pattern : "/roles/:action?/:id?",  handler : "Roles" },
			{ pattern : "/settings/:action?/:id?", handler : "Settings" },
			{ pattern : "/menus/:action?/:id?",  handler : "Menus" },
			{ pattern : "/api-tokens/:action?/:id?", handler : "ApiTokens" }
		];
	}

	function onLoad(){
		var nav = wirebox.getInstance( "AdminNavigationRegistry@core" );

		/**
		 * Grouped rather than flat. A group's position is the lowest order
		 * among its members, so the numbers below both order the items within
		 * a group and place the group itself:
		 *
		 *     Dashboard          10
		 *     CMS                20   Pages 20, Menus 24, Media 26
		 *     Modules            40   contributed by the feature modules
		 *     Access             60   Users 60, Roles 62
		 *     Settings           90
		 *     API                95
		 */
		nav.register( label = "Dashboard", href = "/admin", order = 10, exact = true );

		nav.register( label = "Menus", href = "/admin/menus", permission = "menus.manage", order = 24, group = "CMS" );

		// Users and Roles together: both answer "who can do what here", and
		// neither is content.
		nav.register( label = "Users", href = "/admin/users", permission = "users.view", order = 60, group = "Access" );
		nav.register( label = "Roles", href = "/admin/roles", permission = "roles.view", order = 62, group = "Access" );

		// Settings and API stay top level. Both are site configuration rather
		// than a category of screens, and a menu holding one item each would be
		// two clicks to reach what is now one.
		nav.register( label = "Settings", href = "/admin/settings", permission = "site.view", order = 90 );
		nav.register( label = "API", href = "/admin/api-tokens", permission = "api.tokens.manage", order = 95 );
	}

	function onUnload(){
		var nav = wirebox.getInstance( "AdminNavigationRegistry@core" );

		for ( var href in [ "/admin", "/admin/users", "/admin/roles", "/admin/menus", "/admin/settings", "/admin/api-tokens" ] ) {
			nav.unregister( href );
		}
	}

}
