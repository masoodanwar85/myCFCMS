/**
 * The Contact module, and the public submission path Core grew for it.
 *
 * This is the first write path in the CMS reachable without signing in, so the
 * specs that matter most are the refusals: a missing token, a tripped honeypot,
 * a flood from one address. Each has to fail in a way that stores nothing and
 * tells an attacker as little as possible.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-ct-";

	function beforeAll(){
		super.beforeAll();
		variables.sites   = getInstance( "SiteService@core" );
		variables.contact = getInstance( "ContactService@contact" );
		variables.csrf    = getInstance( "CsrfService@core" );
		cleanup();
		seed();
	}

	function afterAll(){
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "Contact", function(){

			beforeEach( function( currentSpec ){
				setup();
			} );

			describe( "forms", function(){

				it( "creates a form scoped to its site", function(){
					expect( variables.form.getSiteId() ).toBe( siteOne.getId() );
					expect( variables.form.getSlug() ).toBe( "contact-us" );
				} );

				it( "refuses a duplicate slug on one site", function(){
					expect( function(){
						contact.createForm( siteId = siteOne.getId(), name = "Contact us" );
					} ).toThrow( type = "Contact.FormSlugExists" );
				} );

				it( "allows the same slug on another site", function(){
					var other = contact.createForm( siteId = siteTwo.getId(), name = "Contact us" );

					expect( other.getSlug() ).toBe( "contact-us" );

					contact.deleteForm( other.getId() );
				} );

				it( "rejects an unusable recipient address", function(){
					expect( function(){
						contact.createForm(
							siteId         = siteOne.getId(),
							name           = "Bad recipient",
							recipientEmail = "not-an-address"
						);
					} ).toThrow( type = "Contact.InvalidForm" );
				} );

				it( "serves the site's first active form as the default", function(){
					expect( contact.getDefaultForm( siteOne.getId() ).getId() ).toBe( variables.form.getId() );
				} );

				it( "returns null when a site has no active form", function(){
					// A ternary cannot return null on ColdFusion, which is why
					// this is worth asserting rather than assuming.
					expect( isNull( contact.getDefaultForm( siteThree.getId() ) ) ).toBeTrue();
				} );

			} );

			describe( "validating a submission", function(){

				it( "requires a name, an email and a message", function(){
					var errors = contact.validateSubmission( {} );

					expect( errors.len() ).toBe( 3 );
				} );

				it( "rejects a malformed email", function(){
					expect( contact.validateSubmission( {
						name : "Jo", email : "nope", message : "hi"
					} ).len() ).toBe( 1 );
				} );

				it( "accepts a complete submission", function(){
					expect( contact.validateSubmission( {
						name : "Jo", email : "jo@example.com", message : "Hello there."
					} ) ).toBeEmpty();
				} );

				it( "refuses an over-long message rather than truncating silently", function(){
					expect( contact.validateSubmission( {
						name : "Jo", email : "jo@example.com", message : repeatString( "x", 10001 )
					} ).len() ).toBe( 1 );
				} );

			} );

			describe( "storing a submission", function(){

				it( "records what was sent", function(){
					var sent = contact.submit(
						form   = variables.form,
						values = { name : "Jo Bloggs", email : "JO@Example.com", subject : "Hi", message : "A message." },
						ipAddress = "203.0.113.10"
					);

					expect( sent.getId() ).toBeGT( 0 );
					expect( sent.getEmail() ).toBe( "jo@example.com" );
					expect( sent.isNew() ).toBeTrue();

					contact.deleteSubmission( sent.getId() );
				} );

				it( "refuses a form that is not accepting messages", function(){
					contact.updateForm( formId = variables.form.getId(), isActive = false );

					try {
						expect( function(){
							contact.submit(
								form   = contact.getFormById( variables.form.getId() ),
								values = { name : "Jo", email : "jo@example.com", message : "hi" }
							);
						} ).toThrow( type = "Contact.FormInactive" );
					} finally {
						contact.updateForm( formId = variables.form.getId(), isActive = true );
					}
				} );

				it( "throttles a flood from one address", function(){
					var address = "198.51.100." & randRange( 2, 250 );
					var stored  = [];

					for ( var i = 1; i <= 5; i++ ) {
						stored.append( contact.submit(
							form      = variables.form,
							values    = { name : "Flood", email : "f@example.com", message : "m#i#" },
							ipAddress = address
						) );
					}

					expect( function(){
						contact.submit(
							form      = variables.form,
							values    = { name : "Flood", email : "f@example.com", message : "one too many" },
							ipAddress = address
						);
					} ).toThrow( type = "Contact.TooManySubmissions" );

					for ( var s in stored ) {
						contact.deleteSubmission( s.getId() );
					}
				} );

				it( "cannot be attached to another site's form", function(){
					var repo  = getInstance( "ContactRepository@contact" );
					var alien = getInstance( "Submission@contact" )
						.setSiteId( siteTwo.getId() )
						.setFormId( variables.form.getId() )
						.setName( "Eve" )
						.setEmail( "eve@example.com" )
						.setMessage( "wrong site" );

					expect( function(){
						repo.createSubmission( alien );
					} ).toThrow( type = "Contact.CrossTenantForm" );
				} );

			} );

			describe( "triage", function(){

				it( "moves a submission between statuses", function(){
					var sent = contact.submit(
						form   = variables.form,
						values = { name : "Jo", email : "jo@example.com", message : "triage me" }
					);

					contact.setStatus( sent.getId(), "spam" );
					expect( contact.getSubmissionById( sent.getId() ).isSpam() ).toBeTrue();

					contact.setStatus( sent.getId(), "read" );
					expect( contact.getSubmissionById( sent.getId() ).getStatus() ).toBe( "read" );

					contact.deleteSubmission( sent.getId() );
				} );

				it( "refuses an unknown status", function(){
					expect( function(){
						contact.setStatus( 1, "archived" );
					} ).toThrow( type = "Contact.InvalidStatus" );
				} );

				it( "lists only this site's submissions", function(){
					var sent = contact.submit(
						form   = variables.form,
						values = { name : "Jo", email : "jo@example.com", message : "mine" }
					);

					expect( contact.getSubmissions( siteOne.getId() ).len() ).toBeGT( 0 );
					expect( contact.getSubmissions( siteTwo.getId() ) ).toBeEmpty();

					contact.deleteSubmission( sent.getId() );
				} );

			} );

			describe( "the public form", function(){

				it( "is served at the base path", function(){
					var html = render( "/contact" );

					expect( html ).toInclude( "Contact us" );
					expect( html ).toInclude( "csrfToken" );
					expect( html ).toInclude( 'name="website"' );
				} );

				it( "is not served by a site with no form", function(){
					expect( render( "/contact", "#PREFIX#three.test" ) ).toInclude( "Page not found" );
				} );

				it( "appears in the site's navigation", function(){
					expect( render( "/contact" ) ).toInclude( ">Contact us<" );
				} );

				it( "shows a thank-you page after a successful send", function(){
					expect( render( "/contact/thank-you" ) ).toInclude( "Thank you" );
				} );

			} );

			describe( "posting the form", function(){

				it( "stores a valid submission and redirects", function(){
					var before = contact.getSubmissions( siteOne.getId() ).len();

					var event = post( {
						csrfToken : csrf.getCurrentToken(),
						form      : "contact-us",
						name      : "Posted Person",
						email     : "posted@example.com",
						message   : "Sent through the form."
					} );

					expect( event.getValue( "relocate_URI", "" ) ).toInclude( "thank-you" );
					expect( contact.getSubmissions( siteOne.getId() ).len() ).toBe( before + 1 );
				} );

				it( "refuses a post with no token and stores nothing", function(){
					var before = contact.getSubmissions( siteOne.getId() ).len();

					var html = renderPost( {
						form : "contact-us", name : "No Token", email : "nt@example.com", message : "hi"
					} );

					expect( html ).toInclude( "expired" );
					expect( contact.getSubmissions( siteOne.getId() ).len() ).toBe( before );
				} );

				it( "redisplays the form with what was typed when it is invalid", function(){
					var html = renderPost( {
						csrfToken : csrf.getCurrentToken(),
						form      : "contact-us",
						name      : "Keep Me",
						email     : "not-an-email",
						message   : "hi"
					} );

					expect( html ).toInclude( "does not look right" );
					// The visitor should not have to retype what was fine.
					expect( html ).toInclude( "Keep Me" );
				} );

				it( "silently drops a submission that trips the honeypot", function(){
					var before = contact.getSubmissions( siteOne.getId() ).len();

					var event = post( {
						csrfToken : csrf.getCurrentToken(),
						form      : "contact-us",
						name      : "Bot",
						email     : "bot@example.com",
						message   : "spam",
						website   : "http://spam.example"
					} );

					// Answers exactly like a success, so a bot learns nothing.
					expect( event.getValue( "relocate_URI", "" ) ).toInclude( "thank-you" );
					expect( contact.getSubmissions( siteOne.getId() ).len() ).toBe( before );
				} );

			} );

			describe( "the module seams", function(){

				it( "registers a resolver ahead of Pages", function(){
					var registered = getInstance( "ContentResolverRegistry@core" ).getRegistered();

					expect( registered ).toInclude( "ContactContentResolver@contact" );
					expect( registered.find( "ContactContentResolver@contact" ) )
						.toBeLT( registered.find( "PageContentResolver@pages" ) );
				} );

				it( "registers its own admin and site navigation", function(){
					expect(
						getInstance( "AdminNavigationRegistry@core" ).getSections().map( ( s ) => s.href )
					).toInclude( "/admin/contact" );

					expect(
						getInstance( "SiteNavigationRegistry@core" ).getRegistered()
					).toInclude( "ContactNavigationProvider@contact" );
				} );

				it( "registers its permissions into Core's catalogue", function(){
					var slugs = getInstance( "RoleService@core" ).getAllPermissions().map( ( p ) => p.getSlug() );

					expect( slugs ).toInclude( "contact.view" );
					expect( slugs ).toInclude( "contact.manage" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private function post( required struct values ){
		setup();

		return this.request(
			route   = "/contact",
			params  = arguments.values,
			headers = { "Host" : "#PREFIX#one.test" },
			method  = "POST"
		);
	}

	private string function renderPost( required struct values ){
		var event = post( arguments.values );

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private string function render( required string uri, string host = "" ){
		setup();

		var event = this.get(
			route   = arguments.uri,
			headers = { "Host" : len( arguments.host ) ? arguments.host : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.siteOne = sites.createSite( name = "Contact One", slug = PREFIX & "one" );
		sites.addDomain( siteOne.getId(), "#PREFIX#one.test" );

		variables.siteTwo = sites.createSite( name = "Contact Two", slug = PREFIX & "two" );
		sites.addDomain( siteTwo.getId(), "#PREFIX#two.test" );

		// Deliberately given no form, to prove /contact is simply not served.
		variables.siteThree = sites.createSite( name = "Contact Three", slug = PREFIX & "three" );
		sites.addDomain( siteThree.getId(), "#PREFIX#three.test" );

		variables.form = contact.createForm(
			siteId         = siteOne.getId(),
			name           = "Contact us",
			recipientEmail = "hello@example.com"
		);
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
