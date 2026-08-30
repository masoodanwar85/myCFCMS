<cfsetting showdebugoutput="false" requesttimeout="300">
<cfcontent type="text/plain">
<cfscript>
/**
 * Provision an empty site.
 *
 * The application is multi-tenant already: every page, menu, user, role, form
 * and setting is scoped by `site_id`, and `TenantResolver` picks the tenant off
 * the `Host` header. Adding a site is therefore data, not code — this script
 * just runs the same services the admin would, in the right order, so a new
 * tenant lands complete rather than half-built.
 *
 * It creates nothing you cannot later change in the admin. What it does is get
 * the four things right that are awkward to fix afterwards: the primary domain
 * (canonical URLs and the sitemap are built from it), the default roles, an
 * owner who can sign in, and a home page wired to `pages.homePageId`.
 *
 * ## Running it
 *
 * Kept out of the webroot on purpose, like WillCreator.cfm. Copy it in, run it
 * from the server itself, delete it:
 *
 *     cp resources/database/seeds/NewSite.cfm public/__newsite.cfm
 *     curl -G "http://127.0.0.1/__newsite.cfm" \
 *          --data-urlencode "name=Acme Legal" \
 *          --data-urlencode "domains=acme.example.com,www.acme.example.com" \
 *          --data-urlencode "owner=jane@acme.example.com" \
 *          --data-urlencode "ownerName=Jane Smith" \
 *          --data-urlencode "theme=default"
 *     rm public/__newsite.cfm
 *
 * `-G --data-urlencode` matters: the values contain spaces and commas.
 *
 * ## Parameters
 *
 *     name       required  Human-readable site name.
 *     domains    required  Comma-separated. The FIRST is the primary — it drives
 *                          canonical URLs, the sitemap and social tags.
 *     owner      required  Email for the owner account.
 *     ownerName  optional  Defaults to "Site Owner".
 *     slug       optional  Derived from the name when omitted.
 *     theme      optional  A directory under /themes. Defaults to "default".
 *     timezone   optional  Olson id. Defaults to "UTC".
 *     locale     optional  Defaults to "en_US".
 *
 * ## Safety
 *
 * Refuses to run over a non-local connection, because a provisioning endpoint
 * reachable from the internet creates tenants and accounts for anyone who finds
 * it. Nothing is deleted: if the slug or a domain is already taken the services
 * throw and the script stops, leaving what exists alone.
 */

/* ------------------------------------------------------------------ guard */

LOCAL_ADDRESSES = "127.0.0.1,::1,0:0:0:0:0:0:0:1";

if ( !listFindNoCase( LOCAL_ADDRESSES, cgi.remote_addr ) ) {
	writeOutput( "Refused: run this from the server itself, over 127.0.0.1." & chr(10) );
	writeOutput( "Saw remote address [" & cgi.remote_addr & "]." & chr(10) );
	abort;
}

/* ----------------------------------------------------------- parameters  */

function param( required string key, string fallback = "" ){
	// Deliberately not `?:`. ColdFusion's elvis falls through on any *falsy*
	// value, so a legitimately empty or "0" parameter would silently become
	// the fallback.
	if ( !structKeyExists( url, arguments.key ) ) {
		return arguments.fallback;
	}

	var supplied = trim( url[ arguments.key ] );

	return len( supplied ) ? supplied : arguments.fallback;
}

siteName  = param( "name" );
domains   = param( "domains" );
ownerMail = param( "owner" );
ownerName = param( "ownerName", "Site Owner" );
siteSlug  = param( "slug" );
themeSlug = param( "theme", "default" );
timezone  = param( "timezone", "UTC" );
locale    = param( "locale", "en_US" );

missing = [];
if ( !len( siteName ) )  { arrayAppend( missing, "name" ); }
if ( !len( domains ) )   { arrayAppend( missing, "domains" ); }
if ( !len( ownerMail ) ) { arrayAppend( missing, "owner" ); }

