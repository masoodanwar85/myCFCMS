/**
 * One change made through the API.
 *
 * State only, plus the small amount of presentation a reader needs: the raw
 * JSON snapshots are stored as text, and nobody reads a page's whole body to
 * find out what changed, so this knows how to say which fields differ.
 */
component accessors="true" {

	property name="id"           type="numeric";
	property name="siteId"       type="numeric";
	property name="userId"       type="numeric";
	property name="tokenId"      type="numeric";
	property name="action"       type="string";
	property name="resourceType" type="string";
	property name="resourceId"   type="numeric";
	property name="beforeJson"   type="string";
	property name="afterJson"    type="string";
	property name="createdAt";

	// Joined in for the screen, so one query answers "who did this" rather than
	// one extra lookup per row. Empty when the user or token has since been
	// deleted — the change outlives both.
	property name="userName"  type="string";
	property name="tokenName" type="string";

	/**
	 * The names of the fields whose values differ between the two snapshots.
	 *
	 * This is what somebody reading the log actually wants: not two thousand
	 * characters of page body, but "title, metaDescription, canonicalUrl". The
	 * full snapshots stay available for when the answer is "what exactly did it
	 * say before".
	 *
	 * A key present in one snapshot and absent from the other counts as
	 * changed, which is how a create (no `before`) lists everything it set and
	 * a delete lists everything it removed.
	 */
	array function changedFields(){
		var was = parsed( variables.beforeJson ?: "" );
		var now = parsed( variables.afterJson ?: "" );

		var names = {};

		for ( var key in was ) {
			names[ key ] = true;
		}
		for ( var key in now ) {
			names[ key ] = true;
		}

		var changed = [];

		for ( var key in names.keyArray().sort( "textnocase" ) ) {
			if ( !structKeyExists( was, key ) || !structKeyExists( now, key ) ) {
				changed.append( key );
				continue;
			}

			// Compared as text, because these came from JSON and a number that
			// round-trips as `1` and `1.0` is not a change anybody means.
			if ( toText( was[ key ] ) != toText( now[ key ] ) ) {
				changed.append( key );
			}
		}

		return changed;
	}

	/**
	 * Whether this change can be undone by reading the log — which is the
	 * question the log is kept to answer. A delete cannot, because the row is
	 * gone; everything else can, because `before` says what it was.
	 */
	boolean function isReversible(){
		return ( variables.action ?: "" ) != "delete" && len( variables.beforeJson ?: "" ) > 2;
	}

	private struct function parsed( required string json ){
		if ( !len( trim( arguments.json ) ) || !isJSON( arguments.json ) ) {
			return {};
		}

		var value = deserializeJSON( arguments.json );

		return isStruct( value ) ? value : {};
	}

	/**
	 * A value as something comparable. A nested struct or array is compared by
	 * its serialised form rather than walked: the log reports *that* a field
	 * changed, and a field that holds a structure changed if its JSON did.
	 */
	private string function toText( required any value ){
		if ( isSimpleValue( arguments.value ) ) {
			return toString( arguments.value );
		}

		return serializeJSON( arguments.value );
	}

}
