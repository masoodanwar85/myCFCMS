<cfsetting showdebugoutput="false" requesttimeout="600">
<cfcontent type="text/plain">
<cfscript>
/**
 * Provisions the Will Creator site and removes the demo data.
 *
 * Runs through the real services rather than raw inserts, so everything it
 * creates obeys the same validation, slug derivation, path building and HTML
 * sanitising as content created through the admin.
 *
 * ## What it deletes
 *
 * Every site whose slug begins `demo-`, and the platform super admin seeded
 * with them. Deleting a site cascades to its pages, menus, media rows, contact
 * forms, submissions, API tokens, redirects and users — that is the whole
 * point of the foreign keys, and it means this leaves nothing behind.
 *
 * Files under `storage/media` are **not** removed, because they are outside the
 * database and this script has no way to tell a demo upload from one that
 * matters. There are none at the time of writing.
 *
 * ## Idempotent
 *
 * Re-running it removes and rebuilds the `willcreator` site, so it can be used
 * to reset the content while the structure is still being settled.
 *
 * Not in the webroot on purpose. To run it, copy it into `public/` temporarily:
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
contact  = wb.getInstance( "ContactService@contact" );
themes   = wb.getInstance( "ThemeService@core" );
settings = wb.getInstance( "SiteSettingsRepository@core" );

out = [];
function say( line ){ out.append( arguments.line ); }

/* ------------------------------------------------------------ clear out */

queryExecute( "DELETE FROM sites WHERE slug LIKE 'demo-%'" );
queryExecute( "DELETE FROM sites WHERE slug = 'willcreator'" );
// The seeded platform super admin belongs to no site, so no cascade reaches it.
queryExecute( "DELETE FROM users WHERE email = 'root@platform.test'" );

say( "Removed: demo sites, their content and users, and the platform super admin." );
say( "" );

/* --------------------------------------------------------------- tenant */

site = sites.createSite(
	name     = "Will Creator",
	slug     = "willcreator",
	timezone = "Australia/Sydney",
	locale   = "en_AU"
);

// Primary is the host the site answers on today. Canonical URLs, the sitemap
// and social tags are all built from it, so it is the one that decides the
// site's public address — not whichever domain a visitor happens to arrive on.
sites.addDomain( site.getId(), "willcreator.srv1902739.hstgr.cloud", true );
sites.addDomain( site.getId(), "willcreator.com.au", false );
sites.addDomain( site.getId(), "www.willcreator.com.au", false );

themes.setThemeForSite( site.getId(), "default" );

say( "Site:    Will Creator (" & site.getId() & ")" );
say( "Domains: willcreator.srv1902739.hstgr.cloud (primary)" );
say( "         willcreator.com.au, www.willcreator.com.au" );
say( "" );

/* ----------------------------------------------------------------- user */

roles.seedDefaultRolesForSite( site.getId() );

// A one-time password, generated rather than chosen, printed once below.
// Change it on first sign-in: there is no password reset flow yet.
random   = createObject( "java", "java.security.SecureRandom" ).init();
bytes    = createObject( "java", "java.lang.reflect.Array" )
	.newInstance( createObject( "java", "java.lang.Byte" ).TYPE, javacast( "int", 12 ) );
random.nextBytes( bytes );
tempPassword = "Wc-" & lCase( binaryEncode( bytes, "hex" ) );

owner = users.createUser( site.getId(), "Peter Tanswell", "peter@willcreator.com.au", tempPassword );
users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", site.getId() ).getId() );

say( "Owner:    peter@willcreator.com.au" );
say( "Password: " & tempPassword & "   <- change this on first sign-in" );
say( "" );

/* ---------------------------------------------------------------- pages */

function publish( page ){
	pages.publishPage( arguments.page.getId(), owner.getId() );
	return arguments.page;
}

