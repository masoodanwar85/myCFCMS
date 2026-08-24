/**
 * Expands shortcodes in a piece of content.
 *
 * ## Where this runs, and why that matters
 *
 * Content is **sanitised on save** and **expanded on render**. That order is
 * deliberate:
 *
 *   - `[gallery id="3"]` is plain text, so it survives the AntiSamy policy
 *     untouched. Storing expanded HTML instead would mean the sanitiser had to
 *     permit whatever a shortcode emits, which is the opposite of the point.
 *   - Expansion happens after sanitising has already run, so **handler output
 *     is never sanitised**. That is correct — it is application code, not
 *     author input — and it is also the sharp edge: a handler that
 *     interpolates an attribute into its output without escaping has created a
 *     stored XSS hole. Every handler gets an `escape` callback in its context,
 *     and the specs check the shipped ones.
 *
 * ## One pass
 *
 * A handler's output is not re-scanned. A shortcode that emitted another
 * shortcode could otherwise loop forever on a page an author is free to write,
 * and "what does this expand to" would stop being answerable by reading one
 * handler. A handler that genuinely wants to expand its own body can call
 * `expand()` itself.
 *
 * ## Unknown tags are left alone
 *
 * An unrecognised `[tag]` is put back exactly as written rather than removed.
 * Silently deleting it would make a typo indistinguishable from a shortcode
 * that worked, and would quietly erase content when a module is uninstalled.
 * The cost is that an author sees their mistake on the page — which is the
 * point.
 */
component singleton accessors="true" {

	property name="parser"   inject="ShortcodeParser@core";
	property name="registry" inject="ShortcodeRegistry@core";
	property name="log"      inject="logbox:logger:{this}";

	/**
	 * @content The stored content.
	 * @context `{ siteId : 1, path : "about" }` — passed to every handler.
	 */
	string function expand( string content = "", struct context = {} ){
		var text = arguments.content ?: "";

		// The overwhelmingly common case: content with no shortcodes in it at
		// all. Checking first means an ordinary page never pays for the scan.
		if ( !find( "[", text ) ) {
			return text;
		}

		var handlerContext = buildContext( arguments.context );
		var output         = [];

		for ( var token in parser.parse( text ) ) {
			if ( token.type == "text" ) {
				output.append( token.value );
				continue;
			}

			var handler = registry.handlerFor( token.tag );

			if ( isNull( handler ) ) {
				output.append( token.source );
				continue;
			}

			try {
				// The tag travels in the context so one component can answer
				// for several related shortcodes without a file each.
				var callContext = duplicate( handlerContext );
				callContext.tag = token.tag;
				// `duplicate` does not carry a closure, so put it back.
				callContext.escape = handlerContext.escape;

				output.append(
					handler.render(
						attributes = token.attributes,
						body       = token.body,
						context    = callContext
					)
				);
			} catch ( any e ) {
				// One broken shortcode should cost its own output, not the
				// whole page. The original text goes back so the author can see
				// which one failed.
				log.error( "Shortcode [#token.tag#] failed: #e.message#" );
				output.append( token.source );
			}
		}

		return output.toList( "" );
	}

	/**
	 * Does this content contain anything worth expanding?
	 *
	 * Lets an admin screen warn that a page uses a shortcode no installed
	 * module handles, rather than leaving the author to spot it on the site.
	 */
	array function findUnknownTags( string content = "" ){
		var unknown = {};

		if ( !find( "[", arguments.content ?: "" ) ) {
			return [];
		}

		for ( var token in parser.parse( arguments.content ) ) {
			if ( token.type == "shortcode" && !registry.has( token.tag ) ) {
				unknown[ token.tag ] = true;
			}
		}

		return structKeyArray( unknown ).sort( "textnocase" );
	}

	/* --------------------------------------------------------------------- */

	private struct function buildContext( required struct given ){
		var context = duplicate( arguments.given );

		context.siteId = val( context.siteId ?: 0 );
		context.path   = context.path ?: "";

		// Handed to every handler so escaping is the near thing to reach for.
		// A handler that writes an attribute straight into its output without
		// this has made a stored XSS hole on every page using the shortcode.
		//
		// `xmlFormat` rather than `encodeForHTML`, for the same reason the SEO
		// meta tags use it: both are safe in a text node or a quoted attribute,
		// and the aggressive one turns every `/` and `:` in a URL into a
		// numeric entity — valid, unreadable in the page source, and a
		// well-known way to confuse naive downstream parsers.
		context.escape = ( value ) => xmlFormat( arguments.value ?: "" );

		return context;
	}

}
