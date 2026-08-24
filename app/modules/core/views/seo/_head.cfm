<cfoutput>
<!---
	The machine-readable half of a page's <head>.

	Shipped by Core and included by a theme, rather than written out in every
	theme, because these tags are not a design decision — a canonical tag is
	either right or it de-indexes the site, and that should not depend on which
	theme a client picked.

	A theme is still free not to include this, or to emit its own: nothing here
	is compulsory. But a theme that does include it gets the whole set correct.

	Expects `args.seo`, built by SeoService. Degrades to emitting nothing rather
	than throwing, so a theme rendered outside the front controller — a preview,
	a test — is not a broken page.
--->
<!---
	`xmlFormat` rather than `encodeForHTMLAttribute` for these quoted values.
	Both are safe here; the aggressive one encodes every space as `&##x20;`,
	which is valid HTML that some social-preview scrapers parse badly, and it
	turns a readable description into noise in the page source.
--->
<cfset local.seo = args.seo ?: {}>

<cfif len( local.seo.canonical ?: "" )>
	<link rel="canonical" href="#xmlFormat( local.seo.canonical )#">
</cfif>

<cfif len( local.seo.robots ?: "" )>
	<meta name="robots" content="#xmlFormat( local.seo.robots )#">
</cfif>

<cfif len( local.seo.keywords ?: "" )>
	<!---
		Ignored by every major search engine since around 2009. Emitted because
		an author who filled the field in should see it in the source, and
		because some internal and site-search tools still read it.
	--->
	<meta name="keywords" content="#xmlFormat( local.seo.keywords )#">
</cfif>

<meta property="og:type" content="#xmlFormat( local.seo.type ?: 'website' )#">
<meta property="og:title" content="#xmlFormat( len( local.seo.ogTitle ?: '' ) ? local.seo.ogTitle : ( args.title ?: '' ) )#">
<cfif len( local.seo.siteName ?: "" )>
	<meta property="og:site_name" content="#xmlFormat( local.seo.siteName )#">
</cfif>
<cfif len( local.seo.canonical ?: "" )>
	<meta property="og:url" content="#xmlFormat( local.seo.canonical )#">
</cfif>
<cfif len( local.seo.ogDescription ?: local.seo.description ?: "" )>
	<meta property="og:description" content="#xmlFormat( local.seo.ogDescription ?: local.seo.description )#">
</cfif>
<cfif len( local.seo.locale ?: "" )>
	<!--- Open Graph wants `en_GB`, not the `en-GB` an HTML lang attribute uses. --->
	<meta property="og:locale" content="#xmlFormat( replace( local.seo.locale, '-', '_', 'all' ) )#">
</cfif>

<cfif len( local.seo.image ?: "" )>
	<meta property="og:image" content="#xmlFormat( local.seo.image )#">
	<!---
		The author's chosen card, falling back to `summary_large_image` when
		they have not chosen one and there is an image to fill it.
	--->
	<meta name="twitter:card" content="#xmlFormat( len( local.seo.twitterCard ?: '' ) ? local.seo.twitterCard : 'summary_large_image' )#">
	<meta name="twitter:image" content="#xmlFormat( local.seo.image )#">
<cfelse>
	<!---
		Never `summary_large_image` without an image: that gives a card with a
		blank panel where the picture should be, which looks worse than the
		plain summary card. An author's choice is overridden here on purpose.
	--->
	<meta name="twitter:card" content="summary">
</cfif>

<cfif len( local.seo.jsonLd ?: "" )>
	<!---
		Structured data, written by an author who holds `content.unfiltered`.

		`</script>` is neutralised before output. The block is valid JSON — the
		service refuses to store anything else — but JSON may legitimately
		contain the *characters* `</script>`, and an HTML parser ends the script
		element at the first one it sees regardless of the JSON around it. That
		is a script-injection hole hiding inside a data field, and the standard
		escape is to break the sequence with a backslash, which JSON readers
		ignore.
	--->
	<script type="application/ld+json">#replace( local.seo.jsonLd, "</", "<\/", "all" )#</script>
</cfif>

<cfif len( local.seo.headMarkup ?: "" )>
	<!--- Raw, by design. See PageService.applyRawMarkup for the gate. --->
	#local.seo.headMarkup#
</cfif>

<cfif ( local.seo.type ?: "" ) eq "article">
	<cfif isDate( local.seo.publishedAt ?: "" )>
		<meta property="article:published_time" content="#dateTimeFormat( local.seo.publishedAt, 'iso' )#">
	</cfif>
	<cfif isDate( local.seo.modifiedAt ?: "" )>
		<meta property="article:modified_time" content="#dateTimeFormat( local.seo.modifiedAt, 'iso' )#">
	</cfif>
</cfif>
</cfoutput>