if ( arrayLen( missing ) ) {
	writeOutput( "Missing required parameter(s): " & arrayToList( missing, ", " ) & chr(10) );
	writeOutput( "See the comment at the top of this file." & chr(10) );
	abort;
}

domainList = listToArray( domains );

/* -------------------------------------------------------------- services */

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
function say( line = "" ){ arrayAppend( out, arguments.line ); }

// Fail before creating the site rather than halfway through it.
if ( !themes.themeExists( themeSlug ) ) {
	writeOutput( "No theme [" & themeSlug & "] installed under /themes." & chr(10) );
	writeOutput( "Installed: " );
	installed = themes.getInstalledThemes();
	for ( t in installed ) { writeOutput( t.getSlug() & " " ); }
	writeOutput( chr(10) );
	abort;
}

/* ---------------------------------------------------------------- tenant */

site = sites.createSite(
	name     = siteName,
	slug     = siteSlug,
	timezone = timezone,
	locale   = locale
);

siteId = site.getId();

say( "Site:    " & site.getName() & "  (slug '" & site.getSlug() & "', id " & siteId & ")" );

// The first domain becomes primary on its own, but say so explicitly — this is
// the value canonical URLs and the sitemap are built from.
first = true;
for ( host in domainList ) {
	sites.addDomain( siteId, trim( host ), first );
	say( "Domain:  " & trim( host ) & ( first ? "   <- primary" : "" ) );
	first = false;
}

themes.setThemeForSite( siteId, themeSlug );
say( "Theme:   " & themeSlug );
say();

/* ------------------------------------------------------------------ user */

roles.seedDefaultRolesForSite( siteId );

random = createObject( "java", "java.security.SecureRandom" ).init();
bytes  = createObject( "java", "java.lang.reflect.Array" )
	.newInstance( createObject( "java", "java.lang.Byte" ).TYPE, javacast( "int", 12 ) );
random.nextBytes( bytes );
tempPassword = "Cms-" & lCase( binaryEncode( bytes, "hex" ) );

owner = users.createUser( siteId, ownerName, ownerMail, tempPassword );
users.assignRole( owner.getId(), roles.getRoleBySlugForSite( "owner", siteId ).getId() );

say( "Owner:   " & ownerMail );
say( "         " & tempPassword & "   <- change on first sign-in" );
say();

/* ------------------------------------------------------------------ home */

// A site with no home page renders a 404 at its own root, which looks broken
// before anyone has done anything wrong.
home = pages.createPage(
	siteId    = siteId,
	title     = "Home",
	slug      = "home",
	content   = "<p>This site has been created. Sign in to the admin to replace this page.</p>",
	sortOrder = 1,
	authorId  = owner.getId()
);

pages.publishPage( home.getId(), owner.getId() );
settings.put( siteId, "pages.homePageId", home.getId() );

say( "Pages:   Home, published, set as the site root" );

/* ------------------------------------------------------------------ menu */

primary = menus.createMenu( siteId = siteId, name = "Primary", slug = "primary" );

menus.addItem(
	menuId      = primary.getId(),
	siteId      = siteId,
	label       = "Home",
	linkType    = "content",
	contentType = "pages.page",
	contentId   = home.getId()
);

say( "Menu:    Primary, one item" );

/* --------------------------------------------------------------- contact */

contact.createForm(
	siteId         = siteId,
	name           = "Contact Us",
	intro          = "Send us a message and we will get back to you.",
	recipientEmail = ownerMail
);

say( "Contact: form at /contact" );

/* -------------------------------------------------------------- settings */

settings.put( siteId, "seo.indexable", "true" );
settings.put( siteId, "seo.baseUrl", "" );
settings.put( siteId, "site.title", siteName );

say();
say( "Done. Sign in at http://" & trim( domainList[ 1 ] ) & "/admin" );
say();
say( "Delete this file from the webroot now." );

writeOutput( arrayToList( out, chr(10) ) & chr(10) );
</cfscript>
