<cfsetting showdebugoutput="false" requesttimeout="300">
<cfcontent type="text/plain">
<cfscript>
/**
 * Demo content for browsing the CMS locally.
 *
 * Runs through the real services rather than raw inserts, so everything it
 * creates obeys the same validation, slug derivation, path building and HTML
 * sanitising as content created through the admin. Raw SQL would let this file
 * quietly seed data the application itself would refuse.
 *
 * Idempotent: it removes anything it created previously (slug prefix `demo-`)
 * before seeding again.
 *
 * Not in the webroot on purpose. To run it, copy it into `public/` temporarily:
 *
 *     cp resources/database/seeds/DemoContent.cfm public/__seed.cfm
 *     curl "http://127.0.0.1:<port>/__seed.cfm"
 *     rm public/__seed.cfm
 */
wb       = application.wirebox;
sites    = wb.getInstance( "SiteService@core" );
roles    = wb.getInstance( "RoleService@core" );
users    = wb.getInstance( "UserService@core" );
pages    = wb.getInstance( "PageService@pages" );
blog     = wb.getInstance( "BlogService@blog" );
themes   = wb.getInstance( "ThemeService@core" );
settings = wb.getInstance( "SiteSettingsRepository@core" );

PASSWORD = "demo-password-123";

// ---------------------------------------------------------------- clean slate
queryExecute( "DELETE FROM sites WHERE slug LIKE 'demo-%'", {}, { datasource : "myCFCMS" } );
queryExecute(
	"DELETE FROM users WHERE site_id IS NULL AND email LIKE 'root@platform.test'",
	{},
	{ datasource : "myCFCMS" }
);

out = [];
function say( required string line ){
	out.append( arguments.line );
}

// ================================================================== SITE ONE
say( "=== Northwind Studio ===" );

one = sites.createSite(
	name     = "Northwind Studio",
	slug     = "demo-northwind",
	timezone = "Europe/London",
	locale   = "en_GB"
);

// Bound to localhost so it resolves in a browser with no hosts-file changes.
sites.addDomain( one.getId(), "localhost", true );
sites.addDomain( one.getId(), "127.0.0.1" );
sites.addDomain( one.getId(), "northwind.test" );

roles.seedDefaultRolesForSite( one.getId() );
themes.setThemeForSite( one.getId(), "default" );
settings.put( one.getId(), "contact.email", "hello@northwind.test" );

ada = users.createUser( one.getId(), "Ada Whitfield", "ada@northwind.test", PASSWORD );
users.assignRole( ada.getId(), roles.getRoleBySlugForSite( "owner", one.getId() ).getId() );

eli = users.createUser( one.getId(), "Eli Barnes", "eli@northwind.test", PASSWORD );
users.assignRole( eli.getId(), roles.getRoleBySlugForSite( "editor", one.getId() ).getId() );

say( "  owner  ada@northwind.test" );
say( "  editor eli@northwind.test" );

// --- pages -------------------------------------------------------------
home = pages.createPage(
	siteId   = one.getId(),
	title    = "Home",
	// Carries shortcodes, so the home page demonstrates them: the list of
	// posts comes from the Blog module, and the page knows only the tag.
	content  = "<p>Northwind Studio is a small design practice working with independent
	            businesses across the north of England. We build things that are meant to last.</p>
	            <p>Have a look at <a href=""/services"">what we do</a>, or
	            <a href=""/about/team"">meet the people</a>.</p>
	            <h2>From the journal</h2>
	            [recent-posts count=""3""]
	            <p class=""small"">&copy; [year] [site-name].</p>",
	metaDescription = "A small design practice working with independent businesses.",
	sortOrder = 0,
	authorId  = ada.getId()
);
pages.publishPage( home.getId(), ada.getId() );
pages.setHomePage( one.getId(), home.getId() );

about = pages.createPage(
	siteId    = one.getId(),
	title     = "About",
	content   = "<p>Founded in 2016, we are six people in a converted mill in Hebden Bridge.</p>",
	metaDescription = "Six people in a converted mill.",
	sortOrder = 1,
	authorId  = ada.getId()
);
pages.publishPage( about.getId(), ada.getId() );

