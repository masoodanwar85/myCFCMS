/**
 * The Media module's REST resource.
 *
 * Three actions: list the library, read one item, and upload. No `PATCH` and no
 * `DELETE`, deliberately — see the bottom of this comment.
 *
 * Upload is a **`multipart/form-data` POST**, with the file in a part named
 * `file`, because that is what `MediaService.upload()` takes: it hands the part
 * to `fileUpload()`, which lands it in staging before anything looks at it, and
 * every defence the service has — the extension allow-list, the per-kind size
 * cap, the magic-byte check, naming the file ourselves — is downstream of that.
 * A base64 field in a JSON body would have meant a second way into the library
 * with its own copy of those checks, which is the shape that eventually
 * disagrees with itself.
 *
 * ## The projection
 *
 * `MediaItem.getMemento()`, which is the explicit projection the editor's
 * library picker already reads — not the entity, so nothing a developer adds to
 * `MediaItem` next arrives in the public API by accident. It carries the field
 * that actually matters, `url`, which is what goes into a page's
 * `featuredImage`, `ogImage` or `<img src>`; and one projection for both
 * readers means the picker and the API cannot drift.
 *
 * ## What is not here
 *
 * **`PATCH`** for alt text and title. `MediaService.updateDetails()` exists and
 * the admin screen uses it, but editing a file's details needs `media.update`,
 * which the `agent` role does not carry — an automated client may label what it
 * uploads (both fields are accepted on create) and may not relabel somebody
 * else's files. Exposing it would be surface the only client we have cannot
 * reach.
 *
 * **`DELETE`**. Nothing an automated client does should be unrecoverable, and
 * `media.delete` is withheld from the agent role for that reason. An endpoint
 * no token can use is not a safeguard, it is a loose end.
 */
component extends="core.models.api.ApiHandler" {

	property name="mediaService" inject="MediaService@media";

	variables.permissions = {
		"index"  : "media.view",
		"show"   : "media.view",
		"create" : "media.upload",
		"$every" : "media.view"
	};

	/**
	 * Why an upload refusal is not left to `failFromException`.
	 *
	 * Core maps exception types onto status codes by the *shape* of the type
	 * name — `...NotFound` is a 404, `...Invalid...` a 422 — and none of these
	 * four match any of those shapes, so every one of them would come back as a
	 * `500` with the message withheld. That is exactly wrong here: each is the
	 * client's fault, each has a status code that says so, and each message is
	 * already written to be read by whoever tried ("that file is not a readable
	 * image, whatever it is named").
	 */
	variables.REFUSALS = {
		"Media.NoFile"          : { "status" : 400, "code" : "no_file" },
		"Media.TypeNotAllowed"  : { "status" : 415, "code" : "unsupported_type" },
		"Media.TooLarge"        : { "status" : 413, "code" : "too_large" },
		"Media.ContentMismatch" : { "status" : 422, "code" : "content_mismatch" }
	};

	/**
	 * `GET /api/v1/media`
	 *
	 * Paged, unlike the page tree: a library grows without bound and has no
	 * hierarchy that reading it whole would preserve.
	 *
	 * `?kind=image` or `?kind=document` narrows it. A client inserting an
	 * `<img>` wants one and a client placing a download link wants the other,
	 * and neither is served by being handed the whole library.
	 */
	function index( event, rc, prc ){
		var siteId = prc.currentSite.getId();
		var kind   = lCase( trim( rc.kind ?: "" ) );
		var filter = len( kind );

		var total = filter
			? mediaService.countByKindForSite( siteId, kind )
			: mediaService.countForSite( siteId );

		// The library's own page size, so a client walking it sees the same
		// pages the admin screen does.
		var page = readPage( rc, total, 24 );

		var items = filter
			? mediaService.getByKindForSite( siteId, kind, page.perPage, page.offset )
			: mediaService.getForSite( siteId, page.perPage, page.offset );

		return respondPaged( event, items.map( ( item ) => item.getMemento() ), page );
	}

	/**
	 * `GET /api/v1/media/:id`
	 */
	function show( event, rc, prc ){
		var item = mediaService.getById( val( rc.id ?: 0 ) );

		// "Belongs to another site" answers exactly as "does not exist", so the
		// API cannot be used to discover which ids are in use elsewhere.
		if ( isNull( item ) || item.getSiteId() != prc.currentSite.getId() ) {
			return fail( event, 404, "not_found", "No media item with that id." );
		}

		return respond( event = event, data = item.getMemento() );
	}

	/**
	 * `POST /api/v1/media`
	 *
	 * `multipart/form-data`, with the file in the `file` part and optional
	 * `altText` and `title` fields beside it. Both are worth sending at upload
	 * time: alt text is the only thing that stops the SEO audit reporting the
	 * image, and there is no second call that can add it.
	 */
	function create( event, rc, prc ){
		try {
			var item = mediaService.upload(
				siteId     = prc.currentSite.getId(),
				fileField  = "file",
				altText    = rc.altText ?: "",
				title      = rc.title ?: "",
				uploadedBy = prc.currentUser.getId()
			);
		} catch ( any e ) {
			var type = e.type ?: "";

			if ( structKeyExists( variables.REFUSALS, type ) ) {
				var refusal = variables.REFUSALS[ type ];

				return fail( event, refusal.status, refusal.code, e.message );
			}

			return failFromException( event, e );
		}

		var stored = item.getMemento();

		// `upload` rather than `create`, because that is what it is: nothing
		// existed before, and the entry's value is the record that this file
		// arrived through the API at all.
		recordChange( prc, "upload", "media", item.getId(), {}, stored );

		event.setHTTPHeader( name = "Location", value = "/api/v1/media/" & item.getId() );

		return respond( event = event, data = stored, statusCode = 201 );
	}

}
