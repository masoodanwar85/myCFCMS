/**
 * The shortcodes a site understands, contributed by the modules that own them.
 *
 * The fifth registry on the pattern Core already uses. Unlike the others this
 * one is keyed by tag rather than ordered by priority: two modules claiming
 * `[image]` is a conflict to report, not a race to resolve.
 *
 * A handler is any object with:
 *
 *     string render( struct attributes, string body, struct context )
 *
 * `context` carries `{ siteId, path }`. A handler returns **HTML that will not
 * be sanitised** — it is application code, not author input — so a handler is
 * responsible for escaping anything that came from the attributes or body it
 * was given. `ShortcodeService` hands every handler an `escape` helper in the
 * context for exactly that.
 */
component singleton accessors="true" {

	property name="wirebox" inject="wirebox";
	property name="log"     inject="logbox:logger:{this}";

	function init(){
		// tag -> { id : <wirebox id>, description : "..." }
		variables.handlers = {};
		return this;
	}

	/**
	 * @tag         The tag without brackets, e.g. `image`.
	 * @id          WireBox id, resolved lazily so module load order does not matter.
	 * @description Shown in the admin's shortcode reference.
	 *
	 * @throws Shortcode.TagAlreadyRegistered
	 */
	function register( required string tag, required string id, string description = "" ){
		var name = lCase( trim( arguments.tag ) );

		if ( !len( name ) ) {
			throw( type = "Shortcode.InvalidTag", message = "A shortcode needs a tag." );
		}

		if ( structKeyExists( variables.handlers, name ) && variables.handlers[ name ].id != arguments.id ) {
			// Loudly, rather than last-registration-wins: whichever module
			// loaded second would otherwise silently change what an existing
			// page renders.
			throw(
				type    = "Shortcode.TagAlreadyRegistered",
				message = "[#name#] is already handled by [#variables.handlers[ name ].id#]."
			);
		}

		variables.handlers[ name ] = { "id" : arguments.id, "description" : arguments.description };

		return this;
	}

	function unregister( required string tag ){
		structDelete( variables.handlers, lCase( trim( arguments.tag ) ) );
		return this;
	}

	boolean function has( required string tag ){
		return structKeyExists( variables.handlers, lCase( trim( arguments.tag ) ) );
	}

	/**
	 * The handler for one tag, or null.
	 */
	function handlerFor( required string tag ){
		var name = lCase( trim( arguments.tag ) );

		if ( !structKeyExists( variables.handlers, name ) ) {
			return;
		}

		try {
			return wirebox.getInstance( variables.handlers[ name ].id );
		} catch ( any e ) {
			log.error( "Shortcode handler [#variables.handlers[ name ].id#] could not be resolved: #e.message#" );
			return;
		}
	}

	/**
	 * Every registered tag, for the admin's reference screen.
	 */
	array function getRegistered(){
		return structKeyArray( variables.handlers )
			.sort( "textnocase" )
			.map( ( tag ) => {
				return {
					"tag"         : tag,
					"id"          : variables.handlers[ tag ].id,
					"description" : variables.handlers[ tag ].description
				};
			} );
	}

}