team = pages.createPage(
	siteId   = one.getId(),
	title    = "Team",
	parentId = about.getId(),
	content  = "<p>Ada leads the studio. Eli writes most of what you read here.
	            The rest of us are usually behind a screen.</p>",
	authorId = ada.getId()
);
pages.publishPage( team.getId(), ada.getId() );

history = pages.createPage(
	siteId   = one.getId(),
	title    = "History",
	parentId = about.getId(),
	content  = "<p>The mill was a bobbin works until 1974. We kept the floors.</p>",
	authorId = ada.getId()
);
pages.publishPage( history.getId(), ada.getId() );

services = pages.createPage(
	siteId    = one.getId(),
	title     = "Services",
	content   = "<p>Identity, print, and the occasional website.</p>
	             <ul><li>Brand identity</li><li>Print and packaging</li><li>Websites that stay up</li></ul>",
	sortOrder = 2,
	authorId  = ada.getId()
);
pages.publishPage( services.getId(), ada.getId() );

// Left as a draft on purpose: it should 404 on the public site and show as a
// draft in the admin.
pages.createPage(
	siteId    = one.getId(),
	title     = "Pricing",
	content   = "<p>Not ready to publish this yet.</p>",
	sortOrder = 3,
	authorId  = ada.getId()
);

say( "  pages: Home, About (Team, History), Services, + 1 draft" );

// --- blog --------------------------------------------------------------
studio  = blog.createCategory( one.getId(), "Studio Notes" );
craft   = blog.createCategory( one.getId(), "Craft" );
clients = blog.createCategory( one.getId(), "Client Work" );

posts = [
	{
		title   : "Why we still print proofs",
		cats    : [ studio.getId(), craft.getId() ],
		excerpt : "A screen will lie to you about weight, and about scale.",
		body    : "<p>A screen will lie to you about weight, and about scale. Paper will not.</p>
		           <p>We proof everything at size before it goes anywhere near a client, which
		           costs us an afternoon and saves us a fortnight.</p>"
	},
	{
		title   : "Notes on the new workshop",
		cats    : [ studio.getId() ],
		excerpt : "We have taken the floor above, and it has changed how we work.",
		body    : "<p>We have taken the floor above. It has better light and worse heating.</p>
		           <p>Having somewhere to leave work out overnight has changed how we work
		           more than any software ever has.</p>"
	},
	{
		title   : "A rebrand for Hollins Bakery",
		cats    : [ clients.getId(), craft.getId() ],
		excerpt : "Forty years of paper bags, and a wordmark nobody had drawn on purpose.",
		body    : "<p>Hollins had forty years of paper bags and a wordmark nobody had ever
		           actually drawn on purpose. We drew it on purpose.</p>"
	},
	{
		title   : "On keeping the old floors",
		cats    : [ craft.getId() ],
		excerpt : "The cheapest decision we made was also the best one.",
		body    : "<p>Everyone told us to level them. We sanded them instead.</p>"
	}
];

for ( item in posts ) {
	post = blog.createPost(
		siteId      = one.getId(),
		title       = item.title,
		excerpt     = item.excerpt,
		content     = item.body,
		categoryIds = item.cats,
		authorId    = eli.getId()
	);
	blog.publishPost( post.getId() );
}

// A draft post, to prove drafts stay off the archive.
blog.createPost(
	siteId   = one.getId(),
	title    = "Something we are still writing",
	content  = "<p>Half finished.</p>",
	authorId = eli.getId()
);

say( "  blog: 4 published posts, 1 draft, 3 categories" );

// ================================================================== SITE TWO
say( "" );
say( "=== Harbour Coffee (second tenant, different theme) ===" );

two = sites.createSite(
	name     = "Harbour Coffee",
	slug     = "demo-harbour",
	timezone = "Europe/London",
	locale   = "en_GB"
);
sites.addDomain( two.getId(), "harbour.test", true );

roles.seedDefaultRolesForSite( two.getId() );
themes.setThemeForSite( two.getId(), "starter" );

mira = users.createUser( two.getId(), "Mira Osei", "mira@harbour.test", PASSWORD );
users.assignRole( mira.getId(), roles.getRoleBySlugForSite( "owner", two.getId() ).getId() );

