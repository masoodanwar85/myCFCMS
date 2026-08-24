/**
 * A handler that throws, to prove one broken shortcode does not cost the page.
 */
component {
	string function render( struct attributes = {}, string body = "", struct context = {} ){
		throw( type = "Test.Boom", message = "deliberate" );
	}
}
