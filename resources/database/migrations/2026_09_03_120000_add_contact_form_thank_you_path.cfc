/**
 * An optional landing page for a submitted contact form.
 *
 * Contact forms can now be embedded on any page with the `[contact-form]`
 * shortcode, which raises a question the single `/contact` URL never had to
 * answer: where does a visitor end up after sending?
 *
 * The default answer is "nowhere" — the success message replaces the form where
 * it stood, which is what an embedded form on a services page should do.
 *
 * This column is for the case where that is not enough. Advertising conversion
 * tracking is almost always wired to a *page load*: Google Ads and GA4 fire on
 * a specific URL being reached, and a message swapped in by the server produces
 * no such URL. A firm paying for clicks needs the redirect; a firm that is not
 * should not be made to configure one.
 *
 * NULL and empty both mean "stay on the page". Every existing form has neither,
 * so nothing changes until somebody fills it in.
 *
 * Site-relative paths only, enforced in `ContactService` — an open redirect on
 * a public form is how a phishing page borrows a law firm's domain for
 * legitimacy.
 */
component {

	function up( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute(
			"
			ALTER TABLE `contact_forms`
				ADD COLUMN `thank_you_path` VARCHAR(500) NULL AFTER `success_message`
			",
			{},
			options
		);
	}

	function down( schema, qb ){
		var options = arguments.schema.getDefaultOptions();

		queryExecute( "ALTER TABLE `contact_forms` DROP COLUMN `thank_you_path`", {}, options );
	}

}
