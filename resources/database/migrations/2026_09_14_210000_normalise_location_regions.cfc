/**
 * Fill missing location regions and use the area names shown on Service Locations.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			UPDATE `locations`
			SET `region` = 'NSW Central Coast'
			WHERE `name` IN ( 'Avoca', 'Avoca Beach', 'Erina', 'Gosford', 'North Avoca', 'Terrigal', 'Ettalong Beach' )
			  AND ( `region` IS NULL OR `region` = '' OR `region` = 'Central Coast NSW' )
			",
			{},
			options
		);

		queryExecute(
			"
			UPDATE `locations`
			SET `region` = 'Parramatta & Sydney West'
			WHERE `name` IN ( 'Parramatta', 'Newington', 'Guildford', 'Merrylands', 'Wentworthville', 'Westmead' )
			  AND ( `region` IS NULL OR `region` = '' OR `region` = 'Parramatta & Sydney West' )
			",
			{},
			options
		);

		queryExecute(
			"UPDATE `locations` SET `region` = 'NSW Central Coast' WHERE `region` = 'Central Coast NSW'",
			{},
			options
		);

		queryExecute(
			"UPDATE `locations` SET `region` = 'Central West NSW' WHERE `region` = 'Central West'",
			{},
			options
		);

		queryExecute(
			"
			UPDATE `locations`
			SET `region` = 'Hawkesbury & Hills District'
			WHERE `region` IN ( 'Hawkesbury', 'Hills District' )
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"UPDATE `locations` SET `region` = 'Central Coast NSW' WHERE `region` = 'NSW Central Coast'",
			{},
			options
		);
		queryExecute(
			"UPDATE `locations` SET `region` = 'Central West' WHERE `region` = 'Central West NSW'",
			{},
			options
		);
		queryExecute(
			"UPDATE `locations` SET `region` = 'Hawkesbury' WHERE `region` = 'Hawkesbury & Hills District' AND `name` = 'Richmond'",
			{},
			options
		);
		queryExecute(
			"UPDATE `locations` SET `region` = 'Hills District' WHERE `region` = 'Hawkesbury & Hills District' AND `name` = 'Castle Hill'",
			{},
			options
		);
	}

}
