/**
 * An SEO check that throws, to prove one broken check does not cost the others
 * on every URL of a site.
 */
component {
	array function inspect( required any document, required struct context ){
		throw( type = "Zzt.Deliberate", message = "This check is deliberately broken." );
	}
}