harbourHome = pages.createPage(
	siteId   = two.getId(),
	title    = "Home",
	content  = "<p>A small roastery on the harbour wall. Open from six, most days.</p>",
	authorId = mira.getId()
);
pages.publishPage( harbourHome.getId(), mira.getId() );
pages.setHomePage( two.getId(), harbourHome.getId() );

harbourAbout = pages.createPage(
	siteId    = two.getId(),
	title     = "About",
	content   = "<p>We roast on Tuesdays. You can usually smell it from the pier.</p>",
	sortOrder = 1,
	authorId  = mira.getId()
);
pages.publishPage( harbourAbout.getId(), mira.getId() );

beans = blog.createCategory( two.getId(), "Beans" );
hp = blog.createPost(
	siteId      = two.getId(),
	title       = "This month: a washed Ethiopian",
	content     = "<p>Bright, and it does not need milk.</p>",
	categoryIds = [ beans.getId() ],
	authorId    = mira.getId()
);
blog.publishPost( hp.getId() );

say( "  owner mira@harbour.test" );
say( "  pages: Home, About | blog: 1 post" );

// ============================================================== CONTACT
contact = wb.getInstance( "ContactService@contact" );

contact.createForm(
	siteId         = one.getId(),
	name           = "Contact us",
	intro          = "Tell us what you are working on. We read everything.",
	recipientEmail = "hello@northwind.test"
);
contact.createForm(
	siteId         = two.getId(),
	name           = "Say hello",
	intro          = "Wholesale enquiries welcome.",
	recipientEmail = "mira@harbour.test"
);

say( "" );
say( "=== Contact forms on both sites (/contact) ===" );

// ================================================================== MENUS
/**
 * A curated menu for the first site only.
 *
 * Deliberately not for both: Harbour is left on the automatic navigation the
 * modules contribute, so the two halves of the fallback are visible side by
 * side on one installation.
 *
 * The page links store `pages.page` and a row id rather than a URL, so renaming
 * a page in the admin moves the menu with it.
 */
menus = wb.getInstance( "MenuService@core" );

primary = menus.createMenu( siteId = one.getId(), name = "Primary", slug = "primary" );

menus.addItem(
	menuId = primary.getId(), siteId = one.getId(), label = "Home",
	linkType = "content", contentType = "pages.page", contentId = home.getId()
);

aboutItem = menus.addItem(
	menuId = primary.getId(), siteId = one.getId(), label = "About",
	linkType = "content", contentType = "pages.page", contentId = about.getId()
);

// Nested, to show the second level a theme has to render.
menus.addItem(
	menuId = primary.getId(), siteId = one.getId(), label = "The team",
	linkType = "content", contentType = "pages.page", contentId = team.getId(),
	parentId = aboutItem.getId()
);
menus.addItem(
	menuId = primary.getId(), siteId = one.getId(), label = "Our history",
	linkType = "content", contentType = "pages.page", contentId = history.getId(),
	parentId = aboutItem.getId()
);

menus.addItem(
	menuId = primary.getId(), siteId = one.getId(), label = "Services",
	linkType = "content", contentType = "pages.page", contentId = services.getId()
);

// The editor's own label for the archive, not the module's.
menus.addItem(
	menuId = primary.getId(), siteId = one.getId(), label = "Journal",
	linkType = "content", contentType = "blog.archive", contentId = 0
);

menus.addItem(
	menuId = primary.getId(), siteId = one.getId(), label = "Contact",
	linkType = "url", url = "/contact"
);

say( "" );
say( "=== Menus ===" );
say( "  Northwind: a curated 'primary' menu, with About nesting two children" );
say( "  Harbour:   no menu, so it falls back to the automatic navigation" );

// ============================================================ SUPER ADMIN
root = users.createSuperAdmin( "Platform Root", "root@platform.test", PASSWORD );
say( "" );
say( "=== Platform super admin: root@platform.test (reaches every site) ===" );

say( "" );
say( "All demo passwords: " & PASSWORD );

writeOutput( out.toList( chr( 10 ) ) );
</cfscript>
