/**
 * `[form slug="..."]` — a built form embedded in a page, and the round trip
 * after somebody answers it.
 *
 * The shortcode is the *only* way a form is published: this module claims no
 * URLs. So these specs cover the whole public surface — what renders, what a
 * POST on somebody else's page is allowed to claim, and where the visitor ends
 * up either way.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-fsc-";

	function beforeAll(){
		super.beforeAll();
		variables.forms    = getInstance( "FormService@forms" );
		variables.sites    = getInstance( "SiteService@core" );
		variables.pages    = getInstance( "PageService@pages" );
		variables.themes   = getInstance( "ThemeService@core" );
		variables.resolver = getInstance( "FormContentResolver@forms" );
		cleanup();
		seed();
	}

	function afterAll(){
		getInstance( "AuthenticationService@core" ).logout();
		cleanup();
		super.afterAll();
	}

	function run(){
		describe( "The [form] shortcode", function(){

			beforeEach( function(){
				setup();
				forms.updateForm( formId = booking.getId(), isActive = true, thankYouPath = "" );
			} );

			describe( "rendering", function(){

				it( "renders every field the author defined", function(){
					var html = render( "register" );

					expect( html ).toInclude( 'name="your_name"' );
					expect( html ).toInclude( 'name="email"' );
					expect( html ).toInclude( 'name="preferred_time"' );
				} );

				it( "renders a choice field's options rather than a text box", function(){
					var html = render( "register" );

					expect( html ).toInclude( "Morning" );
					expect( html ).toInclude( "Afternoon" );
					expect( html ).toInclude( '<select' );
				} );

				it( "posts back to the page it sits on", function(){
					expect( render( "register" ) ).toInclude( 'action="/register"' );
				} );

				it( "carries a marker distinct from the contact form's", function(){
					var html = render( "register" );

					expect( html ).toInclude( 'name="cmsForm"' );
				} );

				it( "uses the author's button text", function(){
					expect( render( "register" ) ).toInclude( "Request a place" );
				} );

				/**
				 * A form switched off should vanish, not render and then refuse
				 * whatever is sent to it.
				 */
				it( "renders nothing for a form that is switched off", function(){
					forms.updateForm( formId = booking.getId(), isActive = false );

					expect( render( "register" ) ).notToInclude( 'name="your_name"' );
				} );

				it( "renders nothing when the shortcode names no form", function(){
					expect( render( "missing" ) ).notToInclude( 'name="cmsForm"' );
				} );

			} );

			describe( "what a POST may claim", function(){

				/**
				 * The page belongs to Pages. This module may only claim a POST
				 * that names one of its own active forms — anything else has to
				 * fall through, or every form on the site would swallow every
				 * submission on every page.
				 */
				it( "ignores a post with no marker", function(){
					expect( isNull( submit( "register", { name : "Ada" } ) ) ).toBeTrue();
				} );

				it( "ignores a marker naming no form of this site", function(){
					expect( isNull( submit( "register", { cmsForm : "zzt-not-ours" } ) ) ).toBeTrue();
				} );

				it( "ignores a marker naming another site's form", function(){
					expect( isNull( submit( "register", { cmsForm : "zzt-elsewhere" } ) ) ).toBeTrue();
				} );

				it( "ignores a marker naming a switched-off form", function(){
					forms.updateForm( formId = booking.getId(), isActive = false );

					expect( isNull( submit( "register", { cmsForm : booking.getSlug() } ) ) ).toBeTrue();
				} );

			} );

			describe( "after a successful response", function(){

				it( "sends the visitor back to the page", function(){
					expect( submit( "register", valid() ).redirectTo ).toBe( "/register" );
				} );

				it( "shows the success message in place of the form", function(){
					submit( "register", valid() );

					var html = embed( "register", booking.getSlug() );

					expect( html ).toInclude( "Thanks, we have your request." );
					expect( html ).notToInclude( 'name="your_name"' );
				} );

				it( "shows it once and then goes back to the form", function(){
					submit( "register", valid() );

					expect( embed( "register", booking.getSlug() ) ).toInclude( "Thanks, we have your request." );
					expect( embed( "register", booking.getSlug() ) ).toInclude( 'name="your_name"' );
				} );

				it( "redirects to a thank-you page when the form has one", function(){
					forms.updateForm( formId = booking.getId(), thankYouPath = "/thanks" );

					expect( submit( "register", valid() ).redirectTo ).toBe( "/thanks" );
				} );

			} );

			describe( "after a refused response", function(){

				it( "redirects rather than re-rendering, so it cannot be re-posted", function(){
					expect( submit( "register", { cmsForm : booking.getSlug(), csrfToken : "wrong" } ).redirectTo )
						.toBe( "/register" );
				} );

				it( "brings the error back with what was typed", function(){
					submit( "register", valid( { your_name : "Ada", email : "not-an-address" } ) );

					var html = embed( "register", booking.getSlug() );

					expect( html ).toInclude( "Ada" );
					expect( html ).toInclude( 'name="your_name"' );
				} );

				it( "does not carry the token or the captcha response back", function(){
					submit( "register", valid( {
						email                  : "not-an-address",
						"g-recaptcha-response" : "zzt-captcha-value"
					} ) );

					expect( embed( "register", booking.getSlug() ) ).notToInclude( "zzt-captcha-value" );
				} );

			} );

			describe( "the honeypot", function(){

				/**
				 * Answered exactly as a success would be, so a bot learns
				 * nothing about why it failed — and nothing is stored.
				 */
				it( "answers a filled honeypot as though it succeeded, and stores nothing", function(){
					var before = forms.countSubmissions( site.getId() );
					var out    = submit( "register", valid( { website : "http://spam.example" } ) );

					expect( out.redirectTo ).toBe( "/register" );
					expect( forms.countSubmissions( site.getId() ) ).toBe( before );
				} );

			} );

		} );
	}

	/* --------------------------------------------------------------------- */

	private struct function valid( struct values = {} ){
		var posted = {
			cmsForm        : booking.getSlug(),
			csrfToken      : getInstance( "CsrfService@core" ).getCurrentToken(),
			your_name      : "Ada Lovelace",
			email          : "ada@example.com",
			preferred_time : "Morning"
		};

		structAppend( posted, arguments.values, true );

		return posted;
	}

	private function submit( required string path, required struct formData ){
		setup();

		return resolver.handleSubmission( site.getId(), arguments.path, arguments.formData );
	}

	/**
	 * The shortcode on its own, for specs that follow a submission within one
	 * request — flash does not cross a request in the harness, because
	 * `MockController.relocate()` never calls `saveFlash()`.
	 */
	private string function embed( required string path, required string slug ){
		return getInstance( "FormShortcode@forms" ).render(
			attributes = { slug : arguments.slug },
			context    = { siteId : site.getId(), path : arguments.path }
		);
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
		variables.site  = sites.createSite( name = "Shortcode Forms", slug = PREFIX & "one" );
		variables.other = sites.createSite( name = "Elsewhere",       slug = PREFIX & "two" );

		sites.addDomain( site.getId(), "#PREFIX#one.test", true );
		themes.setThemeForSite( site.getId(), "default" );

		variables.booking = forms.createForm(
			siteId         = site.getId(),
			name           = "Registration",
			slug           = "zzt-registration",
			submitLabel    = "Request a place",
			successMessage = "Thanks, we have your request.",
			recipientEmail = "bookings@example.com"
		);

		forms.addField( formId = booking.getId(), fieldType = "text",  label = "Your name", isRequired = true );
		forms.addField( formId = booking.getId(), fieldType = "email", label = "Email", isRequired = true );
		forms.addField( formId = booking.getId(), fieldType = "select", label = "Preferred time",
		                optionsText = "Morning#chr(10)#Afternoon" );

		variables.booking = forms.withFields( booking );

		// Another site's form, so the tenant boundary is exercised.
		forms.createForm( siteId = other.getId(), name = "Elsewhere", slug = "zzt-elsewhere" );

		page( "register", '<p>Join us.</p>[form slug="zzt-registration"]' );
		page( "missing",  '[form slug="zzt-no-such-form"]' );
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
