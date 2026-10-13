/**
 * The Open Graph tags that decide what a shared link looks like.
 *
 * All notices. None of these affect search ranking at all — they affect what
 * appears when somebody pastes the URL into Facebook, LinkedIn, Slack or
 * WhatsApp. Worth knowing, never worth alarming anyone about, and ranking them
 * alongside a broken canonical would be dishonest about what matters.
 *
 * Only `og:image` is checked for presence rather than quality. Whether the
 * image is the right shape for a card is a judgement this cannot make without
 * fetching it, which is a per-page HTTP request for a cosmetic finding.
 */
component singleton accessors="true" {

	this.ID = "opengraph";

	variables.WANTED = [
		{ "property" : "og:title",       "label" : "title" },
		{ "property" : "og:description", "label" : "description" },
		{ "property" : "og:image",       "label" : "image" }
	];

	array function inspect( required any document, required struct context ){
		var absent = [];

		for ( var tag in variables.WANTED ) {
			if ( !len( arguments.document.metaByProperty( tag.property ) ) ) {
				absent.append( tag.label );
			}
		}

		if ( !absent.len() ) {
			return [];
		}

		return [ {
			"checkId"  : "opengraph.missing",
			"severity" : "notice",
			"message"  : "Shared links will show no #absent.toList( ", " )#.",
			"detail"   : absent.map( ( label ) => "og:" & label ).toList( " | " )
		} ];
	}

}
