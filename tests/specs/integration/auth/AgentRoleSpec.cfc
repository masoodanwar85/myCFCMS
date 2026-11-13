/**
 * The `agent` role: what an automated API client is allowed to do.
 *
 * This is a privilege boundary, so it gets specs that fail loudly rather than a
 * list in two files that nobody rereads. Two things are asserted:
 *
 *   1. **The deny list.** Each absent permission is named individually, so
 *      granting one by accident — or by widening the role to "everything" —
 *      fails a spec that says which one and why.
 *   2. **The two definitions agree.** The role is defined in
 *      `RoleService.DEFAULT_ROLES` for sites created from now on, and repeated
 *      in `2026_10_29_100000_seed_agent_role.cfc` for sites that already
 *      existed. A migration cannot reach WireBox, so the duplication is
 *      unavoidable; drifting silently is not.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-agentrole-";

	variables.MIGRATION = "/Applications/ColdFusion2025/cfusion/wwwroot/myCFCMS/"
		& "resources/database/migrations/2026_10_29_100000_seed_agent_role.cfc";

	function beforeAll(){
		super.beforeAll();

		variables.roles = getInstance( "RoleService@core" );
		variables.sites = getInstance( "SiteService@core" );
		variables.users = getInstance( "UserService@core" );
		variables.auth  = getInstance( "AuthorizationService@core" );

		cleanup();

		variables.site = sites.createSite( name = "Agent Role", slug = PREFIX & "one" );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.agentUser = users.createUser( site.getId(), "Agent", "a@#PREFIX#one.test", "demo-password-123" );
		users.assignRole( agentUser.getId(), roles.getRoleBySlugForSite( "agent", site.getId() ).getId() );
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The agent role", function(){

			it( "is seeded for a new site", function(){
				expect( isNull( roles.getRoleBySlugForSite( "agent", site.getId() ) ) ).toBeFalse();
			} );

			it( "can do the content work it exists for", function(){
				for ( var slug in [
					"site.view",
					"pages.view", "pages.create", "pages.update", "pages.publish",
					"media.view", "media.upload",
					"seo.view", "seo.run"
				] ) {
					expect( auth.can( agentUser, slug, site.getId() ) )
						.toBeTrue( "an agent must be able to [#slug#]" );
				}
			} );

			it( "cannot delete anything", function(){
				// Nothing an automated client does should be unrecoverable.
				expect( auth.can( agentUser, "pages.delete", site.getId() ) ).toBeFalse();
				expect( auth.can( agentUser, "media.delete", site.getId() ) ).toBeFalse();
			} );

			it( "cannot post raw HTML", function(){
				// `content.unfiltered` bypasses AntiSamy, `<script>` included.
				expect( auth.can( agentUser, "content.unfiltered", site.getId() ) ).toBeFalse();
			} );

			it( "cannot widen its own access", function(){
				// The worst thing an over-granted agent could do is grant
				// itself more, or issue itself a second token.
				for ( var slug in [
					"users.create", "users.update", "users.delete",
					"roles.create", "roles.update", "roles.delete",
					"api.tokens.manage"
				] ) {
					expect( auth.can( agentUser, slug, site.getId() ) )
						.toBeFalse( "an agent must NOT be able to [#slug#]" );
				}
			} );

			it( "cannot change site configuration", function(){
				for ( var slug in [ "site.update", "site.settings.manage", "site.domains.manage" ] ) {
					expect( auth.can( agentUser, slug, site.getId() ) )
						.toBeFalse( "an agent must NOT be able to [#slug#]" );
				}
			} );

			it( "is not a role that grants everything", function(){
				// A role meaning "everything" silently acquires each new
				// permission a module registers. Right for an owner, wrong for
				// a non-human client — so the definition must be an explicit
				// list, whatever is currently on it.
				var definition = definitionFor( "agent" );

				expect( definition ).notToHaveKey(
					"grantsEverything",
					"the agent role must list its permissions explicitly"
				);
				expect( definition.permissions ).notToBeEmpty();
			} );

			it( "is defined identically in the role service and the migration", function(){
				// The duplication exists because a migration runs with no
				// application context and cannot ask WireBox. This is what
				// stops the two copies drifting.
				var fromService   = definitionFor( "agent" ).permissions;
				var fromMigration = createMock( migrationComponent() )
					.$getProperty( "PERMISSIONS", "variables" );

				expect( fromMigration.sort( "textnocase" ) ).toBe( fromService.sort( "textnocase" ) );
			} );

			it( "leaves the human editor role untouched", function(){
				// The reason the agent is its own role rather than a widened
				// `editor`: widening that would hand every human editor on
				// every site these permissions too.
				var editor = definitionFor( "editor" );

				expect( editor.permissions ).toBe( [ "site.view", "users.view", "roles.view" ] );
			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private struct function definitionFor( required string slug ){
		var wanted = arguments.slug;
		var found  = roles.getDefaultRoleDefinitions().filter( ( d ) => d.slug == wanted );

		expect( found.len() ).toBe( 1, "no default role definition for [#wanted#]" );

		return found[ 1 ];
	}

	/**
	 * The migration as a component path.
	 *
	 * Migrations live outside the application's mappings, so this reads the one
	 * file by its dotted path from the webroot rather than inventing a mapping
	 * the rest of the suite does not have.
	 */
	private string function migrationComponent(){
		expect( fileExists( variables.MIGRATION ) )
			.toBeTrue( "the agent role migration is missing: " & variables.MIGRATION );

		return "resources.database.migrations.2026_10_29_100000_seed_agent_role";
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
