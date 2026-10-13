/**
 * A fetched page, parsed into something a check can ask questions of.
 *
 * ## Why this is not regular expressions
 *
 * Every on-page check is a question about structure — how many `<h1>` are
 * there, which `<img>` has no `alt`, what does `<link rel="canonical">` point
 * at. Regular expressions answer those questions right until the markup is
 * slightly unusual, and then answer them wrongly and silently. An audit that
 * reports the wrong thing is worse than no audit, because somebody will act on
 * it.
 *
 * ## Why TagSoup
 *
 * CFML has no HTML parser. `xmlParse` needs well-formed XML and real pages are
 * not: unclosed `<p>`, bare `<img>`, attributes without quotes. TagSoup is a
 * SAX parser built for exactly that — it reads HTML as browsers do and emits
 * well-formed XML, which `xmlParse` then accepts and `xmlSearch` can query
 * with XPath.
 *
 * It needs nothing installed. `tagsoup-1.2.jar` already ships on ColdFusion's
 * own classpath, so this adds no dependency and nothing to deploy. That is the
 * whole reason it was chosen over jsoup, which would be the obvious pick in
 * any other language.
 *
 * Namespace processing is switched off deliberately. Left on, TagSoup emits
 * every element in the XHTML namespace and every XPath below would need a
 * prefix registered to match anything — a great deal of ceremony for documents
 * that have one vocabulary.
 *
 * ## Transient, not singleton
 *
 * One of these wraps one fetched page. It holds parsed state, so it must not be
 * shared between requests.
 */
