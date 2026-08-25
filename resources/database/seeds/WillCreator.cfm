<cfsetting showdebugoutput="false" requesttimeout="900">
<cfcontent type="text/plain">
<cfscript>
/**
 * Provisions the Will Creator site and removes the demo data.
 *
 * Runs through the real services rather than raw inserts, so everything obeys
 * the same validation, slug derivation, path building and HTML sanitising as
 * content created through the admin.
 *
 * ## The page tree
 *
 * Read from `willcreator-pages.json`, which was generated from the live site's
 * own navigation rather than transcribed. 100 pages, four levels deep:
 *
 *     Legal Services > Wills > Wills - Blue Mountains > Wills - Katoomba
 *
 * Two entries in that file are *not* built as pages. "Blog" is served by the
 * Blog module and "Contact Us" by the Contact module; creating pages at those
 * paths would shadow the modules that own them.
 *
 * ## Content
 *
 * The pages listed in `copy` below carry full content. The remaining service
 * and location pages are created with a short, factual line so the structure,
 * URLs and navigation are correct — their real copy has to come from the
 * existing site. The script reports the split at the end so it is not a
 * surprise.
 *
 * ## Idempotent
 *
 * Re-running removes and rebuilds the `willcreator` site.
 *
 * Not in the webroot on purpose. To run it:
 *
 *     cp resources/database/seeds/WillCreator.cfm public/__provision.cfm
 *     curl "http://127.0.0.1:<port>/__provision.cfm"
 *     rm public/__provision.cfm
 */
wb       = application.wirebox;
sites    = wb.getInstance( "SiteService@core" );
roles    = wb.getInstance( "RoleService@core" );
users    = wb.getInstance( "UserService@core" );
pages    = wb.getInstance( "PageService@pages" );
menus    = wb.getInstance( "MenuService@core" );
blog     = wb.getInstance( "BlogService@blog" );
contact  = wb.getInstance( "ContactService@contact" );
themes   = wb.getInstance( "ThemeService@core" );
settings = wb.getInstance( "SiteSettingsRepository@core" );

out = [];
function say( line ){ out.append( arguments.line ); }

// Served by their own modules; a page at the same path would shadow them.
MODULE_PATHS = "blog,contact-us";

/* ------------------------------------------------------------ clear out */

queryExecute( "DELETE FROM sites WHERE slug LIKE 'demo-%'" );
queryExecute( "DELETE FROM sites WHERE slug = 'willcreator'" );
queryExecute( "DELETE FROM users WHERE email = 'root@platform.test'" );

say( "Removed: demo sites and the platform super admin." );
say( "" );

/* --------------------------------------------------------------- tenant */

site = sites.createSite(
	name     = "Will Creator",
	slug     = "willcreator",
	timezone = "Australia/Sydney",
	locale   = "en_AU"
);

sites.addDomain( site.getId(), "willcreator.srv1902739.hstgr.cloud", true );
sites.addDomain( site.getId(), "willcreator.com.au", false );
sites.addDomain( site.getId(), "www.willcreator.com.au", false );

// Local aliases, so the site can be opened during development without having
// to fake a Host header. Non-primary, which is what matters: canonical URLs,
// the sitemap and social tags are all built from the primary domain, so
// nothing a search engine sees ever mentions localhost.
sites.addDomain( site.getId(), "localhost", false );
sites.addDomain( site.getId(), "127.0.0.1", false );

themes.setThemeForSite( site.getId(), "willcreator" );

say( "Site:    Will Creator, theme 'willcreator'" );
say( "Domains: willcreator.srv1902739.hstgr.cloud (primary), willcreator.com.au, www.willcreator.com.au" );

/* ----------------------------------------------------------------- user */

roles.seedDefaultRolesForSite( site.getId() );

random = createObject( "java", "java.security.SecureRandom" ).init();
bytes  = createObject( "java", "java.lang.reflect.Array" )
	.newInstance( createObject( "java", "java.lang.Byte" ).TYPE, javacast( "int", 12 ) );
random.nextBytes( bytes );
tempPassword = "Wc-" & lCase( binaryEncode( bytes, "hex" ) );

owner = users.createUser( site.getId(), "Peter Tanswell", "peter@willcreator.com.au", tempPassword );
users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

say( "Owner:   peter@willcreator.com.au" );
say( "         " & tempPassword & "   <- change on first sign-in" );
say( "" );

/* -------------------------------------------------------- page content  */

/**
 * The real page content, extracted from the live site.
 *
 * `willcreator-content.json` was produced by fetching every URL in the
 * navigation and taking the `<main>` region, with the site chrome, editor
 * wrappers and the old `/index.cfm/` link prefix stripped. It is the site's own
 * copy, not a paraphrase of it.
 *
 * **83 of the 100 pages are empty on the live site** — they exist in the
 * navigation and render a heading, with no body at all. Those are created here
 * with empty content, because that is what they contain. Writing something
 * plausible into them would hide the fact that they need writing.
 */
content = deserializeJSON( fileRead( expandPath( "/resources/database/seeds/willcreator-content.json" ) ) );

/* ---------------------------------------------------------------- pages */

tree    = deserializeJSON( fileRead( expandPath( "/resources/database/seeds/willcreator-pages.json" ) ) );
created = { "withContent" : 0, "empty" : 0 };
byPath  = {};

/**
 * Build a branch of the tree.
 *
 * The path is carried down so a page's content can be looked up by the address
 * it will actually live at, which is what makes the `copy` map above readable.
 */
