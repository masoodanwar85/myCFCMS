<cfoutput>
<cfset editing = isObject( prc.page )>
<cfset p       = prc.page>

<!---
	Three tabs rather than one long form. The Content tab is what an author uses
	every day; SEO and Advanced are occasional and mostly optional, and putting
	twenty more inputs in front of someone writing a page makes the common task
	worse to serve the rare one.

	There is no Navigation tab. Menu order and parentage looked like navigation
	and are not: the Menus screen owns what appears in a site's menu, and a page
	that also had its own "navigation" settings gave two answers to one
	question. What was on that tab has moved to where it belongs — parent next
	to the slug, because together they are the URL, and order at the foot of the
	page, because it sequences the tree.

	Plain CSS tabs, no framework: the panels are all in the DOM and all inside
	the one form, so switching tabs never loses what has been typed and a save
	posts every field whichever tab is showing.
--->
<h1>#editing ? "Edit page" : "New page"#</h1>
<cfif editing>
	<p class="sub">
		<code>/#encodeForHTML( p.getPath() )#</code>
		<cfif len( p.getScheduleState() )>
			<span class="pill off">#p.getScheduleState()#</span>
		</cfif>
	</p>
</cfif>

<form method="post" action="#editing ? '/admin/pages/update/' & p.getId() : '/admin/pages/create'#">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
	<!---
		Tells the handler the SEO tab was rendered, so an unticked checkbox can
		be read as `false` rather than as "left alone". Without it there is no
		way to tell "the author cleared this" from "this form did not include
		the field".
	--->
	<input type="hidden" name="seoTabPresent" value="1">

	<div class="tabs">
		<input type="radio" name="pageTab" id="tab-content" checked>
		<label for="tab-content">Content</label>

		<input type="radio" name="pageTab" id="tab-seo">
		<label for="tab-seo">SEO</label>

		<input type="radio" name="pageTab" id="tab-advanced">
		<label for="tab-advanced">Advanced</label>

		<!-- ------------------------------------------------------ content -->
		<section class="tab-panel" data-for="tab-content">
			<!---
				Tells the handler this tab was rendered, so an unticked
				checkbox below can be read as `false` rather than as "the form
				did not include the field". Same reason `seoTabPresent` exists,
				and separate from it so the two tabs stay independent.

				Inside the panel, not next to the radios: a direct-child input
				of `.tabs` shifts every panel by one. See `_styles.cfm`.
			--->
			<input type="hidden" name="contentTabPresent" value="1">

			<label for="title">Title</label>
			<input type="text" id="title" name="title" required
			       value="#editing ? encodeForHTMLAttribute( p.getTitle() ) : ''#">

			<!---
				A display switch, not a second title. With it off the title is
				still the browser tab, the menu label, the breadcrumb and the
				`<title>` tag — only the on-page heading goes away.
			--->
			<div class="checks">
				<label>
					<input type="checkbox" name="showHeading"<cfif !editing || p.getShowHeading()> checked</cfif>>
					Show this title as a heading on the page
				</label>
			</div>
			<p class="muted" style="font-size:.8rem">
				Turn off for a page whose content already opens with its own headline &mdash; a
				landing page with a hero, say &mdash; so the title is not printed twice. The page
				then has no <code>&lt;h1&gt;</code> of its own, so write one in the content using
				<strong>Page heading</strong> in the editor's style menu.
			</p>

			<!---
				The trap this pair creates. Two `<h1>`s on a page is not an
				error anything will report: it renders, and it reads as two
				competing titles to a screen reader and to a crawler. Cheap to
				spot here — the content is already in hand — and much harder to
				notice once the page is live.

				`findNoCase` on the raw markup rather than parsing it: this is a
				hint, and a hint that is occasionally over-eager costs nothing,
				while a parser on every form render costs something every time.
			--->
			<cfif editing && p.getShowHeading() && findNoCase( "<h1", p.getContent() ?: "" )>
				<p class="flash error" style="font-size:.8rem">
					This page's content already contains a <code>&lt;h1&gt;</code>, and the title is
					also being shown as a heading &mdash; so the page has two top-level headings.
					Untick the box above, or change the one in the content to <strong>Heading</strong>.
				</p>
			</cfif>

			<div class="grid2">
				<div>
					<label for="slug">Slug</label>
					<input type="text" id="slug" name="slug" placeholder="derived from the title"
					       value="#editing ? encodeForHTMLAttribute( p.getSlug() ) : ''#">
					<cfif editing>
						<p class="muted" style="font-size:.8rem">Changing this moves every page beneath it too.</p>
					</cfif>
				</div>
				<div>
					<!---
						Parent sits with the slug, not under a "Navigation"
						heading, because the two together *are* the URL:
						`about` under `About` is `/about/team`. It decides where
						the page lives, not where it appears in a menu — that is
						what the Menus screen is for.
					--->
					<label for="parentId">Parent</label>
					<select id="parentId" name="parentId">
						<option value="">(top level)</option>
						<cfloop array="#prc.parents#" index="candidate">
							<cfset selected = editing && !p.isRoot() && p.getParentId() eq candidate.getId()>
							<option value="#candidate.getId()#" #selected ? 'selected' : ''#>#encodeForHTML( candidate.getPath() )#</option>
						</cfloop>
					</select>
					<p class="muted" style="font-size:.8rem">
						Sets this page's address. Moving it rewrites the URL of every page beneath it.
					</p>
				</div>
			</div>

			<label for="content">Content</label>
			<textarea id="content" name="content" data-editor>#editing ? encodeForHTML( p.getContent() ?: "" ) : ""#</textarea>

			<label for="sortOrder">Order</label>
			<input type="text" id="sortOrder" name="sortOrder" style="max-width:8rem"
			       value="#editing ? p.getSortOrder() : 0#">
			<p class="muted" style="font-size:.8rem">
				Lower comes first, among pages with the same parent. Used by the page tree and by the
				<strong>automatic</strong> navigation a site falls back to &mdash; once you build a
				<a href="/admin/menus">menu</a>, that menu's own order wins.
			</p>
		</section>

		<!-- ---------------------------------------------------------- seo -->
		<section class="tab-panel" data-for="tab-seo">
			<label for="metaTitle">Meta title <span class="muted">&lt;title&gt; &mdash; falls back to the page title</span></label>
			<input type="text" id="metaTitle" name="metaTitle"
			       value="#editing ? encodeForHTMLAttribute( p.getMetaTitle() ?: '' ) : ''#">

			<label for="metaDescription">Meta description</label>
			<textarea id="metaDescription" name="metaDescription" rows="3">#editing ? encodeForHTML( p.getMetaDescription() ?: "" ) : ""#</textarea>

			<label for="metaKeywords">Meta keywords</label>
			<input type="text" id="metaKeywords" name="metaKeywords"
			       value="#editing ? encodeForHTMLAttribute( p.getMetaKeywords() ?: '' ) : ''#">
			<p class="muted" style="font-size:.8rem">
				Kept for internal search and older tools. No major search engine has used this since about 2009.
			</p>

			<label for="canonicalUrl">Canonical URL <span class="muted">blank = worked out from the primary domain</span></label>
			<input type="text" id="canonicalUrl" name="canonicalUrl" placeholder="https://example.com/preferred-page"
			       value="#editing ? encodeForHTMLAttribute( p.getCanonicalUrl() ?: '' ) : ''#">

			<div class="grid2">
				<div class="checks">
					<label>
						<input type="checkbox" name="robotsIndex" #!editing || p.getRobotsIndex() ? 'checked' : ''#>
						Allow indexing <span class="muted">(index / noindex)</span>
					</label>
				</div>
				<div class="checks">
					<label>
						<input type="checkbox" name="robotsFollow" #!editing || p.getRobotsFollow() ? 'checked' : ''#>
						Follow links <span class="muted">(follow / nofollow)</span>
					</label>
				</div>
			</div>

			<h2>Social / Open Graph</h2>

			<div class="grid2">
				<div>
					<label for="ogTitle">OG title <span class="muted">falls back to the meta title</span></label>
					<input type="text" id="ogTitle" name="ogTitle"
					       value="#editing ? encodeForHTMLAttribute( p.getOgTitle() ?: '' ) : ''#">
				</div>
				<div>
					<label for="ogImage">OG image URL</label>
					<input type="text" id="ogImage" name="ogImage" placeholder="/media/2026/08/preview.png"
					       value="#editing ? encodeForHTMLAttribute( p.getOgImage() ?: '' ) : ''#">
				</div>
			</div>

			<label for="ogDescription">OG description <span class="muted">falls back to the meta description</span></label>
			<textarea id="ogDescription" name="ogDescription" rows="3">#editing ? encodeForHTML( p.getOgDescription() ?: "" ) : ""#</textarea>

			<div class="grid2">
				<div>
					<label for="ogType">OG type</label>
					<select id="ogType" name="ogType">
						<cfloop list="website,article,profile,book,video.other,music.song" index="option">
							<option value="#option#" #editing && p.getOgType() eq option ? 'selected' : ''#>#option#</option>
						</cfloop>
					</select>
				</div>
				<div>
					<label for="twitterCard">Twitter card</label>
					<select id="twitterCard" name="twitterCard">
						<cfloop list="summary_large_image,summary,app,player" index="option">
							<option value="#option#" #editing && p.getTwitterCard() eq option ? 'selected' : ''#>#option#</option>
						</cfloop>
					</select>
					<p class="muted" style="font-size:.8rem">
						A large-image card without an image shows a blank panel, so it falls back to
						<code>summary</code> when there is none.
					</p>
				</div>
			</div>

			<h2>Sitemap</h2>

			<div class="grid3">
				<div class="checks">
					<label>
						<input type="checkbox" name="sitemapInclude" #!editing || p.getSitemapInclude() ? 'checked' : ''#>
						Include in sitemap.xml
					</label>
				</div>
				<div>
					<label for="sitemapPriority">Priority</label>
					<input type="text" id="sitemapPriority" name="sitemapPriority"
					       value="#editing ? p.getSitemapPriority() : '0.5'#">
					<p class="muted" style="font-size:.8rem">0.0 to 1.0, relative to this site's other pages.</p>
				</div>
				<div>
					<label for="sitemapChangefreq">Change frequency</label>
					<select id="sitemapChangefreq" name="sitemapChangefreq">
						<cfloop list="always,hourly,daily,weekly,monthly,yearly,never" index="option">
							<option value="#option#" #editing && p.getSitemapChangefreq() eq option ? 'selected' : ''#>#option#</option>
						</cfloop>
					</select>
				</div>
			</div>
			<p class="muted" style="font-size:.8rem">
				A page marked <strong>noindex</strong> is left out of the sitemap whatever this says &mdash;
				advertising a page you have asked not to be indexed is a contradiction a crawler resolves
				however it likes.
			</p>
		</section>

		<!-- ----------------------------------------------------- advanced -->
		<section class="tab-panel" data-for="tab-advanced">
			<!---
				Only when the theme offers templates. A picker with one option
				that says "Standard" is a control that does nothing, and a
				client whose theme has no templates should never see it.
			--->
			<cfif prc.templates.len()>
				<label for="template">Template</label>
				<select id="template" name="template">
					<option value="">Standard page</option>
					<cfloop array="#prc.templates#" index="templateName">
						<option value="#encodeForHTMLAttribute( templateName )#"
						        <cfif editing && ( p.getTemplate() ?: "" ) eq templateName>selected</cfif>>#encodeForHTML( templateName )#</option>
					</cfloop>
				</select>
				<p class="muted" style="font-size:.8rem">
					Templates are built by your developer and live in the theme &mdash; a page that needs
					its own logic, like a calculator or a live listing, uses one instead of the standard
					layout. The page's title, SEO settings and menu position work exactly the same either
					way. Choosing <strong>Standard page</strong> renders the content as usual.
				</p>
			</cfif>

			<div class="grid2">
				<div>
					<label for="publishFrom">Publish from</label>
					<input type="datetime-local" id="publishFrom" name="publishFrom"
					       value="#editing && !isNull( p.getPublishFrom() ) ? dateTimeFormat( p.getPublishFrom(), 'yyyy-mm-dd''T''HH:nn' ) : ''#">
				</div>
				<div>
					<label for="publishUntil">Publish until</label>
					<input type="datetime-local" id="publishUntil" name="publishUntil"
					       value="#editing && !isNull( p.getPublishUntil() ) ? dateTimeFormat( p.getPublishUntil(), 'yyyy-mm-dd''T''HH:nn' ) : ''#">
				</div>
			</div>
			<p class="muted" style="font-size:.8rem">
				Both optional. A page still has to be <strong>published</strong> to appear &mdash; these
				narrow the window, they do not open it. Times are in the site's timezone
				(#encodeForHTML( prc.currentSite.getTimezone() )#).
			</p>

			<cfif prc.mayPostRawHtml>
				<h2>Raw markup</h2>
				<p class="flash warn">
					Everything below is written into the page <strong>exactly as typed</strong>, with no
					sanitising. It can run scripts on every visitor's browser. You are seeing these fields
					because you hold <code>content.unfiltered</code>.
				</p>

				<label for="headMarkup">Extra &lt;head&gt; markup</label>
				<textarea id="headMarkup" name="headMarkup" data-code rows="5">#editing ? encodeForHTML( p.getHeadMarkup() ?: "" ) : ""#</textarea>

				<label for="bodyMarkup">Extra markup before &lt;/body&gt;</label>
				<textarea id="bodyMarkup" name="bodyMarkup" data-code rows="5">#editing ? encodeForHTML( p.getBodyMarkup() ?: "" ) : ""#</textarea>

				<label for="jsonLd">JSON-LD structured data</label>
				<textarea id="jsonLd" name="jsonLd" data-code rows="6" placeholder='{ "@context": "https://schema.org", "@type": "Organization" }'>#editing ? encodeForHTML( p.getJsonLd() ?: "" ) : ""#</textarea>
				<p class="muted" style="font-size:.8rem">
					Must be valid JSON. The <code>&lt;script&gt;</code> wrapper is added for you.
				</p>
			<cfelse>
				<h2>Raw markup</h2>
				<p class="muted">
					Custom <code>&lt;head&gt;</code> markup, body markup and JSON-LD are written into the page
					without sanitising, so they need the <code>content.unfiltered</code> permission.
					Ask an owner if you need them.
				</p>
			</cfif>
		</section>
	</div>

	<div class="actions-bar">
		<button type="submit">#editing ? "Save page" : "Create page"#</button>
		<a class="btn secondary" href="/admin/pages">Cancel</a>
	</div>
</form>
</cfoutput>
