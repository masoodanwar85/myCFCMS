/**
 * Tenant administration: the use cases that create and configure a site.
 *
 * This is the layer handlers, API endpoints and CLI tasks call. It validates,
 * normalises and orchestrates; it renders nothing and knows no HTTP. Keeping
 * it free of presentation is what lets the same method back a server-rendered
 * admin screen, a REST endpoint and a future GraphQL mutation.
 */
component singleton accessors="true" {

	property name="siteRepository"         inject="SiteRepository@core";
	property name="slugifier"        inject="Slugifier@core";
	property name="siteDomainRepository"   inject="SiteDomainRepository@core";
	property name="siteSettingsRepository" inject="SiteSettingsRepository@core";
	property name="domainNormalizer"       inject="DomainNormalizer@core";
	property name="wirebox"                inject="wirebox";

	/**
	 * Create a tenant.
	 *
	 * @name     Human-readable site name.
	 * @slug     Stable machine identifier. Derived from the name when omitted.
	 * @status   `active` or `inactive`.
	 * @timezone Olson timezone used when presenting this site's content.
	 * @locale   Default locale for this site.
	 *
	 * @throws Tenancy.InvalidSite       when a required value is missing or malformed.
	 * @throws Tenancy.SlugAlreadyTaken  when the slug is in use.
	 */
	core.models.tenancy.Site function createSite(
		required string name,
		string slug     = "",
		string status   = "active",
		string timezone = "UTC",
		string locale   = "en_US"
	){
		var siteName = trim( arguments.name );

		if ( !len( siteName ) ) {
			throw( type = "Tenancy.InvalidSite", message = "A site requires a name." );
		}

		var siteSlug = len( trim( arguments.slug ) ) ? slugify( arguments.slug ) : slugify( siteName );

		if ( !len( siteSlug ) ) {
			throw(
				type    = "Tenancy.InvalidSite",
				message = "Could not derive a usable slug from [#siteName#]. Provide one explicitly."
			);
		}

		if ( !isValidStatus( arguments.status ) ) {
			throw(
				type    = "Tenancy.InvalidSite",
				message = "Unknown site status [#arguments.status#]. Expected `active` or `inactive`."
			);
		}

		// Cheap, readable failure for the common case. The unique index in the
		// database is what actually guarantees it.
		if ( siteRepository.existsBySlug( siteSlug ) ) {
			throw(
				type    = "Tenancy.SlugAlreadyTaken",
				message = "The site slug [#siteSlug#] is already in use."
			);
		}

		var site = wirebox
			.getInstance( "Site@core" )
			.setName( siteName )
			.setSlug( siteSlug )
			.setStatus( arguments.status )
			.setTimezone( trim( arguments.timezone ) )
			.setLocale( trim( arguments.locale ) );

		return siteRepository.create( site );
	}

	/**
	 * Attach a hostname to a site.
	 *
	 * The first domain a site receives becomes its primary automatically —
	 * a site with domains but no primary has no canonical URL to build links from.
	 *
	 * @siteId    The owning site.
	 * @domain    Hostname; normalised before it is stored.
	 * @isPrimary Force this domain to be the canonical one.
	 * @isActive  Whether the domain should serve traffic.
	 *
	 * @throws Tenancy.SiteNotFound          when the site does not exist.
	 * @throws Tenancy.InvalidDomain         when the hostname is unusable.
	 * @throws Tenancy.DomainAlreadyAssigned when the hostname belongs to any site.
	 */
	core.models.tenancy.SiteDomain function addDomain(
		required numeric siteId,
		required string domain,
		boolean isPrimary = false,
		boolean isActive  = true
	){
		var site = siteRepository.findById( arguments.siteId );

		if ( isNull( site ) ) {
			throw( type = "Tenancy.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		var host = domainNormalizer.normalize( arguments.domain );

		if ( !len( host ) ) {
			throw(
				type    = "Tenancy.InvalidDomain",
				message = "[#arguments.domain#] is not a usable hostname."
			);
		}

		if ( siteDomainRepository.existsByDomain( host ) ) {
			throw(
				type    = "Tenancy.DomainAlreadyAssigned",
				message = "The domain [#host#] is already assigned to a site.",
				detail  = "A domain may belong to exactly one site."
			);
		}

		var isFirstDomain = !siteDomainRepository.findBySiteId( arguments.siteId ).len();
		var makeItPrimary = arguments.isPrimary || isFirstDomain;

		// Clear the existing primary first; only one row per site may hold the flag.
		if ( makeItPrimary ) {
			var current = siteDomainRepository.findPrimaryForSite( arguments.siteId );
			if ( !isNull( current ) ) {
				siteDomainRepository.setPrimaryFlag( current.getId(), false );
			}
		}

		var siteDomain = wirebox
			.getInstance( "SiteDomain@core" )
			.setSiteId( arguments.siteId )
			.setDomain( host )
			.setIsPrimary( makeItPrimary )
			.setIsActive( arguments.isActive );

		return siteDomainRepository.create( siteDomain );
	}

	array function getDomains( required numeric siteId ){
		return siteDomainRepository.findBySiteId( arguments.siteId );
	}

	/**
	 * Promote an existing domain to be the site's canonical hostname.
	 *
	 * @throws Tenancy.DomainNotFound when the domain is not owned by that site.
	 */
	function makeDomainPrimary( required numeric siteId, required string domain ){
		var host       = domainNormalizer.normalize( arguments.domain );
		var siteDomain = siteDomainRepository.findByDomain( host );

		if ( isNull( siteDomain ) || siteDomain.getSiteId() != arguments.siteId ) {
			throw(
				type    = "Tenancy.DomainNotFound",
				message = "Site [#arguments.siteId#] does not own the domain [#host#]."
			);
		}

		siteDomainRepository.makePrimary( arguments.siteId, siteDomain.getId() );

		return this;
	}

	/**
	 * Write one tenant setting.
	 *
	 * @throws Tenancy.SiteNotFound     when the site does not exist.
	 * @throws Tenancy.InvalidSetting   when the key is empty.
	 */
	core.models.tenancy.SiteSetting function setSetting(
		required numeric siteId,
		required string key,
		string value = ""
	){
		var settingKey = trim( arguments.key );

		if ( !len( settingKey ) ) {
			throw( type = "Tenancy.InvalidSetting", message = "A setting requires a key." );
		}

		if ( isNull( siteRepository.findById( arguments.siteId ) ) ) {
			throw( type = "Tenancy.SiteNotFound", message = "No site with id [#arguments.siteId#]." );
		}

		return siteSettingsRepository.put( arguments.siteId, settingKey, arguments.value );
	}

	string function getSetting(
		required numeric siteId,
		required string key,
		string defaultValue = ""
	){
		return siteSettingsRepository.getValue( arguments.siteId, trim( arguments.key ), arguments.defaultValue );
	}

	struct function getSettings( required numeric siteId ){
		return siteSettingsRepository.getAllForSite( arguments.siteId );
	}

	array function getAllSites(){
		return siteRepository.findAll();
	}

	function getSiteById( required numeric siteId ){
		return siteRepository.findById( arguments.siteId );
	}

	function getSiteBySlug( required string slug ){
		return siteRepository.findBySlug( arguments.slug );
	}

	boolean function isValidStatus( required string status ){
		// `listFindNoCase` rather than a member call on an array literal.
		// ColdFusion 2025 parses `[ "a", "b" ].findNoCase( x )`; 2023 does not,
		// and fails to compile the whole component with an error pointing at
		// whatever follows rather than at the literal.
		return listFindNoCase( "active,inactive", arguments.status ) > 0;
	}

	/**
	 * Lower-case, hyphen-separated, alphanumeric.
	 */
	string function slugify( required string value ){
		// Delegated: five copies of this each dropped accented
		// characters instead of transliterating them.
		return slugifier.slugify( arguments.value );
	}

}
