/**
 * What changed through the API, recorded so it can be reconstructed later.
 *
 * The API lets a token write content, and the `agent` role exists so an
 * automated client can hold one. This is the other half of that: when a page is
 * wrong on Monday, "which token did it and what did it say before" has an
 * answer that does not depend on anybody having been watching.
 *
 * ## A failed log never fails the request
 *
 * `record()` catches everything and logs it. By the time it is called the page
 * has already been created, published or deleted — refusing the response at
 * that point would tell the client the change did not happen when it did, and
 * a client that retried would create it twice. So a write that cannot be
 * recorded is reported to the application log at error level and the request
 * succeeds.
 *
 * shortcut: the entry is written after the change rather than in the same
 * transaction, so a crash in between loses the entry and keeps the change. The
 * services do not expose transactions to handlers; closing the gap means
 * threading one through, and it is not worth that until something actually
 * depends on the log being complete rather than merely useful.
 *
 * ## What is not recorded
 *
 * Reads. A log of every `GET` would be an access log — useful, much larger, and
 * a different thing — and it would bury the handful of entries that say
 * somebody changed something.
 *
 * Changes made through the admin screens. Those carry a session rather than a
 * token, and the screens already attribute content to its author and editor.
 * This table is about the boundary a non-human client crosses.
 */
component singleton accessors="true" {

	property name="repository" inject="ApiChangeRepository@core";
	property name="wirebox"    inject="wirebox";
	property name="log"        inject="logbox:logger:{this}";

	/**
	 * Record one change.
	 *
	 * @action       `create`, `update`, `publish`, `unpublish`, `delete`, `upload`.
	 * @resourceType `page`, `media`.
	 * @before       The resource as it was, or an empty struct for a create.
	 * @after        The resource as it now is, or an empty struct for a delete.
	 * @userId       The token's user. Null for nothing, which should not happen
	 *               on an authenticated request but must not throw if it does.
	 *
	 * @return The entry, or nothing when it could not be written.
	 */
	function record(
		required numeric siteId,
		required string action,
		required string resourceType,
		numeric resourceId,
		numeric userId,
		numeric tokenId,
		struct before = {},
		struct after  = {}
	){
		try {
			var change = wirebox
				.getInstance( "ApiChange@core" )
				.setSiteId( arguments.siteId )
				.setAction( trim( arguments.action ) )
				.setResourceType( trim( arguments.resourceType ) )
				.setBeforeJson( asJson( arguments.before ) )
				.setAfterJson( asJson( arguments.after ) );

			// Set only when given: these columns are nullable, and an entity
			// property left alone reads as null.
			if ( !isNull( arguments.resourceId ) && arguments.resourceId ) {
				change.setResourceId( arguments.resourceId );
			}
			if ( !isNull( arguments.userId ) && arguments.userId ) {
				change.setUserId( arguments.userId );
			}
			if ( !isNull( arguments.tokenId ) && arguments.tokenId ) {
				change.setTokenId( arguments.tokenId );
			}

			return repository.create( change );
		} catch ( any e ) {
			// Deliberately swallowed — see the note at the top of this file.
			log.error(
				"Could not record an API change (#arguments.action# #arguments.resourceType#) on site [#arguments.siteId#]: #e.message#",
				e
			);
		}
	}

	/* -------------------------------------------------------------- reads */

	array function getForSite(
		required numeric siteId,
		numeric limit       = 50,
		numeric offset      = 0,
		string resourceType = "",
		numeric resourceId  = 0
	){
		return repository.findForSite(
			arguments.siteId,
			arguments.limit,
			arguments.offset,
			arguments.resourceType,
			arguments.resourceId
		);
	}

	numeric function countForSite(
		required numeric siteId,
		string resourceType = "",
		numeric resourceId  = 0
	){
		return repository.countForSite( arguments.siteId, arguments.resourceType, arguments.resourceId );
	}

	function getChange( required numeric id, required numeric siteId ){
		return repository.findById( arguments.id, arguments.siteId );
	}

	/* ---------------------------------------------------------- internals */

	/**
	 * A snapshot as JSON.
	 *
	 * An empty struct is stored as `{}` rather than as an empty string, so a
	 * reader never has to tell "there was nothing before" apart from "nobody
	 * wrote the snapshot".
	 */
	private string function asJson( required struct snapshot ){
		try {
			return serializeJSON( arguments.snapshot );
		} catch ( any e ) {
			// A snapshot that will not serialise must not lose the entry that
			// says a change happened. The fact is worth more than the detail.
			log.warn( "An API change snapshot could not be serialised: #e.message#" );

			return "{}";
		}
	}

}
