/**
 * A handler that emits another shortcode, to prove expansion is a single pass.
 */
component {
	string function render( struct attributes = {}, string body = "", struct context = {} ){
		return "[year]";
	}
}
