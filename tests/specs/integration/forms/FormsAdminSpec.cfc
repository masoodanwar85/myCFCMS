/**
 * The Forms admin screens, through real routed requests.
 *
 * Four screens were written for this module and nothing else renders them, so
 * a template error would first appear in production. These also pin the tenant
 * boundary: every id in a URL is a guess anybody can make, and the check that
 * it belongs to the current site is the only thing between a guess and another
 * client's responses.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX   = "zzt-fadm-";
	variables.PASSWORD = "correct-horse-battery";

	function beforeAll(){
		super.beforeAll();
		variables.forms = getInstance( "FormService@forms" );
		variables.sites = getInstance( "SiteService@core" );
		variables.roles = getInstance( "RoleService@core" );
		variables.users = getInstance( "UserService@core" );
		variables.auth  = getInstance( "AuthenticationService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		auth.logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The Forms admin", function(){

			beforeEach( function(){
				setup();
				auth.logout();
				signIn( variables.owner );
			} );

			afterEach( function(){
				auth.logout();
			} );

			describe( "the forms list", function(){

				it( "renders, showing each form's shortcode", function(){
					var html = screen( "/admin/forms/forms" );

					expect( html ).toInclude( "Registration" );
					// The template writes the quotes literally, so they are not
					// entity-encoded — assert on the parts, not on a guess at
					// the exact escaping.
					expect( html ).toInclude( "[form slug=" );
					expect( html ).toInclude( "zzt-reg" );
				} );

				it( "shows how many responses a delete would take with it", function(){
					expect( screen( "/admin/forms/forms" ) ).toInclude( "Responses" );
				} );

				it( "points at Contact for the enquiry form, so the two are not confused", function(){
					expect( screen( "/admin/forms/forms" ) ).toInclude( "/admin/contact/forms" );
				} );

			} );

			describe( "the builder", function(){

				it( "renders the form's fields", function(){
					var html = screen( "/admin/forms/build/" & reg.getId() );

					expect( html ).toInclude( "Your name" );
					expect( html ).toInclude( "Preferred time" );
				} );

				it( "offers every field type", function(){
					var html = screen( "/admin/forms/build/" & reg.getId() );

					for ( var type in getInstance( "FieldTypes@forms" ).all() ) {
						expect( html ).toInclude( 'value="' & type.key & '"' );
					}
				} );

				/**
				 * The fields used to render as a stack of open editors, so a
				 * form with a dozen of them was twelve full forms down the
				 * page. They are a list now: one row per field, opening in
				 * place.
				 */
				it( "shows the fields as a list, not a stack of open forms", function(){
					var html = screen( "/admin/forms/build/" & reg.getId() );

					expect( html ).toInclude( "field-list" );
					expect( html ).toInclude( "<details class=""field-item""" );
				} );

				it( "says what each field is without opening it", function(){
					var html = screen( "/admin/forms/build/" & reg.getId() );

					// The key and the type badge, on the closed row.
					expect( html ).toInclude( "your_name" );
					expect( html ).toInclude( "Single line text" );
					expect( html ).toInclude( "Dropdown" );
				} );

				/**
				 * The add form offered type, label and name only, so a
				 * placeholder or a piece of help text could not be set until
				 * *after* the field existed — an author had to add a field and
				 * then reopen it to finish it.
				 */
				it( "offers the same inputs when adding a field as when editing one", function(){
					var html = screen( "/admin/forms/build/" & reg.getId() );

					for ( var input in [ "newPlaceholder", "newHelp", "newMax" ] ) {
						expect( html ).toInclude( 'id="' & input & '"' );
					}
				} );

				it( "shows a field's stored placeholder and help text back", function(){
					var fields = forms.getFieldsForForm( reg.getId() );

					forms.updateField(
						fieldId     = fields[ 1 ].getId(),
						placeholder = "As it appears on your passport",
						helpText    = "We use this on the certificate"
					);

					var html = screen( "/admin/forms/build/" & reg.getId() );

					// Compared through the same encoder the admin views use.
					// `encodeForHTMLAttribute` escapes every space as `&##x20;`,
					// so a raw substring search fails on correct output — the
					// value is there, and the browser decodes it.
					expect( html ).toInclude( encodeForHTMLAttribute( "As it appears on your passport" ) );
					expect( html ).toInclude( encodeForHTMLAttribute( "We use this on the certificate" ) );
				} );

				/**
				 * Choices only mean something for the types that have them, but
				 * the value must survive a round trip through a type that does
				 * not — otherwise switching a dropdown to text and back loses
				 * what the author typed.
				 */
				it( "keeps a field's choices when its type has none", function(){
					var fields = forms.getFieldsForForm( reg.getId() );
					var plain  = fields[ 1 ];

					var html = screen( "/admin/forms/build/" & reg.getId() );

					expect( html ).toInclude( 'name="optionsText"' );
				} );

				it( "says a field's name is fixed once it exists", function(){
					expect( screen( "/admin/forms/build/" & reg.getId() ) ).toInclude( "is fixed once it exists" );
				} );

				/**
				 * An id in a URL is a guess anybody can make. Without this
				 * check, guessing one reaches another client's form.
				 */
				it( "refuses a form belonging to another site", function(){
					var event = adminRequest( "/admin/forms/build/" & elsewhere.getId() );

					// Asserted on the other form's *field* label, which appears
					// only if the builder actually rendered that form. The form
					// name alone is too weak — it collides with other copy.
					expect( event.getRenderedContent() ).notToInclude( "Secret" );
				} );

			} );

			describe( "the responses inbox", function(){

				it( "renders, listing what was sent", function(){
					var html = screen( "/admin/forms" );

					expect( html ).toInclude( "Form responses" );
					expect( html ).toInclude( "Ada Lovelace" );
				} );

				it( "shows the sender's address when the form asked for one", function(){
					expect( screen( "/admin/forms" ) ).toInclude( "ada@example.com" );
				} );

				it( "opens one response and shows the questions as they were asked", function(){
					var html = screen( "/admin/forms/view/" & response.getId() );

					expect( html ).toInclude( "Your name" );
					expect( html ).toInclude( "Ada Lovelace" );
				} );

				/**
				 * Opening is what marks a response read; doing it on the list
				 * would mark everything read the moment somebody glanced.
				 */
				it( "marks a response read when it is opened", function(){
					var fresh = forms.submit( form = reg, values = {
						your_name : "Grace", email : "grace@example.com", preferred_time : "Morning"
					} );

					expect( forms.getSubmissionById( fresh.getId() ).getStatus() ).toBe( "new" );

					screen( "/admin/forms/view/" & fresh.getId() );

					expect( forms.getSubmissionById( fresh.getId() ).getStatus() ).toBe( "read" );
				} );

				it( "refuses a response belonging to another site", function(){
					var event = adminRequest( "/admin/forms/view/" & foreignResponse.getId() );

					expect( event.getRenderedContent() ).notToInclude( "Mallory" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	/**
	 * Named `adminRequest`, not `request`: `request` is a CFML scope, and a
	 * private method of that name is not callable at all — "the symbol you
	 * provided request is not the name of a function".
	 */
	private function adminRequest( required string uri ){
		setup();

		return this.get( route = arguments.uri, headers = { "Host" : "#PREFIX#one.test" } );
	}

	private string function screen( required string uri ){
		var event = adminRequest( arguments.uri );

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function signIn( required any user ){
		getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
		auth.startSessionFor( arguments.user, variables.site.getId() );

		return this;
	}

	private function seed(){
		variables.site  = sites.createSite( name = "Forms Admin", slug = PREFIX & "one" );
		variables.other = sites.createSite( name = "Other Admin", slug = PREFIX & "two" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );

		roles.seedDefaultRolesForSite( site.getId() );
		variables.owner = users.createUser( site.getId(), "Owner", "owner@fadm.test", PASSWORD );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

		variables.reg = forms.createForm(
			siteId         = site.getId(),
			name           = "Registration",
			slug           = "zzt-reg",
			recipientEmail = "bookings@example.com"
		);

		forms.addField( formId = reg.getId(), fieldType = "text",   label = "Your name", isRequired = true );
		forms.addField( formId = reg.getId(), fieldType = "email",  label = "Email" );
		forms.addField( formId = reg.getId(), fieldType = "select", label = "Preferred time",
		                optionsText = "Morning#chr(10)#Afternoon" );

		variables.reg = forms.withFields( reg );

		variables.response = forms.submit( form = reg, values = {
			your_name : "Ada Lovelace", email : "ada@example.com", preferred_time : "Morning"
		} );

		// Another site's form and response, so the boundary is exercised.
		variables.elsewhere = forms.createForm( siteId = other.getId(), name = "Elsewhere", slug = "zzt-elsewhere" );
		forms.addField( formId = elsewhere.getId(), fieldType = "text", label = "Secret" );
		variables.elsewhere = forms.withFields( elsewhere );

		variables.foreignResponse = forms.submit( form = elsewhere, values = { secret : "Mallory" } );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