home = publish( pages.createPage(
	siteId    = site.getId(),
	title     = "Home",
	content   = "<p>Put your affairs in order and prepare for the future. Will Creator is a
	             fixed-fee service for wills, powers of attorney and enduring guardians,
	             built for New South Wales families.</p>
	             <h2>Your estate portfolio</h2>
	             <p>There are three key documents every adult should hold: a will, a power of
	             attorney, and the appointment of an enduring guardian. Together they set out
	             what happens to your assets, who can act for you financially if you cannot,
	             and who makes health and lifestyle decisions on your behalf.</p>
	             <h2>How it works</h2>
	             <p>You complete the documents online, in your own time, at a fixed fee agreed
	             before you start. Every document is reviewed by a qualified solicitor before
	             you sign it, so you are not relying on a template alone.</p>
	             <h2>When is the best time to do this?</h2>
	             <p>Now. These documents only work if they are already in place, and the
	             circumstances that make people think about them are rarely convenient.</p>",
	metaTitle = "Will Creator | Fixed-fee wills, powers of attorney and enduring guardians",
	metaDescription = "A fixed-fee online service for wills, powers of attorney and enduring guardians, reviewed by a qualified solicitor. Serving New South Wales families.",
	sortOrder = 0,
	authorId  = owner.getId()
) );

// The site's front door. Stored as a setting so Core needs no knowledge of pages.
settings.put( site.getId(), "pages.homePageId", home.getId() );

about = publish( pages.createPage(
	siteId    = site.getId(),
	title     = "About Us",
	content   = "<p>PT Legal is a small practice based in Parramatta, in Sydney's west, serving
	             clients across Sydney and New South Wales remotely.</p>
	             <p>We work to make legal matters feel manageable rather than intimidating,
	             explaining things in plain language and being clear about cost from the start.</p>
	             <h2>What you can expect</h2>
	             <ul>
	               <li>Friendly, courteous and responsive service</li>
	               <li>Commitments honoured, without exception</li>
	               <li>Costs disclosed up front, and fixed-price quotes that stay fixed</li>
	               <li>A callback within 24 hours when we cannot help immediately</li>
	               <li>Plain language, not legalese</li>
	               <li>A lifetime guarantee on the services we provide</li>
	             </ul>
	             <p>Our focus is wills, estates and succession law for New South Wales families.</p>
	             <p><em>Liability limited by a scheme approved under Professional Standards
	             Legislation.</em></p>",
	metaTitle = "About Us | Will Creator",
	metaDescription = "PT Legal is a small Parramatta practice focused on wills, estates and succession law for New South Wales families.",
	sortOrder = 1,
	authorId  = owner.getId()
) );

solicitor = publish( pages.createPage(
	siteId    = site.getId(),
	title     = "Our Solicitor",
	content   = "<h2>Peter Tanswell</h2>
	             <p>Peter is the director of PT Legal, a practice focused on estate planning,
	             probate, estate administration and estate litigation.</p>
	             <p>Before the law, Peter spent more than four decades in information technology,
	             including management roles at KPMG and EY in Australia and the United Kingdom.
	             That background shapes a practical approach to complex advice, and it is why
	             willcreator.com.au exists: a system that lets people prepare their own wills,
	             powers of attorney and enduring guardian documents, with a solicitor reviewing
	             the result.</p>
	             <h2>Qualifications</h2>
	             <ul>
	               <li>Master of Laws (Applied Law), specialising in Wills, Estates and Property Law</li>
	               <li>Bachelor of Laws</li>
	               <li>Graduate Diploma in Legal Practice</li>
	               <li>Doctorate in Project Management</li>
	               <li>Master of Commerce (Accounting Information Systems)</li>
	               <li>Master of Science (Computing Science)</li>
	             </ul>
	             <h2>Memberships</h2>
	             <ul>
	               <li>Law Society of New South Wales</li>
	               <li>Information Systems Audit and Control Association (ISACA)</li>
	             </ul>",
	metaTitle = "Our Solicitor | Peter Tanswell | Will Creator",
	metaDescription = "Peter Tanswell, director of PT Legal, specialising in estate planning, probate, estate administration and estate litigation.",
	sortOrder = 2,
	authorId  = owner.getId()
) );