function build( nodes, parentId, prefix ){
	var order = 0;

	for ( var node in arguments.nodes ) {
		order++;

		var slug = node.slug;
		var path = len( arguments.prefix ) ? arguments.prefix & "/" & slug : slug;

		// Home has an empty slug in the source nav; it becomes the site root.
		if ( !len( slug ) ) {
			slug = "home";
			path = "";
		}

		if ( listFindNoCase( MODULE_PATHS, path ) ) {
			continue;
		}

		var body = structKeyExists( content, path ) ? content[ path ].html : "";

		created[ len( body ) ? "withContent" : "empty" ]++;

		var attributes = {
			siteId          : site.getId(),
			title           : node.title,
			slug            : slug,
			content         : body,
			metaTitle       : node.title & " | Will Creator",
			metaDescription : "Wills, estates and succession law for New South Wales families.",
			sortOrder       : order,
			authorId        : owner.getId()
		};

		// Only when there actually is one. `parentId` is optional on the
		// service, and 0 does not mean "top level" — it means "the page whose
		// id is 0", which the service then refuses to find.
		if ( val( arguments.parentId ) ) {
			attributes.parentId = arguments.parentId;
		}

		var page = pages.createPage( argumentCollection = attributes );

		pages.publishPage( page.getId(), owner.getId() );

		byPath[ path ] = page;

		if ( node.children.len() ) {
			build( node.children, page.getId(), path );
		}
	}
}

build( tree, 0, "" );

settings.put( site.getId(), "pages.homePageId", byPath[ "" ].getId() );

say( "Pages:   " & ( created.withContent + created.empty ) & " created, four levels deep" );
say( "         " & created.withContent & " carry content from the live site" );
say( "         " & created.empty & " are empty, because they are empty on the live site too" );

/* ----------------------------------------------------------------- blog */

category = blog.createCategory( siteId = site.getId(), name = "Estate Planning" );

postPath = "blog/demystifying-estate-planning";

post = blog.createPost(
	siteId      = site.getId(),
	title       = content[ postPath ].title,
	slug        = "demystifying-estate-planning",
	content     = content[ postPath ].html,
	categoryIds = [ category.getId() ],
	authorId    = owner.getId()
);

blog.publishPost( post.getId() );

say( "Blog:    1 post, 1 category" );

/* -------------------------------------------------------------- contact */

contact.createForm(
	siteId         = site.getId(),
	name           = "Contact Us",
	intro          = "Send us a message with any questions you have. We aim to reply within 24 hours.",
	recipientEmail = "peter@willcreator.com.au"
);

say( "Contact: form at /contact" );

/* ----------------------------------------------------------------- menu */

primary   = menus.createMenu( siteId = site.getId(), name = "Primary", slug = "primary" );
menuItems = 0;

/**
 * Mirror the page tree into the menu, to the same depth.
 *
 * Items link to the *page*, not to a URL, so renaming or moving a page carries
 * the menu with it rather than leaving a stale address behind.
 */
function buildMenu( nodes, parentItemId, prefix ){
	for ( var node in arguments.nodes ) {
		var slug = len( node.slug ) ? node.slug : "home";
		var path = len( node.slug ) ? ( len( arguments.prefix ) ? arguments.prefix & "/" & node.slug : node.slug ) : "";

		var item = "";

		if ( listFindNoCase( MODULE_PATHS, path ) ) {
			// The two module-served entries: the blog archive by its registered
			// content type, the contact form by its address.
			if ( path == "blog" ) {
				item = menus.addItem(
					menuId      = primary.getId(),
					siteId      = site.getId(),
					label       = node.title,
					linkType    = "content",
					contentType = "blog.archive",
					contentId   = 0,
					parentId    = arguments.parentItemId
				);
			} else {
				item = menus.addItem(
					menuId   = primary.getId(),
					siteId   = site.getId(),
					label    = node.title,
					linkType = "url",
					url      = "/contact",
					parentId = arguments.parentItemId
				);
			}
		} else {
			item = menus.addItem(
				menuId      = primary.getId(),
				siteId      = site.getId(),
				label       = node.title,
				linkType    = "content",
				contentType = "pages.page",
				contentId   = byPath[ path ].getId(),
				parentId    = arguments.parentItemId
			);
		}

		menuItems++;

		// Do not descend into a module-served branch. The live nav lists the
		// single blog post as a child of Blog; in this CMS the archive lists
		// its own posts, and a menu naming individual articles goes stale the
		// day a second one is written.
		if ( node.children.len() && !listFindNoCase( MODULE_PATHS, path ) ) {
			buildMenu( node.children, item.getId(), path );
		}
	}
}

buildMenu( tree, 0, "" );

say( "Menu:    " & menuItems & " items, mirroring the page tree" );

/* ------------------------------------------------------------------ seo */

settings.put( site.getId(), "seo.indexable", "true" );
settings.put( site.getId(), "seo.defaultDescription", "Fixed-fee wills, powers of attorney and enduring guardians for New South Wales families, reviewed by a qualified solicitor." );
settings.put( site.getId(), "seo.baseUrl", "" );

say( "SEO:     indexable, canonical URLs from the primary domain" );
say( "" );
say( "Visit:   http://willcreator.srv1902739.hstgr.cloud/" );
say( "Admin:   http://willcreator.srv1902739.hstgr.cloud/admin" );

writeOutput( out.toList( chr( 10 ) ) );
</cfscript>
