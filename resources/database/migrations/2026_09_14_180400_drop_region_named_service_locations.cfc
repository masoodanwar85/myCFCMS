/**
 * Drop region names that were seeded as towns (e.g. "Probate - Central Coast NSW"
 * when that region page has no suburb children).
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			DELETE sl FROM `services_locations` sl
			INNER JOIN `locations` l ON l.`id` = sl.`location_id`
			INNER JOIN `pages` locroot
				ON locroot.`site_id` = sl.`site_id`
			   AND locroot.`path` = 'locations'
			INNER JOIN `pages` region
				ON region.`parent_id` = locroot.`id`
			   AND region.`title` = l.`name`
			",
			{},
			options
		);

		queryExecute(
			"
			DELETE l FROM `locations` l
			LEFT JOIN `services_locations` sl ON sl.`location_id` = l.`id`
			INNER JOIN `pages` locroot
				ON locroot.`site_id` = l.`site_id`
			   AND locroot.`path` = 'locations'
			INNER JOIN `pages` region
				ON region.`parent_id` = locroot.`id`
			   AND region.`title` = l.`name`
			WHERE sl.`location_id` IS NULL
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		// One-way cleanup; re-seed by migrating 180300 down/up if needed.
	}

}