services = publish( pages.createPage(
	siteId    = site.getId(),
	title     = "Legal Services",
	content   = "<p>We work in wills and estates: estate planning, will preparation, powers of
	             attorney and enduring guardians, along with probate, letters of administration
	             and estate litigation.</p>
	             <p>Estate planning is rarely simple, particularly where families are blended,
	             and a one-size-fits-all approach is not adequate. We tailor a plan to your
	             circumstances.</p>
	             <h2>Preparing an estate plan and a will</h2>
	             <p>A will is a legal document setting out how your assets are distributed after
	             you die. It names your beneficiaries, appoints an executor, can appoint a
	             guardian for children under 18, and can record your funeral wishes.</p>
	             <p>A full estate plan goes further, covering superannuation, protection for
	             vulnerable beneficiaries, tax, and appointing someone to act for you if you
	             lose capacity.</p>
	             <h2>If you have lost someone</h2>
	             <p>We can help you apply for a Grant of Probate, or for Letters of
	             Administration where there is no will, and assist with administering and
	             distributing the estate afterwards.</p>",
	metaTitle = "Legal Services | Wills and Estates | Will Creator",
	metaDescription = "Estate planning, wills, powers of attorney, enduring guardians, probate and letters of administration across New South Wales.",
	sortOrder = 3,
	authorId  = owner.getId()
) );

// The service pages, as children of Legal Services so their URLs read
// /legal-services/wills and so on.
servicePages = [
	{ title : "Estate Planning", summary : "A plan tailored to your circumstances, covering your will, your superannuation, protection for vulnerable beneficiaries, tax, and who acts for you if you lose capacity." },
	{ title : "Wills", summary : "A will sets out how your assets are distributed, names your executor, and can appoint a guardian for children under 18." },
	{ title : "Creating a Will", summary : "Complete your will online at a fixed fee, in your own time, with a qualified solicitor reviewing it before you sign." },
	{ title : "Power of Attorney", summary : "Appoints someone to make financial and legal decisions for you. An enduring power of attorney continues to operate if you lose capacity." },
	{ title : "Enduring Guardian", summary : "Appoints someone to make health, medical and lifestyle decisions on your behalf if you are unable to make them yourself." },
	{ title : "Probate", summary : "The grant that confirms a will is valid and authorises the executor to deal with the estate." },
	{ title : "Letters of Administration", summary : "Where there is no valid will, this is the grant that authorises someone to administer the estate." },
	{ title : "Property Law", summary : "Conveyancing, leasing and transmission applications." },
	{ title : "Contracts", summary : "Drafting and reviewing commercial agreements." },
	{ title : "Non-Disclosure Agreements", summary : "Confidentiality agreements for commercial discussions." }
];

order = 0;

for ( entry in servicePages ) {
	order++;

	publish( pages.createPage(
		siteId    = site.getId(),
		title     = entry.title,
		parentId  = services.getId(),
		content   = "<p>" & entry.summary & "</p>
		             <p>Get in touch to talk through your circumstances, or start online through
		             the Will Wizard.</p>",
		metaTitle = entry.title & " | Will Creator",
		metaDescription = entry.summary,
		sortOrder = order,
		authorId  = owner.getId()
	) );
}

resources = publish( pages.createPage(
	siteId    = site.getId(),
	title     = "Legal Resources",
	content   = "<p>Background reading on wills, estates and succession law in New South Wales,
	             along with the tools you need to get started.</p>
	             <h2>Where we work</h2>
	             <ul>
	               <li>Sydney West &mdash; Parramatta, Newington, Guildford, Merrylands, Wentworthville, Westmead</li>
	               <li>Blue Mountains &mdash; Katoomba, Leura, Blackheath, Blaxland, Springwood</li>
	               <li>Hawkesbury and the Hills District</li>
	               <li>Central West NSW &mdash; Bathurst, Orange, Forbes, Parkes, Dubbo</li>
	               <li>Central Coast NSW &mdash; Gosford, Terrigal, Avoca Beach, Ettalong Beach</li>
	             </ul>
	             <p>Documents can be prepared remotely wherever you are in New South Wales.</p>",
	metaTitle = "Legal Resources | Will Creator",
	metaDescription = "Guides to wills, estates and succession law in New South Wales, and the areas we serve.",
	sortOrder = 4,
	authorId  = owner.getId()
) );

