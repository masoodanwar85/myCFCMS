/**
 * What sort of thing an upload is: an `image` or a `document`.
 *
 * ## Why a column and not a `mime_type LIKE` clause
 *
 * The library already told an image from a document by asking whether
 * `mime_type` starts with `image/`. That works for exactly two kinds, because
 * "document" is expressed as *not an image* — and the moment a third kind
 * arrives (audio, video), every "document" query silently starts returning it.
 *
 * A column makes each query a positive statement about what it wants. Adding a
 * kind later is then a new value, not a rewrite of the clauses that already
 * exist.
 *
 * ## `kind` is for finding files; `mime_type` is still what guards them
 *
 * Worth being explicit, because a denormalised column that duplicates a
 * security decision is a liability. It does not duplicate one:
 *
 *   - `kind` decides what a **picker lists** and how a **cell is drawn** — a
 *     thumbnail or a filename with an extension badge.
 *   - `mime_type` decides what is **sent to the browser**, and `isImage()`
 *     remains what `Media.cfc` asks before serving a file inline rather than as
 *     a download.
 *
 * So a row whose `kind` somehow disagreed with its `mime_type` would be listed
 * in the wrong tab of the picker. It would not be served as the wrong type.
 *
 * ## The backfill
 *
 * Derived from `mime_type`, which is the same question the old code asked, so
 * every existing row keeps the classification it already had. Nothing to
 * review afterwards.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `media`
				ADD COLUMN `kind` VARCHAR(16) NOT NULL DEFAULT 'document' AFTER `mime_type`,
				ADD KEY `idx_media_site_kind_created` (`site_id`, `kind`, `created_at`)
			",
			{},
			options
		);

		// The same test the application used before this column existed, so no
		// row changes meaning on the way through.
		queryExecute(
			"UPDATE `media` SET `kind` = 'image' WHERE `mime_type` LIKE 'image/%'",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `media`
				DROP KEY `idx_media_site_kind_created`,
				DROP COLUMN `kind`
			",
			{},
			options
		);
	}

}