component accessors="true" {

	property name="log" inject="logbox:logger:{this}";

	variables.doc      = "";
	variables.parsed   = false;
	variables.parseError = "";

	/**
	 * @html The raw response body of a fetched page.
	 */
	function loadHtml( required string html ){
		variables.parsed     = false;
		variables.parseError = "";
		variables.doc        = "";

		if ( !len( trim( arguments.html ) ) ) {
			variables.parseError = "The response was empty.";
			return this;
		}

		try {
			var parser = createObject( "java", "org.ccil.cowan.tagsoup.Parser" );

			parser.setFeature( "http://xml.org/sax/features/namespaces", false );

			var writer    = createObject( "java", "java.io.StringWriter" ).init();
			var xmlWriter = createObject( "java", "org.ccil.cowan.tagsoup.XMLWriter" ).init( writer );

			parser.setContentHandler( xmlWriter );
			parser.parse(
				createObject( "java", "org.xml.sax.InputSource" ).init(
					createObject( "java", "java.io.StringReader" ).init( arguments.html )
				)
			);

			variables.doc    = xmlParse( writer.toString() );
			variables.parsed = true;
		} catch ( any e ) {
			// A page that cannot be parsed is a finding, not a crash: the run
			// records it and carries on to the next URL.
			variables.parseError = e.message;
			log.warn( "SEO audit could not parse a page: #e.message#" );
		}

		return this;
	}

	boolean function isParsed(){
		return variables.parsed;
	}

	string function getParseError(){
		return variables.parseError;
	}

	/* ------------------------------------------------------------- the head */

	string function title(){
		return firstText( "//title" );
	}

	/**
	 * `<meta name="description" content="...">`.
	 */
	string function metaByName( required string name ){
		return firstAttribute( "//meta[translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='#xpathLiteralSafe( lCase( arguments.name ) )#']", "content" );
	}

	/**
	 * `<meta property="og:title" content="...">`. Open Graph uses `property`
	 * rather than `name`, which is why it needs its own accessor and is the
	 * mistake most hand-written head markup makes.
	 */
	string function metaByProperty( required string property ){
		return firstAttribute( "//meta[translate(@property,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='#xpathLiteralSafe( lCase( arguments.property ) )#']", "content" );
	}

	string function linkByRel( required string rel ){
		return firstAttribute( "//link[translate(@rel,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='#xpathLiteralSafe( lCase( arguments.rel ) )#']", "href" );
	}

	/* ------------------------------------------------------------- the body */

	/**
	 * Every heading in document order, as `{ level, text }`.
	 *
	 * Order matters: "h1 then h3" is only a finding if they appear in that
	 * sequence, so this must not be sorted or grouped.
	 */
	array function headings(){
		if ( !variables.parsed ) {
			return [];
		}

		var found = [];

		for ( var node in search( "//h1|//h2|//h3|//h4|//h5|//h6" ) ) {
			found.append( {
				"level" : val( right( node.xmlName, 1 ) ),
				"text"  : normaliseSpace( node.xmlText ?: "" )
			} );
		}

		return found;
	}

	/**
	 * Every `<img>`, as `{ src, alt, hasAlt }`.
	 *
	 * `hasAlt` is whether the attribute is **present**, which is not the same
	 * question as whether it has a value. `alt=""` is a deliberate, correct
	 * statement that an image is decorative; a missing `alt` is an omission.
	 * Collapsing the two would make the check nag about images that are already
	 * right.
	 */
	array function images(){
		if ( !variables.parsed ) {
			return [];
		}

		var found = [];

		for ( var node in search( "//img" ) ) {
			var attrs = node.xmlAttributes;

			found.append( {
				"src"    : attrs.src ?: "",
				"alt"    : attrs.alt ?: "",
				"hasAlt" : structKeyExists( attrs, "alt" )
			} );
		}

		return found;
	}

	/**
	 * Every `<a href>`, as `{ href, text }`. Anchors without an `href` are not
	 * links and are left out.
	 */
	array function links(){
		if ( !variables.parsed ) {
			return [];
		}

		var found = [];

		for ( var node in search( "//a[@href]" ) ) {
			found.append( {
				"href" : trim( node.xmlAttributes.href ?: "" ),
				"text" : normaliseSpace( node.xmlText ?: "" )
			} );
		}

		return found;
	}

	/**
	 * The readable text of the page body, for counting words.
	 *
	 * `<script>`, `<style>` and `<noscript>` are excluded: their contents are
	 * code, and counting them would make a page with a large inline script look
	 * substantial when it has nothing to read.
	 *
	 * Navigation, headers and footers are *not* excluded. They are text on the
	 * page and a crawler sees them, so removing them would be a judgement about
	 * what counts rather than a measurement. It does mean a thin page on a site
	 * with a large footer measures higher than it reads, which is why the thin
	 * content threshold is deliberately low.
	 */
	string function bodyText(){
		if ( !variables.parsed ) {
			return "";
		}

		// Said as one XPath rather than by walking the tree. `xmlText` on an
		// element returns its descendants' text concatenated, so a walk cannot
		// separate a node's own text from a `<script>` nested inside it — the
		// exclusion has to be part of the selection, not applied afterwards.
		var nodes = search(
			"//body//text()[not(ancestor::script) and not(ancestor::style) and not(ancestor::noscript)]"
		);

		var parts = [];

		for ( var node in nodes ) {
			// ACF returns text() matches as strings in some versions and as
			// nodes in others. Both are handled rather than relying on one.
			parts.append( isSimpleValue( node ) ? node : ( node.xmlValue ?: node.xmlText ?: "" ) );
		}

		return normaliseSpace( parts.toList( " " ) );
	}

	numeric function wordCount(){
		var text = bodyText();

		return len( text ) ? listLen( text, " " ) : 0;
	}

	/* ---------------------------------------------------------- internals */

	private array function search( required string xpath ){
		if ( !variables.parsed ) {
			return [];
		}

		try {
			var found = xmlSearch( variables.doc, arguments.xpath );

			return isArray( found ) ? found : [];
		} catch ( any e ) {
			log.warn( "SEO audit XPath [#arguments.xpath#] failed: #e.message#" );
			return [];
		}
	}

	private string function firstText( required string xpath ){
		var found = search( arguments.xpath );

		return found.len() ? normaliseSpace( found[ 1 ].xmlText ?: "" ) : "";
	}

	private string function firstAttribute( required string xpath, required string attribute ){
		var found = search( arguments.xpath );

		if ( !found.len() ) {
			return "";
		}

		return trim( found[ 1 ].xmlAttributes[ arguments.attribute ] ?: "" );
	}

	/**
	 * Strip a value that would break out of the XPath string literal it is
	 * interpolated into. Only ever called with names this module supplies, but
	 * an XPath built by concatenation is an injection site whether or not
	 * anything hostile reaches it today.
	 */
	private string function xpathLiteralSafe( required string value ){
		return reReplace( arguments.value, "[^a-zA-Z0-9:_.\-]", "", "all" );
	}

	private string function normaliseSpace( required string value ){
		return trim( reReplace( arguments.value, "\s+", " ", "all" ) );
	}

}