wizard = publish( pages.createPage(
	siteId    = site.getId(),
	title     = "Will Wizard",
	content   = "<p>The Will Wizard takes you through your will, power of attorney and enduring
	             guardian documents step by step, at a fixed fee agreed before you start.</p>
	             <p>Everything you complete is reviewed by a qualified solicitor before you sign.</p>
	             <p><em>This page is a placeholder for the Will Wizard application, which is a
	             separate tool rather than a content page.</em></p>",
	metaTitle = "Will Wizard | Will Creator",
	metaDescription = "Complete your will, power of attorney and enduring guardian online at a fixed fee, reviewed by a solicitor.",
	sortOrder = 5,
	authorId  = owner.getId()
) );

say( "Pages:   " & pages.getPagesForSite( site.getId() ).len() & " created and published" );

/* ------------------------------------------------------------- contact  */

contactForm = contact.createForm(
	siteId         = site.getId(),
	name           = "Contact Us",
	intro          = "Send us a message with any questions you have. We aim to reply within 24 hours.",
	recipientEmail = "peter@willcreator.com.au"
);

say( "Contact: form at /contact, replies to peter@willcreator.com.au" );

/* ---------------------------------------------------------------- menu  */

primary = menus.createMenu( siteId = site.getId(), name = "Primary", slug = "primary" );

function link( label, page, parentId ){
	return menus.addItem(
		menuId      = primary.getId(),
		siteId      = site.getId(),
		label       = arguments.label,
		linkType    = "content",
		contentType = "pages.page",
		contentId   = arguments.page.getId(),
		parentId    = arguments.parentId ?: 0
	);
}

link( "Home", home );
link( "About Us", about );
link( "Our Solicitor", solicitor );

servicesItem = link( "Legal Services", services );

// Two levels is the cap, so the service pages hang directly off Legal Services.
for ( child in pages.getPagesForSite( site.getId() ) ) {
	if ( !isNull( child.getParentId() ) && child.getParentId() == services.getId() ) {
		link( child.getTitle(), child, servicesItem.getId() );
	}
}

link( "Will Wizard", wizard );
link( "Legal Resources", resources );

menus.addItem(
	menuId   = primary.getId(),
	siteId   = site.getId(),
	label    = "Blog",
	linkType = "content",
	contentType = "blog.archive",
	contentId   = 0
);

menus.addItem(
	menuId   = primary.getId(),
	siteId   = site.getId(),
	label    = "Contact Us",
	linkType = "url",
	url      = "/contact"
);

say( "Menu:    primary, with the service pages nested under Legal Services" );

/* ----------------------------------------------------------------- seo  */

settings.put( site.getId(), "seo.indexable", "true" );
settings.put( site.getId(), "seo.defaultDescription", "Fixed-fee wills, powers of attorney and enduring guardians for New South Wales families, reviewed by a qualified solicitor." );
// Left blank deliberately: with no override, canonical URLs and the sitemap are
// built from the primary domain and the scheme of the request, which is correct
// today and stays correct when the site moves to https on willcreator.com.au.
settings.put( site.getId(), "seo.baseUrl", "" );

say( "SEO:     indexable, canonical URLs derived from the primary domain" );
say( "" );
say( "Visit:   http://willcreator.srv1902739.hstgr.cloud/" );
say( "Admin:   http://willcreator.srv1902739.hstgr.cloud/admin" );

writeOutput( out.toList( chr( 10 ) ) );
</cfscript>
