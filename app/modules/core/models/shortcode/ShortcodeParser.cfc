/**
 * Turns `[tag attr="value"]body[/tag]` into a list of tokens.
 *
 * A hand-written scanner rather than a regular expression. The pattern this
 * needs — a tag, an arbitrary attribute list, an optional body ending in a
 * *matching* closing tag — wants backreferences and lazy groups, and this
 * project has already been bitten twice by assumptions about which regex engine
 * ColdFusion is using and what it supports. A scanner is longer and does
 * exactly what it says.
 *
 * Recognised forms:
 *
 *     [year]                          self-closing
 *     [image id="12" align="right"]   self-closing with attributes
 *     [button url="/x"]Read on[/button]
 *     [[year]]                        an escape: renders the literal text [year]
 *
 * Returns a flat array of tokens, in source order:
 *
 *     { type : "text",      value : "..." }
 *     { type : "shortcode", tag : "image", attributes : {...}, body : "...", source : "[image ...]" }
 *
 * `source` is kept so a caller can put the original text back when nothing
 * handles the tag.
 *
 * Deliberately **not** recursive. A shortcode body is passed to its handler as
 * plain text; a handler that wants to expand what is inside it can ask the
 * service to. That keeps a malformed document from costing unbounded work, and
 * makes "what does this expand to" answerable by reading one handler.
 */
