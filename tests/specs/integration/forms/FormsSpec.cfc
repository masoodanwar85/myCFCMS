/**
 * The Forms module: building a form, and receiving what people send.
 *
 * Two things carry most of the weight here.
 *
 * **Validation is per-field and driven by data an author wrote.** A choice
 * field's options are in the page source, so a posted answer is whatever the
 * sender says it is — checking it against the offered options is the difference
 * between a form and an open write endpoint.
 *
 * **A response records what was asked, not a pointer to it.** Editing a form
 * afterwards must not rewrite what an old response says. That is the reason
 * answers carry their own label instead of a `field_id`, and it is easy to
 * regress by "tidying up" into a join.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-forms-";

	function beforeAll(){
		super.beforeAll();
		variables.forms  = getInstance( "FormService@forms" );
		variables.sites  = getInstance( "SiteService@core" );
		variables.types  = getInstance( "FieldTypes@forms" );
		cleanup();

		variables.site  = sites.createSite( name = "Forms Test", slug = PREFIX & "one" );
		variables.other = sites.createSite( name = "Other",      slug = PREFIX & "two" );
		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Forms", function(){

			beforeEach( function(){
				setup();
			} );

			describe( "building one", function(){

				it( "derives a shortcode name from the form's name", function(){
					expect( newForm( "Event Registration" ).getSlug() ).toBe( "event-registration" );
				} );

				it( "refuses two forms with the same shortcode name on one site", function(){
					newForm( "Duplicate Me", "zzt-dup" );

					expect( function(){
						forms.createForm( siteId = site.getId(), name = "Other", slug = "zzt-dup" );
					} ).toThrow( type = "Forms.SlugExists" );
				} );

				/**
				 * Unlike Contact, which is one form per site. Here plural is the
				 * point — the module exists because a site needs more than the
				 * enquiry form.
				 */
				it( "allows a site as many forms as it likes", function(){
					newForm( "First " & createUUID() );
					newForm( "Second " & createUUID() );

					expect( forms.getFormsForSite( site.getId() ).len() ).toBeGTE( 2 );
				} );

				it( "lets another site use the same shortcode name", function(){
					newForm( "Shared Name", "zzt-shared" );

					expect( function(){
						forms.createForm( siteId = other.getId(), name = "Shared Name", slug = "zzt-shared" );
					} ).notToThrow();
				} );

				it( "refuses an unusable recipient address", function(){
					expect( function(){
						forms.createForm( siteId = site.getId(), name = "Bad " & createUUID(), recipientEmail = "not-an-address" );
					} ).toThrow( type = "Forms.InvalidForm" );
				} );

			} );

			describe( "fields", function(){

				it( "turns a label into a field name", function(){
					var built = newForm( "Keys " & createUUID() );
					var field = forms.addField( formId = built.getId(), fieldType = "text", label = "Your Full Name" );

					expect( field.getFieldKey() ).toBe( "your_full_name" );
				} );

				it( "refuses a type it has no renderer for", function(){
					var built = newForm( "Types " & createUUID() );

					expect( function(){
						forms.addField( formId = built.getId(), fieldType = "signature", label = "Sign here" );
					} ).toThrow( type = "Forms.InvalidField" );
				} );

				/**
				 * A choice field with no choices is a control a visitor cannot
				 * answer — and a required one makes the form unsubmittable.
				 */
				it( "refuses a choice field with no choices", function(){
					var built = newForm( "Choices " & createUUID() );

					expect( function(){
						forms.addField( formId = built.getId(), fieldType = "select", label = "Pick one" );
					} ).toThrow( type = "Forms.InvalidField" );
				} );

				it( "keeps choices one per line, ignoring blanks", function(){
					var built = newForm( "Options " & createUUID() );
					var field = forms.addField(
						formId      = built.getId(),
						fieldType   = "radio",
						label       = "Preferred time",
						optionsText = "Morning#chr(10)##chr(10)#Afternoon#chr(10)#  Evening  "
					);

					expect( field.getOptions() ).toBe( [ "Morning", "Afternoon", "Evening" ] );
				} );

				it( "orders fields as they were added", function(){
					var built = newForm( "Order " & createUUID() );
					forms.addField( formId = built.getId(), fieldType = "text", label = "One" );
					forms.addField( formId = built.getId(), fieldType = "text", label = "Two" );

					var labels = forms.getFieldsForForm( built.getId() ).map( ( f ) => f.getLabel() );

					expect( labels ).toBe( [ "One", "Two" ] );
				} );

				/**
				 * The label is display; the key is where answers live. Renaming
				 * the label must not touch the key, or every response already
				 * given is filed under a name the form no longer has.
				 */
				it( "does not change a field's name when its label is renamed", function(){
					var built = newForm( "Rename " & createUUID() );
					var field = forms.addField( formId = built.getId(), fieldType = "text", label = "Phone" );

					forms.updateField( fieldId = field.getId(), label = "Best contact number" );

					expect( forms.getFieldById( field.getId() ).getFieldKey() ).toBe( "phone" );
				} );

			} );

			describe( "validating a response", function(){

				beforeEach( function(){
					variables.survey = newForm( "Survey " & createUUID() );
					forms.addField( formId = survey.getId(), fieldType = "text",  label = "Name", isRequired = true );
					forms.addField( formId = survey.getId(), fieldType = "email", label = "Email" );
					forms.addField( formId = survey.getId(), fieldType = "number", label = "Age" );
					forms.addField( formId = survey.getId(), fieldType = "select", label = "Service",
					                optionsText = "Wills#chr(10)#Probate" );
					variables.survey = forms.withFields( survey );
				} );

				it( "accepts a complete response", function(){
					expect( forms.validateSubmission( survey, {
						name : "Ada", email : "ada@example.com", age : "40", service : "Wills"
					} ) ).toBeEmpty();
				} );

				it( "asks for a required field that was left blank", function(){
					var errors = forms.validateSubmission( survey, { email : "ada@example.com" } );

					expect( arrayToList( errors ) ).toInclude( "Name" );
				} );

				it( "does not complain about an optional field left blank", function(){
					expect( forms.validateSubmission( survey, { name : "Ada" } ) ).toBeEmpty();
				} );

				it( "checks an email field looks like an address", function(){
					var errors = forms.validateSubmission( survey, { name : "Ada", email : "nope" } );

					expect( arrayToList( errors ) ).toInclude( "Email" );
				} );

				it( "checks a number field is a number", function(){
					var errors = forms.validateSubmission( survey, { name : "Ada", age : "forty" } );

					expect( arrayToList( errors ) ).toInclude( "Age" );
				} );

				/**
				 * The options live in the page source; a posted value is
				 * whatever the sender says. Without this a choice field accepts
				 * anything at all.
				 */
				it( "refuses an answer the form never offered", function(){
					var errors = forms.validateSubmission( survey, { name : "Ada", service : "Something else" } );

					expect( arrayToList( errors ) ).toInclude( "Service" );
				} );

			} );

			describe( "receiving a response", function(){

				beforeEach( function(){
					variables.booking = newForm( "Booking " & createUUID() );
					forms.addField( formId = booking.getId(), fieldType = "text",  label = "Name", isRequired = true );
					forms.addField( formId = booking.getId(), fieldType = "email", label = "Email" );
					forms.addField( formId = booking.getId(), fieldType = "checkbox", label = "Days",
					                optionsText = "Monday#chr(10)#Tuesday#chr(10)#Friday" );
					variables.booking = forms.withFields( booking );
				} );

				it( "stores the answers with the questions as they were asked", function(){
					var stored = forms.submit( form = booking, values = {
						name : "Ada", email : "ada@example.com", days : "Monday,Friday"
					} );

					var answers = forms.getSubmissionById( stored.getId() ).getAnswers();

					expect( answers.len() ).toBe( 3 );
					expect( answers[ 1 ].label ).toBe( "Name" );
					expect( answers[ 1 ].value ).toBe( "Ada" );
					expect( answers[ 3 ].value ).toBe( [ "Monday", "Friday" ] );
				} );

				/**
				 * The reason answers carry their label rather than a field id.
				 * Editing a form must not rewrite the history of what people
				 * were asked.
				 */
				it( "keeps an old response readable after the form is rewritten", function(){
					var stored = forms.submit( form = booking, values = { name : "Ada", email : "ada@example.com" } );

					var fields = forms.getFieldsForForm( booking.getId() );
					forms.updateField( fieldId = fields[ 1 ].getId(), label = "Full legal name" );
					forms.deleteField( fields[ 2 ].getId() );

					var answers = forms.getSubmissionById( stored.getId() ).getAnswers();

					expect( answers[ 1 ].label ).toBe( "Name" );
					expect( answers[ 2 ].label ).toBe( "Email" );
					expect( answers[ 2 ].value ).toBe( "ada@example.com" );
				} );

				it( "picks up the sender's address so a reply is possible", function(){
					var stored = forms.submit( form = booking, values = { name : "Ada", email : "Ada@Example.COM" } );

					expect( stored.getSenderEmail() ).toBe( "ada@example.com" );
				} );

				it( "summarises a response for the inbox without repeating the address", function(){
					var stored = forms.submit( form = booking, values = { name : "Ada", email : "ada@example.com" } );

					expect( stored.getSummary() ).toBe( "Ada" );
				} );

				it( "refuses a response to a form that is switched off", function(){
					forms.updateForm( formId = booking.getId(), isActive = false );

					expect( function(){
						forms.submit( form = forms.withFields( forms.getFormById( booking.getId() ) ),
						              values = { name : "Ada" } );
					} ).toThrow( type = "Forms.FormInactive" );

					forms.updateForm( formId = booking.getId(), isActive = true );
				} );

				it( "refuses an invalid response rather than storing it", function(){
					var before = forms.countSubmissions( site.getId() );

					expect( function(){
						forms.submit( form = booking, values = { email : "ada@example.com" } );
					} ).toThrow( type = "Forms.InvalidSubmission" );

					expect( forms.countSubmissions( site.getId() ) ).toBe( before );
				} );

				/**
				 * A form may deliberately keep nothing. It is still validated
				 * and still delivered — it simply leaves no row.
				 */
				it( "stores nothing when the form is set not to keep responses", function(){
					forms.updateForm( formId = booking.getId(), storeSubmissions = false );

					var before = forms.countSubmissions( site.getId() );

					forms.submit( form = forms.withFields( forms.getFormById( booking.getId() ) ),
					              values = { name : "Ada" } );

					expect( forms.countSubmissions( site.getId() ) ).toBe( before );

					forms.updateForm( formId = booking.getId(), storeSubmissions = true );
				} );

				it( "never lets markup in an answer reach the admin as markup", function(){
					var stored = forms.submit( form = booking, values = {
						name : "<script>alert(1)</script>Ada", email : "ada@example.com"
					} );

					expect( forms.getSubmissionById( stored.getId() ).getAnswers()[ 1 ].value )
						.notToInclude( "<script" );
				} );

			} );

			describe( "the thank-you path", function(){

				it( "keeps a site-relative path", function(){
					expect( forms.safeReturnPath( "/thanks" ) ).toBe( "/thanks" );
				} );

				it( "refuses anything that would leave the site", function(){
					expect( forms.safeReturnPath( "https://evil.example.com" ) ).toBe( "" );
					expect( forms.safeReturnPath( "//evil.example.com" ) ).toBe( "" );
				} );

			} );

			describe( "field types", function(){

				it( "offers no type the renderer and validator do not both know", function(){
					for ( var type in types.all() ) {
						expect( types.isValid( type.key ) ).toBeTrue( "type #type.key# is listed but not valid" );
						expect( len( types.inputTypeFor( type.key ) ) ).toBeGT( 0 );
					}
				} );

				it( "knows which types carry choices", function(){
					expect( types.hasOptions( "select" ) ).toBeTrue();
					expect( types.hasOptions( "text" ) ).toBeFalse();
				} );

				it( "knows which types hold more than one answer", function(){
					expect( types.isMultiValue( "checkbox" ) ).toBeTrue();
					expect( types.isMultiValue( "radio" ) ).toBeFalse();
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function newForm( required string name, string slug = "" ){
		return forms.createForm( siteId = site.getId(), name = arguments.name, slug = arguments.slug );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
