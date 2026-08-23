/**
 * Turns whatever arrives on the wire into the canonical form we store in
 * `site_domains.domain`.
 *
 * Normalisation lives here — in one place — so that the value written by an
 * administrator and the value read from the `Host` header can never disagree.
 *
 * Deliberately NOT stripping a `www.` prefix: `client.com` and `www.client.com`
 * are separate rows so an operator can decide which one is primary and whether
 * the other is active at all.
 */
component singleton {

	/**
	 * @host A hostname, optionally including scheme, port, path or trailing dot.
	 *
	 * @return The canonical hostname, or an empty string when nothing usable is left.
	 */
	string function normalize( string host = "" ){
		var value = trim( arguments.host ?: "" );

		if ( !len( value ) ) {
			return "";
		}

		value = lCase( value );

		// Drop a scheme, if someone stored or sent a full URL.
		value = reReplace( value, "^[a-z][a-z0-9+.-]*://", "" );

		// Drop userinfo, path, query and fragment.
		value = listFirst( value, "/?##" );
		if ( find( "@", value ) ) {
			value = listLast( value, "@" );
		}

		// Drop the port. IPv6 literals keep their brackets and are left alone.
		if ( !find( "[", value ) ) {
			value = listFirst( value, ":" );
		}

		// A fully-qualified name may carry a trailing root dot.
		value = reReplace( value, "\.+$", "" );

		return isValidHost( value ) ? value : "";
	}

	/**
	 * Cheap structural check. This rejects obvious junk before it reaches the
	 * database; it is not a substitute for the unique index.
	 */
	boolean function isValidHost( required string host ){
		if ( !len( arguments.host ) || len( arguments.host ) > 255 ) {
			return false;
		}

		// IPv6 literal, e.g. [::1]
		if ( reFind( "^\[[0-9a-f:]+\]$", arguments.host ) ) {
			return true;
		}

		// Labels of alphanumerics and hyphens, hyphens never leading or trailing.
		return reFind( "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", arguments.host ) > 0;
	}

}
