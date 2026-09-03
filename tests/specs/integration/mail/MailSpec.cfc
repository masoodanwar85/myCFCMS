/**
 * The mail layer.
 *
 * The thing that must never happen is a message disappearing without trace, so
 * most of these specs are about the record rather than the delivery.
 *
 * Requires migrations to have run: `box migrate up`.
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/app" {

	variables.PREFIX = "zzt-ml-";

	function beforeAll(){
		super.beforeAll();
		variables.mail     = getInstance( "MailService@core" );
		variables.sites    = getInstance( "SiteService@core" );
		variables.settings = getInstance( "coldbox:moduleSettings:core" );
		cleanup();
		variables.site = sites.createSite( name = "Mail One", slug = PREFIX & "one" );

		// Whatever this deployment is configured with, restored in afterAll.
		//
		// These specs used to read the live setting, so they passed only while
		// the application happened to have mail switched off — and started
		// failing the day somebody configured it, reporting a fault in the mail
		// layer when the only thing that had changed was a config file. A spec
		// about "what happens when sending is off" has to make that true itself.
		variables.configuredMode = settings.mailMode ?: "off";
	}

	function afterAll(){
		settings.mailMode = configuredMode;
		cleanup();
		super.afterAll();
	}

	/**
	 * Set the mode and hand back the service, so a spec reads as one sentence.
	 */
	private function withMode( required string mode ){
		settings.mailMode = arguments.mode;

		return mail;
	}

	function run(){
		describe( "MailService", function(){

			describe( "recording", function(){

				beforeEach( function(){
					withMode( "off" );
				} );

				it( "records a message even when sending is off", function(){
					var result = mail.send(
						to      = "someone@example.com",
						subject = "Recorded",
						body    = "<p>Hello</p>",
						siteId  = site.getId()
					);

					expect( result.id ).toBeGT( 0 );
					expect( result.status ).toBe( "suppressed" );

					var stored = mail.getMessageById( result.id );

					expect( stored.to_address ).toBe( "someone@example.com" );
					expect( stored.subject ).toBe( "Recorded" );
					expect( stored.body ).toInclude( "Hello" );
				} );

				it( "says why it was not sent", function(){
					var result = mail.send( to = "a@example.com", subject = "Why", body = "x", siteId = site.getId() );

					expect( mail.getMessageById( result.id ).error ).toInclude( "switched off" );
				} );

				it( "lower-cases the recipient", function(){
					var result = mail.send( to = "  MiXeD@Example.COM ", subject = "Case", body = "x", siteId = site.getId() );

					expect( mail.getMessageById( result.id ).to_address ).toBe( "mixed@example.com" );
				} );

				it( "uses the configured sender when none is given", function(){
					var result = mail.send( to = "a@example.com", subject = "From", body = "x", siteId = site.getId() );

					expect( mail.getMessageById( result.id ).from_address ).toBe( mail.defaultFrom() );
				} );

			} );

			describe( "refusing bad input", function(){

				it( "rejects an unusable address before recording anything", function(){
					var before = mail.countMessages( site.getId() );

					expect( function(){
						mail.send( to = "not-an-address", subject = "x", body = "y", siteId = site.getId() );
					} ).toThrow( type = "Mail.InvalidRecipient" );

					expect( mail.countMessages( site.getId() ) ).toBe( before );
				} );

			} );

			describe( "templates", function(){

				it( "renders a view as the body", function(){
					var result = mail.send(
						to       = "owner@example.com",
						subject  = "Templated",
						template = "emails/contactNotification",
						data     = {
							formName : "Contact us",
							name     : "Jo",
							email    : "jo@example.com",
							subject  : "Hi",
							message  : "Plain words"
						},
						siteId = site.getId()
					);

					var body = mail.getMessageById( result.id ).body;

					expect( body ).toInclude( "Contact us" );
					expect( body ).toInclude( "Plain words" );
				} );

				it( "escapes what a visitor wrote", function(){
					var result = mail.send(
						to       = "owner@example.com",
						subject  = "Escaping",
						template = "emails/contactNotification",
						data     = {
							formName : "Contact us",
							name     : "Jo",
							email    : "jo@example.com",
							subject  : "",
							message  : "<script>alert(1)</script>"
						},
						siteId = site.getId()
					);

					var body = mail.getMessageById( result.id ).body;

					expect( body ).notToInclude( "<script>alert" );
					expect( body ).toInclude( "&lt;script&gt;" );
				} );

			} );

			describe( "listing", function(){

				it( "scopes messages to a site", function(){
					var other = sites.createSite( name = "Mail Two", slug = PREFIX & "two" );

					mail.send( to = "a@example.com", subject = "Mine", body = "x", siteId = site.getId() );

					expect( mail.countMessages( site.getId() ) ).toBeGT( 0 );
					expect( mail.countMessages( other.getId() ) ).toBe( 0 );
				} );

				it( "goes with the site when the site is deleted", function(){
					var doomed = sites.createSite( name = "Doomed", slug = PREFIX & "doomed" );
					mail.send( to = "a@example.com", subject = "Bye", body = "x", siteId = doomed.getId() );

					queryExecute( "DELETE FROM sites WHERE id = :id", { id : doomed.getId() } );

					expect( mail.countMessages( doomed.getId() ) ).toBe( 0 );
				} );

			} );

			describe( "modes", function(){

				afterEach( function(){
					withMode( configuredMode );
				} );

				it( "reads the three modes it knows", function(){
					expect( withMode( "off" ).getMode() ).toBe( "off" );
					expect( withMode( "log" ).getMode() ).toBe( "log" );
					expect( withMode( "send" ).getMode() ).toBe( "send" );
				} );

				/**
				 * The property that matters: an unset or misspelt mode must not
				 * be read as permission to send.
				 */
				it( "falls back to off for anything it does not recognise", function(){
					expect( withMode( "" ).getMode() ).toBe( "off" );
					expect( withMode( "SEND-IT" ).getMode() ).toBe( "off" );
					expect( withMode( "off" ).isEnabled() ).toBeFalse();
					expect( withMode( "log" ).isEnabled() ).toBeFalse();
				} );

			} );

		} );
	}

	private function cleanup(){
		queryExecute( "DELETE FROM sites WHERE slug LIKE :p", { p : PREFIX & "%" } );
	}

}
