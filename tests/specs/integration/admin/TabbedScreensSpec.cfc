/**
 * The invariant behind the CSS-only tabs.
 *
 * Which panel is visible is decided by POSITION — the nth radio reveals the nth
 * panel — so three things have to hold on every tabbed screen, and none of them
 * is visible by reading the CSS:
 *
 *   1. As many panels as radios.
 *   2. Exactly one radio checked, or the screen opens with every panel hidden.
 *   3. No direct-child `input` of `.tabs` other than the radios, because
 *      `:nth-of-type` counts by element type and a stray hidden field would
 *      shift every panel by one.
 *
 * The third is the one that will be broken by accident, and it fails silently:
 * the page renders, and the wrong panel opens. These specs render each tabbed
 * screen for real and check all three.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-tab-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();
		variables.sites = getInstance( "SiteService@core" );
		variables.roles = getInstance( "RoleService@core" );
		variables.users = getInstance( "UserService@core" );
		variables.auth  = getInstance( "AuthenticationService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		auth.logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Tabbed admin screens", function(){

			beforeEach( function(){
				setup();
				auth.logout();
				signIn( variables.owner );
			} );

			afterEach( function(){
				auth.logout();
			} );

			var screens = {
				"Settings"       : { uri : "/admin/settings", tabs : 6 },
				"the blog list"  : { uri : "/admin/blog",     tabs : 2 },
				"the post form"  : { uri : "/admin/blog/new", tabs : 2 },
				"the page form"  : { uri : "/admin/pages/new", tabs : 3 }
			};

			for ( var name in screens ) {
				( function( label, screen ){

					describe( label, function(){

						beforeEach( function(){
							variables.tabs = tabsOf( render( screen.uri ) );
						} );

						it( "renders the tabs it is expected to have", function(){
							expect( tabs.radios ).toBe( screen.tabs );
						} );

						it( "has one panel per tab", function(){
							expect( tabs.panels ).toBe( tabs.radios );
						} );

						it( "opens with exactly one tab selected", function(){
							expect( tabs.checked ).toBe( 1 );
						} );

						/**
						 * The load-bearing one. A hidden input placed directly
						 * inside `.tabs` renders fine and quietly opens the
						 * wrong panel.
						 */
						it( "puts no non-radio input directly inside the tab strip", function(){
							expect( tabs.stripInputs ).toBe( tabs.radios );
						} );

					} );

				} )( name, screens[ name ] );
			}

		} );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * The counts each spec asserts on.
	 *
	 * `strip` is the `.tabs` element up to its first panel — the radios and
	 * labels, and nothing a panel contains. That boundary is the whole point:
	 * a form inside a panel has hidden inputs of its own, and those are fine.
	 * Only inputs in the strip shift `:nth-of-type`.
	 */
	private struct function tabsOf( required string html ){
		var start = find( '<div class="tabs">', arguments.html );

		expect( start ).toBeGT( 0, "the screen rendered no .tabs element at all" );

		var fromTabs  = mid( arguments.html, start, len( arguments.html ) );
		var firstPanel = find( '<section class="tab-panel"', fromTabs );

		expect( firstPanel ).toBeGT( 0, "the .tabs element contains no panels" );

		var strip = mid( fromTabs, 1, firstPanel - 1 );

		return {
			"radios"       : occurrences( strip, '<input type="radio"' ),
			"checked"      : occurrences( strip, " checked>" ),
			"stripInputs"  : occurrences( strip, "<input" ),
			"panels"       : occurrences( fromTabs, '<section class="tab-panel"' )
		};
	}

	/**
	 * Substring occurrences. Deliberately not `listLen( s, needle, true )`:
	 * a list delimiter is a SET OF CHARACTERS, not a substring, so that counts
	 * something else entirely and does it convincingly.
	 */
	private numeric function occurrences( required string haystack, required string needle ){
		if ( !len( arguments.needle ) ) {
			return 0;
		}

		var without = replace( arguments.haystack, arguments.needle, "", "all" );

		return int( ( len( arguments.haystack ) - len( without ) ) / len( arguments.needle ) );
	}

	private function render( required string uri ){
		setup();

		var event = this.request(
			route   = arguments.uri,
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function signIn( required any user ){
		getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
		auth.startSessionFor( arguments.user, variables.site.getId() );

		return this;
	}

	private function seed(){
		variables.site = sites.createSite( name = "Tabs Test", slug = PREFIX & "one" );
		sites.addDomain( site.getId(), "#PREFIX#one.test" );
		roles.seedDefaultRolesForSite( site.getId() );

		variables.owner = users.createUser( site.getId(), "Owner", "owner@tabs.test", PASSWORD );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
