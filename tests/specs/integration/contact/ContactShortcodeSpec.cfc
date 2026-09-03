/**
 * `[contact-form]` — the site's enquiry form embedded in a page.
 *
 * The thank-you is the part worth pinning down. A form at `/contact` can answer
 * a refusal by re-rendering itself; an embedded one cannot, because the page
 * belongs to Pages. So embedded submissions always redirect and carry their
 * outcome in flash.
 *
 * A site has exactly one contact form, so the posted marker can only confirm or
 * deny that a POST belongs to this form — it can no longer *select* between
 * forms, which is what used to let an edited hidden field route a message to a
 * different recipient.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-csc-";

	function beforeAll(){
		super.beforeAll();
		variables.contact  = getInstance( "ContactService@contact" );
		variables.sites    = getInstance( "SiteService@core" );
		variables.pages    = getInstance( "PageService@pages" );
		variables.themes   = getInstance( "ThemeService@core" );
		variables.resolver = getInstance( "ContactContentResolver@contact" );
		cleanup();
		seed();
	}

	function afterAll(){
		getInstance( "AuthenticationService@core" ).logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The [contact-form] shortcode", function(){

			beforeEach( function(){
				setup();
				// Every spec starts from the form as seeded: active, no
				// thank-you page. Several change it, and a spec that inherited
				// another's changes would pass or fail for the wrong reason.
				contact.updateForm( formId = siteForm.getId(), isActive = true, thankYouPath = "" );
			} );

			describe( "rendering", function(){

				it( "puts the site's form into a page", function(){
					var html = render( "enquire" );

					expect( html ).toInclude( 'name="csrfToken"' );
					expect( html ).toInclude( 'name="message"' );
				} );

				it( "posts back to the page it sits on, not to /contact", function(){
					expect( render( "enquire" ) ).toInclude( 'action="/enquire"' );
				} );

				/**
				 * The page already has a heading. A second would give it two
				 * competing titles — the trap `show_heading` exists for.
				 */
				it( "drops the form's own heading when embedded", function(){
					expect( render( "enquire" ) ).notToInclude( "<h1>Contact Us</h1>" );
				} );

				it( "renders no form when the site's form is switched off", function(){
					contact.updateForm( formId = siteForm.getId(), isActive = false );

					expect( render( "enquire" ) ).notToInclude( 'name="csrfToken"' );
				} );

			} );

			/**
			 * The round trip, tested where this module's part of it lives:
			 * `handleSubmission` writes the outcome, the shortcode reads it and
			 * decides what to render.
			 *
			 * Not driven through two mock requests, because `MockController`'s
			 * `relocate()` records the URI and throws without calling
			 * `saveFlash()` — flash never crosses a request in the harness.
			 * That is a gap in the test double, not the application: the same
			 * round trip over HTTP with a cookie jar brings the outcome back.
			 */
			describe( "after a successful send", function(){

				it( "sends the visitor back to the page it was embedded in", function(){
					expect( submit( "enquire", validValues() ).redirectTo ).toBe( "/enquire" );
				} );

				it( "renders the success message in place of the form", function(){
					submit( "enquire", validValues() );

					var html = embed( "enquire" );

					expect( html ).toInclude( "Thank you. We will be in touch." );
					expect( html ).notToInclude( 'name="message"' );
				} );

				/**
				 * A success message that survived into the next page view would
				 * tell a visitor they had sent something they had not.
				 */
				it( "shows the message once and then goes back to the form", function(){
					submit( "enquire", validValues() );

					expect( embed( "enquire" ) ).toInclude( "Thank you. We will be in touch." );
					expect( embed( "enquire" ) ).toInclude( 'name="message"' );
				} );

				it( "redirects to a configured thank-you page instead, when there is one", function(){
					contact.updateForm( formId = siteForm.getId(), thankYouPath = "/thanks" );

					expect( submit( "enquire", validValues() ).redirectTo ).toBe( "/thanks" );
				} );

			} );

			describe( "after a refused send", function(){

				it( "redirects rather than re-rendering, so a refusal cannot be re-posted", function(){
					expect( submit( "enquire", { form : siteForm.getSlug(), csrfToken : "wrong" } ).redirectTo )
						.toBe( "/enquire" );
				} );

				it( "brings the error back to the page with what was typed", function(){
					submit( "enquire", validValues( { name : "Ada", email : "not-an-email" } ) );

					var html = embed( "enquire" );

					expect( html ).toInclude( "Ada" );
					expect( html ).toInclude( 'name="message"' );
					expect( html ).toInclude( "role=""alert""" );
				} );

				/**
				 * The CSRF token and the reCAPTCHA response have no business in
				 * the session or in the next page.
				 */
				it( "does not carry the token or the captcha response back", function(){
					submit( "enquire", validValues( {
						email                  : "not-an-email",
						"g-recaptcha-response" : "zzt-captcha-value"
					} ) );

					expect( embed( "enquire" ) ).notToInclude( "zzt-captcha-value" );
				} );

			} );

			describe( "the marker on an embedded post", function(){

				/**
				 * On a page Pages owns, the marker is the only thing saying the
				 * POST is ours. It can confirm or deny; with one form per site
				 * it can no longer select, which is what used to let an edited
				 * hidden field send a message to another recipient.
				 */
				it( "ignores a post whose marker is not this site's form", function(){
					expect( isNull( submit( "enquire", { form : "zzt-something-else" } ) ) ).toBeTrue();
				} );

				it( "ignores a post with no marker, leaving the page to its own module", function(){
					expect( isNull( submit( "enquire", {} ) ) ).toBeTrue();
				} );

				it( "still accepts a post on /contact itself, which this resolver owns", function(){
					expect( isNull( submit( "contact", validValues() ) ) ).toBeFalse();
				} );

			} );

			describe( "the thank-you path", function(){

				it( "keeps a site-relative path", function(){
					expect( contact.safeReturnPath( "/thank-you" ) ).toBe( "/thank-you" );
				} );

				/**
				 * An open redirect on a public form is how a phishing page
				 * borrows a client's domain: the victim sees the firm's address
				 * in the link they were sent and lands somewhere else.
				 */
				it( "refuses anything that would leave the site", function(){
					expect( contact.safeReturnPath( "https://evil.example.com" ) ).toBe( "" );
					expect( contact.safeReturnPath( "//evil.example.com" ) ).toBe( "" );
					expect( contact.safeReturnPath( "javascript:alert(1)" ) ).toBe( "" );
				} );

				it( "refuses a value carrying a newline, which could split the response", function(){
					expect( contact.safeReturnPath( "/ok#chr(13)##chr(10)#Set-Cookie: a=b" ) ).toBe( "" );
				} );

				it( "stores nothing rather than failing to save over a bad path", function(){
					contact.updateForm( formId = siteForm.getId(), thankYouPath = "https://evil.example.com" );

					expect( contact.getFormForSite( site.getId() ).getThankYouPath() ).toBe( "" );
				} );

			} );

			/**
			 * The screen was rewritten from a list of forms to one form plus
			 * whatever the multi-form era left behind, and nothing else renders
			 * it — a template error here would first appear in production.
			 */
			describe( "the admin screen", function(){

				beforeEach( function(){
					getInstance( "TenantContext@core" ).setCurrentTenant( variables.site );
					getInstance( "AuthenticationService@core" ).startSessionFor( variables.owner, site.getId() );
				} );

				afterEach( function(){
					getInstance( "AuthenticationService@core" ).logout();
				} );

				it( "shows the site's one form", function(){
					var html = adminScreen();

					expect( html ).toInclude( "Contact form" );
					expect( html ).toInclude( 'name="recipientEmail"' );
					expect( html ).toInclude( 'name="thankYouPath"' );
				} );

				it( "offers no way to add a second", function(){
					expect( adminScreen() ).notToInclude( "Add a form" );
				} );

				it( "tells an author how to embed it", function(){
					expect( adminScreen() ).toInclude( "[contact-form]" );
				} );

			} );

			describe( "one form per site", function(){

				it( "refuses a second contact form", function(){
					expect( function(){
						contact.createForm( siteId = site.getId(), name = "Another" );
					} ).toThrow( type = "Contact.FormAlreadyExists" );
				} );

				/**
				 * Which form a site served used to be decided by name, so
				 * renaming one could silently change what `/contact` showed.
				 */
				it( "picks the site's form by age, not alphabetically", function(){
					contact.updateForm( formId = siteForm.getId(), name = "Zzz Renamed" );

					expect( contact.getFormForSite( site.getId() ).getId() ).toBe( siteForm.getId() );

					contact.updateForm( formId = siteForm.getId(), name = "Contact Us" );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private struct function validValues( struct values = {} ){
		var posted = {
			form      : siteForm.getSlug(),
			csrfToken : getInstance( "CsrfService@core" ).getCurrentToken(),
			name      : "Ada Lovelace",
			email     : "ada@example.com",
			subject   : "Hello",
			message   : "I would like some advice about a will."
		};

		structAppend( posted, arguments.values, true );

		return posted;
	}

	private function submit( required string path, required struct formData ){
		setup();

		return resolver.handleSubmission( site.getId(), arguments.path, arguments.formData );
	}

	/**
	 * The shortcode on its own, for the specs that follow a submission within
	 * one request. `render()` drives the whole pipeline where the expansion
	 * itself is what is under test.
	 */
	private string function embed( required string path ){
		return getInstance( "ContactShortcode@contact" ).render(
			context = { siteId : site.getId(), path : arguments.path }
		);
	}

	private string function adminScreen(){
		setup();

		var event = this.get(
			route   = "/admin/contact/forms",
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private string function render( required string slug ){
		setup();

		var event = this.get(
			route   = "/" & arguments.slug,
			headers = { "Host" : "#PREFIX#one.test" }
		);

		return event.getRenderedContent() & ( event.getHandlerResults() ?: "" );
	}

	private function seed(){
		variables.site  = sites.createSite( name = "Shortcode Test", slug = PREFIX & "one" );
		variables.other = sites.createSite( name = "Other Site",     slug = PREFIX & "two" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		themes.setThemeForSite( site.getId(), "default" );

		variables.siteForm = contact.createForm(
			siteId         = site.getId(),
			name           = "Contact Us",
			slug           = "zzt-contact-us",
			recipientEmail = "enquiries@example.com"
		);

		// Another site's form, so the tenant boundary is exercised rather than
		// assumed.
		contact.createForm( siteId = other.getId(), name = "Other", slug = "zzt-something-else" );

		page( "enquire", "<p>Ask us anything.</p>[contact-form]" );

		var roles = getInstance( "RoleService@core" );
		var users = getInstance( "UserService@core" );

		roles.seedDefaultRolesForSite( site.getId() );
		variables.owner = users.createUser( site.getId(), "Owner", "owner@csc.test", "correct-horse-battery" );
		users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );
	}

	private function page( required string slug, required string content ){
		var made = pages.createPage(
			siteId  = site.getId(),
			title   = arguments.slug,
			slug    = arguments.slug,
			content = arguments.content,
			status  = "published"
		);

		pages.publishPage( made.getId() );

		return made;
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