component singleton accessors="true" {

	// A tag is a letter followed by letters, digits, hyphens or underscores.
	// Deliberately narrow: it is what stops `[1]`, `[see fig. 2]` and most
	// prose in square brackets from being read as markup.
	variables.TAG_START = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
	variables.TAG_CHARS = variables.TAG_START & "0123456789-_";

	array function parse( string content = "" ){
		var text   = arguments.content ?: "";
		var length = len( text );
		var tokens = [];
		var buffer = "";
		var i      = 1;

		while ( i <= length ) {
			var char = mid( text, i, 1 );

			if ( char != "[" ) {
				buffer &= char;
				i++;
				continue;
			}

			// `[[` opens an escape. Everything up to the matching `]]` is
			// emitted as literal text, so an author can write about the
			// shortcodes themselves.
			if ( mid( text, i + 1, 1 ) == "[" ) {
				var close = find( "]]", text, i + 2 );

				if ( close ) {
					// The brackets come back: `[[year]]` is how an author
					// writes about the `[year]` shortcode without invoking it,
					// so the literal text they want is `[year]`, not `year`.
					buffer &= "[" & mid( text, i + 2, close - i - 2 ) & "]";
					i = close + 2;
					continue;
				}
			}

			var tag = readTag( text, i + 1 );

			if ( isNull( tag ) ) {
				// Not a shortcode — an ordinary bracket in prose.
				buffer &= char;
				i++;
				continue;
			}

			if ( len( buffer ) ) {
				tokens.append( { "type" : "text", "value" : buffer } );
				buffer = "";
			}

			tokens.append( tag.token );
			i = tag.next;
		}

		if ( len( buffer ) ) {
			tokens.append( { "type" : "text", "value" : buffer } );
		}

		return tokens;
	}

	/* --------------------------------------------------------------------- */

	/**
	 * Read one shortcode starting at `start` (the character after the `[`).
	 *
	 * @return `{ token : {...}, next : <index after the shortcode> }`, or null
	 *         when this is not a shortcode after all.
	 */
	private function readTag( required string text, required numeric start ){
		var i    = arguments.start;
		var name = "";

		if ( !find( mid( arguments.text, i, 1 ), variables.TAG_START ) ) {
			return;
		}

		while ( i <= len( arguments.text ) && find( mid( arguments.text, i, 1 ), variables.TAG_CHARS ) ) {
			name &= mid( arguments.text, i, 1 );
			i++;
		}

		var attributes = readAttributes( arguments.text, i );

		if ( isNull( attributes ) ) {
			return;
		}

		var openEnd = attributes.next;
		var source  = mid( arguments.text, arguments.start - 1, openEnd - arguments.start + 2 );

		var token = {
			"type"       : "shortcode",
			"tag"        : lCase( name ),
			"attributes" : attributes.values,
			"body"       : "",
			"source"     : source
		};

		// A matching `[/tag]` turns this into an enclosing shortcode. Absent
		// one, it stands alone — so `[button]` on its own is not left hunting
		// for a close tag through the rest of the document.
		var closing = "[/" & name & "]";
		var at      = findNoCase( closing, arguments.text, openEnd + 1 );

		if ( at ) {
			token.body   = mid( arguments.text, openEnd + 1, at - openEnd - 1 );
			token.source = mid( arguments.text, arguments.start - 1, at + len( closing ) - arguments.start + 1 );

			return { "token" : token, "next" : at + len( closing ) };
		}

		return { "token" : token, "next" : openEnd + 1 };
	}

	/**
	 * Read `attr="value" other='v' bare` up to the closing `]`.
	 *
	 * @return `{ values : {...}, next : <index of the `]`> }`, or null when
	 *         there is no closing bracket — an unterminated `[` is prose.
	 */
	private function readAttributes( required string text, required numeric start ){
		var i      = arguments.start;
		var length = len( arguments.text );
		var values = {};

		while ( i <= length ) {
			var char = mid( arguments.text, i, 1 );

			if ( char == " " || char == chr( 9 ) || char == chr( 10 ) || char == chr( 13 ) ) {
				i++;
				continue;
			}

			// A trailing slash before the bracket: `[image id="1" /]`.
			if ( char == "/" && mid( arguments.text, i + 1, 1 ) == "]" ) {
				return { "values" : values, "next" : i + 1 };
			}

			if ( char == "]" ) {
				return { "values" : values, "next" : i };
			}

			var name = "";

			while ( i <= length && find( mid( arguments.text, i, 1 ), variables.TAG_CHARS ) ) {
				name &= mid( arguments.text, i, 1 );
				i++;
			}

			if ( !len( name ) ) {
				// Something that is neither an attribute nor a close: not a
				// shortcode. `[see p. 4]` lands here.
				return;
			}

			// Skip whitespace before `=`.
			while ( i <= length && mid( arguments.text, i, 1 ) == " " ) {
				i++;
			}

			if ( mid( arguments.text, i, 1 ) != "=" ) {
				// A bare attribute: `[button primary]`. Present, with no value.
				values[ lCase( name ) ] = "";
				continue;
			}

			i++;

			while ( i <= length && mid( arguments.text, i, 1 ) == " " ) {
				i++;
			}

			var quote = mid( arguments.text, i, 1 );
			var value = "";

			// An entity-encoded quote is still a quote.
			//
			// Content reaches this parser *after* the sanitiser has run, and
			// AntiSamy encodes quote characters in text — so what an author
			// typed as `count="3"` is stored as `count=&quot;3&quot;`. Read
			// naively that is an unquoted value of `&quot;3&quot;`, which is
			// not a number, and every shortcode attribute written in the editor
			// silently fell back to its default.
			var entity = quoteEntityAt( arguments.text, i );

			if ( len( entity ) ) {
				i += len( entity );

				var close = find( entity, arguments.text, i );

				if ( !close ) {
					return;
				}

				value = mid( arguments.text, i, close - i );
				i     = close + len( entity );
			} else if ( quote == '"' || quote == "'" ) {
				i++;

				var close = find( quote, arguments.text, i );

				if ( !close ) {
					// An unterminated quote would otherwise swallow the rest of
					// the document.
					return;
				}

				value = mid( arguments.text, i, close - i );
				i     = close + 1;
			} else {
				while ( i <= length
					&& mid( arguments.text, i, 1 ) != " "
					&& mid( arguments.text, i, 1 ) != "]" ) {
					value &= mid( arguments.text, i, 1 );
					i++;
				}
			}

			values[ lCase( name ) ] = decodeEntities( value );
		}

		return;
	}

	/**
	 * The quote entity starting at `pos`, or an empty string.
	 *
	 * An explicit list rather than a general HTML decoder: these are the only
	 * forms a sanitiser produces for a quote, and a parser that guessed at
	 * arbitrary entities would start reading prose as markup.
	 */
	private string function quoteEntityAt( required string text, required numeric pos ){
		for ( var entity in [ "&quot;", "&##34;", "&##x22;", "&apos;", "&##39;", "&##x27;" ] ) {
			if ( mid( arguments.text, arguments.pos, len( entity ) ) == entity ) {
				return entity;
			}
		}

		return "";
	}

	/**
	 * Put back the characters the sanitiser encoded, so a handler receives what
	 * the author actually typed.
	 *
	 * `&amp;` is done last, or `&amp;quot;` would decode twice and reintroduce
	 * a quote the author had escaped on purpose.
	 */
	private string function decodeEntities( required string value ){
		var out = arguments.value;

		out = replace( out, "&quot;", '"', "all" );
		out = replace( out, "&##34;", '"', "all" );
		out = replace( out, "&##x22;", '"', "all" );
		out = replace( out, "&apos;", "'", "all" );
		out = replace( out, "&##39;", "'", "all" );
		out = replace( out, "&##x27;", "'", "all" );
		out = replace( out, "&lt;", "<", "all" );
		out = replace( out, "&gt;", ">", "all" );
		out = replace( out, "&amp;", "&", "all" );

		return out;
	}

}
