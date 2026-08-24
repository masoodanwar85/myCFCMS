/**
 * The admin's navigation, contributed by modules.
 *
 * Same principle as ContentResolverRegistry: the admin shell must not carry a
 * hard-coded list of every module's screens, or installing Blog would mean
 * editing the admin. A module registers its own section in its ModuleConfig,
 * and the admin layout renders whatever is registered — filtered by what the
 * signed-in user may actually see.
 *
 * ## Groups
 *
 * A flat bar stopped scaling at about eight sections, and would get worse with
 * every module installed. A section may name a `group`, and sections sharing
 * one are rendered together under a single heading.
 *
 * The group's own position is the **lowest order among its members**, rather
 * than a number registered separately. That keeps one ordering scheme instead
 * of two, and means a module cannot accidentally reposition a whole group by
 * picking a low number — it can only take a place within it.
 *
 * A group is only rendered when at least one of its members survives the
 * permission filter, so a user who may reach nothing under "Access" is not
 * shown an empty menu that hints at what exists.
 */
component singleton accessors="true" {

	function init(){
		variables.sections = [];
		return this;
	}

	/**
	 * @label      Text shown in the navigation.
	 * @href       Admin URI, e.g. "/admin/pages". A URI rather than a ColdBox
	 *             event, so a section's address does not depend on reverse
	 *             routing across module entry points.
	 * @permission Permission slug required to see it. Empty means everyone signed in.
	 * @order      Lower sorts first.
	 * @match      URI prefix that marks this section current. Defaults to href.
	 * @exact      Match the current URI exactly rather than by prefix. The
	 *             dashboard needs this: its href is `/admin`, which prefixes
	 *             every other admin URL and would leave it always highlighted.
	 * @group      Heading to sit under. Empty means top level.
	 */
	function register(
		required string label,
		required string href,
		string permission = "",
		numeric order     = 100,
		string match      = "",
		boolean exact     = false,
		string group      = ""
	){
		for ( var existing in variables.sections ) {
			if ( existing.href == arguments.href ) {
				return this;
			}
		}

		variables.sections.append( {
			"label"      : arguments.label,
			"href"       : arguments.href,
			"permission" : arguments.permission,
			"order"      : arguments.order,
			"match"      : len( arguments.match ) ? arguments.match : arguments.href,
			"exact"      : arguments.exact,
			"group"      : trim( arguments.group )
		} );

		variables.sections.sort( ( a, b ) => a.order - b.order );

		return this;
	}

	function unregister( required string href ){
		var wanted = arguments.href;

		variables.sections = variables.sections.filter( ( section ) => section.href != wanted );

		return this;
	}

	array function getSections(){
		return variables.sections;
	}

	/**
	 * The sections a given user may actually reach.
	 *
	 * Navigation is filtered by the same authorisation service that guards the
	 * screens, so a link never appears that would be refused when followed.
	 */
	array function getSectionsFor( required any user, required any authorizationService ){
		var actor = arguments.user;
		var auth  = arguments.authorizationService;

		return variables.sections.filter( ( section ) => {
			return !len( section.permission ) || auth.can( actor, section.permission );
		} );
	}

	/**
	 * The same sections, arranged for rendering.
	 *
	 * Returns a flat array in display order, where an entry is either:
	 *
	 *     { type : "link",  label, href, match, exact }
	 *     { type : "group", label, items : [ <links> ] }
	 *
	 * A shape rather than a nested registry, because the layout should be able
	 * to loop once and not care which it is looking at beyond one branch.
	 */
	array function getGroupedSectionsFor( required any user, required any authorizationService ){
		var permitted = getSectionsFor( arguments.user, arguments.authorizationService );
		var entries   = [];
		var groups    = {};

		for ( var section in permitted ) {
			if ( !len( section.group ) ) {
				entries.append( {
					"type"  : "link",
					"order" : section.order,
					"label" : section.label,
					"href"  : section.href,
					"match" : section.match,
					"exact" : section.exact,
					"badge" : section.badge ?: 0
				} );

				continue;
			}

			if ( !structKeyExists( groups, section.group ) ) {
				var group = {
					"type"  : "group",
					// The group takes its position from its first member, and
					// keeps it as later ones arrive with higher numbers.
					"order" : section.order,
					"label" : section.group,
					"items" : []
				};

				groups[ section.group ] = group;
				entries.append( group );
			}

			var group = groups[ section.group ];

			group.order = min( group.order, section.order );
			group.items.append( {
				"type"  : "link",
				"order" : section.order,
				"label" : section.label,
				"href"  : section.href,
				"match" : section.match,
				"exact" : section.exact,
				"badge" : section.badge ?: 0
			} );
		}

		for ( var entry in entries ) {
			if ( entry.type == "group" ) {
				entry.items.sort( ( a, b ) => a.order - b.order );
			}
		}

		entries.sort( ( a, b ) => a.order - b.order );

		return entries;
	}

}
