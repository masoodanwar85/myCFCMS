<cfoutput>
<!---
	The marketing home page, from the "Theme C" design.

	Chosen per page from the Advanced tab, like every other template. It does
	not print the page's stored copy: a home page of this shape sells the work
	in a glance, and the article text stays in the database for whenever it is
	wanted again.

	The copy below is the design's own. Replace it in this file; it is not
	editable content, which is the trade a designed landing page makes.

	What *is* editable without touching this file: the hero, which gives way to
	the Slides module the moment a site has slides; and every one of the
	practice's own details, which come from Settings → Firm details and are
	simply left out where a site has not set them.
--->
<cfscript>
	local.firm      = args.firm ?: {};
	local.phone     = trim( local.firm.phone ?: "" );
	local.email     = trim( local.firm.email ?: "" );
	local.address   = trim( local.firm.address ?: "" );

	local.telHref = reReplace( local.phone, "[^0-9+]", "", "all" );

	// Each line is escaped on its own and then joined with the break.
	// Escaping the whole string first and replacing afterwards does not work:
	// `encodeForHTML` turns the newline into a numeric entity, so there is no
	// chr(10) left to find and the address renders as one line with the entity
	// visible in it.
	local.addressHtml = listToArray( replace( local.address, chr( 13 ), "", "all" ), chr( 10 ) )
		.map( function( line ){ return encodeForHTML( trim( line ) ); } )
		.toList( "<br>" );

	// The site's own hero, when it has one. Asked for by id so this template
	// needs no knowledge of the module beyond the one method.
	local.heroSlider = application.wirebox
		.getInstance( "SlideService@slides" )
		.renderHeroSlider( args.site.getId() );

	/*
	 * The enquiry panel's form.
	 *
	 * Expanded through the shortcode rather than built here, so the panel
	 * submits into the Contact module's inbox instead of being markup shaped
	 * like a form. `expand` takes a **context struct**, not a site id — the
	 * handler reads `siteId` out of it — and the shortcode renders the
	 * `contact-form` view in embedded mode: no heading, no wrapper, which is
	 * exactly what fits inside this panel.
	 */
	local.enquiryForm = application.wirebox
		.getInstance( "ShortcodeService@core" )
		.expand( "[contact-form]", { siteId : args.site.getId() } );
</cfscript>

<!--- ============ HERO ============ --->
<cfif len( trim( local.heroSlider ) )>
	#local.heroSlider#
<cfelse>
	<section class="hero" id="top">
		<!--- The weave and the wash stand in for the design's full-width
		      photograph until a site supplies one through Slides. --->
		<div class="hero__weave" aria-hidden="true"></div>
		<div class="hero__wash" aria-hidden="true"></div>

		<div class="hero__inner">
			<span class="eyebrow eyebrow--on-blue">Probate and deceased estates &middot; Australia-wide</span>
			<h1>Someone steady <em>beside you</em> through probate.</h1>
			<p class="hero__lead">
				We prepare the application, deal with the Supreme Court and see the estate
				through to the final distribution, in any state or territory.
			</p>
			<div class="btn-row">
				<a class="btn" href="/contact">Book a consultation</a>
				<cfif len( local.phone )>
					<a class="btn btn--ghost" href="tel:#encodeForHTMLAttribute( local.telHref )#">Call #encodeForHTML( local.phone )#</a>
				</cfif>
			</div>
		</div>
	</section>
</cfif>

<!--- ============ SERVICES ============ --->
<section class="section" id="services">
	<div class="wrap split">
		<div class="split__intro stack">
			<span class="eyebrow">Our services</span>
			<h2>Help at every stage of an estate</h2>
			<p class="muted">
				Most estates need only one of these. We will tell you which in the first
				conversation, and what it involves.
			</p>
			<div class="btn-row btn-row--tight">
				<a class="btn btn--blue btn--sm" href="/services">Explore all services</a>
				<a class="btn btn--line" href="/contact">Speak to us</a>
			</div>
		</div>

		<div class="split__body grid">
			<a class="card" href="/services/grant-of-probate">
				<span class="card__icon">
					<svg width="28" height="28" viewBox="0 0 40 40" fill="none" stroke="##FFB58A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10 5h14l7 7v23H10z"/><path d="M24 5v7h7M15 19h11M15 24h11M15 29h6"/></svg>
				</span>
				<h3>Grant of Probate</h3>
				<p>For executors named in a will. We prepare and lodge the application and answer any requisitions.</p>
				<span class="card__more">Learn more &rarr;</span>
			</a>

			<a class="card" href="/services/letters-of-administration">
				<span class="card__icon">
					<svg width="28" height="28" viewBox="0 0 40 40" fill="none" stroke="##FFB58A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="20" cy="13" r="6"/><path d="M8 34c0-7 5-11 12-11s12 4 12 11"/></svg>
				</span>
				<h3>Letters of Administration</h3>
				<p>Where there is no will, or no executor able to act. We establish who may apply and obtain the grant.</p>
				<span class="card__more">Learn more &rarr;</span>
			</a>

			<a class="card" href="/services/estate-administration">
				<span class="card__icon">
					<svg width="28" height="28" viewBox="0 0 40 40" fill="none" stroke="##FFB58A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 18 20 6l15 12"/><path d="M9 16v18h22V16"/><path d="M17 34V24h6v10"/></svg>
				</span>
				<h3>Estate Administration</h3>
				<p>After the grant: collecting assets, paying debts, transferring property and distributing to beneficiaries.</p>
				<span class="card__more">Learn more &rarr;</span>
			</a>

			<a class="card" href="/services/reseal-of-a-grant">
				<span class="card__icon">
					<svg width="28" height="28" viewBox="0 0 40 40" fill="none" stroke="##FFB58A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="20" cy="17" r="10"/><circle cx="20" cy="17" r="5"/><path d="M14 25l-3 10 9-4 9 4-3-10"/></svg>
				</span>
				<h3>Reseal of a Grant</h3>
				<p>For assets in a different state or overseas. An existing grant is recognised without starting again.</p>
				<span class="card__more">Learn more &rarr;</span>
			</a>
		</div>
	</div>
</section>

<!--- ============ FREE GUIDES ============ --->
<section class="section section--tight section--blue" id="guides">
	<div class="wrap" style="display:flex;flex-direction:column;gap:52px">
		<div style="display:flex;flex-wrap:wrap;gap:20px 64px;justify-content:space-between;align-items:flex-end">
			<div class="stack" style="max-width:640px;gap:16px">
				<span class="eyebrow">Free guides</span>
				<h2>Plain-English guides to read in your own time</h2>
			</div>
			<p style="max-width:400px">
				Short guides written by our lawyers. Download one and read it before you call us.
			</p>
		</div>

		<div class="grid grid--wide">
			<article class="card card--onblue">
				<span style="font-size:12px;letter-spacing:.2em;text-transform:uppercase;color:##FFD2B3">PDF guide</span>
				<h3>Probate explained</h3>
				<p>What a grant is, when you need one and what the court asks for.</p>
				<a class="btn btn--sm" style="align-self:flex-start;margin-top:6px" href="/guides">Download the guide</a>
			</article>

			<article class="card card--onblue">
				<span style="font-size:12px;letter-spacing:.2em;text-transform:uppercase;color:##FFD2B3">PDF guide</span>
				<h3>An executor's checklist</h3>
				<p>The first things to do, the documents to find and the mistakes to avoid.</p>
				<a class="btn btn--sm" style="align-self:flex-start;margin-top:6px" href="/guides">Download the guide</a>
			</article>

			<article class="card card--onblue">
				<span style="font-size:12px;letter-spacing:.2em;text-transform:uppercase;color:##FFD2B3">PDF guide</span>
				<h3>When there is no will</h3>
				<p>How intestacy works and who can apply for Letters of Administration.</p>
				<a class="btn btn--sm" style="align-self:flex-start;margin-top:6px" href="/guides">Download the guide</a>
			</article>
		</div>
	</div>
</section>

<!--- ============ WHY CHOOSE US ============ --->
<section class="section section--tint">
	<div class="wrap" style="display:flex;flex-direction:column;gap:56px">
		<div class="stack stack--mid" style="gap:16px">
			<span class="eyebrow">Why choose us</span>
			<h2>What you can expect when we act for you</h2>
		</div>

		<div class="grid">
			<div class="feature">
				<svg width="36" height="36" viewBox="0 0 40 40" fill="none" stroke="##1A5FA8" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="20" cy="13" r="6"/><path d="M8 34c0-7 5-11 12-11s12 4 12 11"/></svg>
				<h3>A lawyer on every file</h3>
				<p>You deal with an admitted solicitor from the first call to the final distribution.</p>
			</div>

			<div class="feature">
				<svg width="36" height="36" viewBox="0 0 40 40" fill="none" stroke="##1A5FA8" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="6" y="9" width="28" height="22" rx="2"/><path d="M6 16h28M12 25h6"/></svg>
				<h3>Costs set out upfront</h3>
				<p>You get the cost in writing before any work starts, and we tell you if it changes.</p>
			</div>

			<div class="feature">
				<svg width="36" height="36" viewBox="0 0 40 40" fill="none" stroke="##1A5FA8" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="20" cy="20" r="14"/><path d="M6 20h28M20 6c5 4 5 24 0 28M20 6c-5 4-5 24 0 28"/></svg>
				<h3>Every state and territory</h3>
				<p>We lodge in whichever Supreme Court registry the estate requires.</p>
			</div>

			<div class="feature">
				<svg width="36" height="36" viewBox="0 0 40 40" fill="none" stroke="##1A5FA8" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 10h28v18H18l-8 6v-6H6z"/><path d="M13 17h14M13 22h8"/></svg>
				<h3>No office visit needed</h3>
				<p>Everything can be handled by phone, email and post, wherever you are.</p>
			</div>
		</div>
	</div>
</section>

<!--- ============ PROCESS ============ --->
<section class="section" id="process">
	<div class="wrap" style="display:flex;flex-direction:column;gap:56px">
		<div style="display:flex;flex-wrap:wrap;gap:20px 48px;justify-content:space-between;align-items:flex-end">
			<div class="stack" style="gap:16px">
				<span class="eyebrow">How it works</span>
				<h2>A simple process, in four steps</h2>
			</div>
			<a class="btn btn--sm" href="/contact">Start with a call</a>
		</div>

		<ol class="steps">
			<li class="step">
				<div class="step__row"><span class="step__num">1</span><span class="step__rule"></span></div>
				<h3>A first conversation</h3>
				<p>Tell us what has happened. We confirm whether a grant is needed and set out the cost.</p>
			</li>
			<li class="step">
				<div class="step__row"><span class="step__num">2</span><span class="step__rule"></span></div>
				<h3>We prepare the application</h3>
				<p>We gather the documents, publish any required notice and draft the court papers.</p>
			</li>
			<li class="step">
				<div class="step__row"><span class="step__num">3</span><span class="step__rule"></span></div>
				<h3>Lodged with the court</h3>
				<p>We file in the right registry and deal with the court until the grant is issued.</p>
			</li>
			<li class="step">
				<div class="step__row"><span class="step__num">4</span></div>
				<h3>The estate is finalised</h3>
				<p>Assets are released, debts settled and each beneficiary receives their share.</p>
			</li>
		</ol>
        <hr />
        <img src="/media/2026/11/from-meeting-to-grant-of-probate-aae8ba18.png" />
	</div>
    
</section>

<!--- ============ ABOUT ============ --->
<section class="section section--tint" id="about">
	<div class="wrap about">
		<div class="about__media">
			<!---
				The site's default featured image when it has one, the design's
				flat panel when it does not. `args.branding.logoUrl` is not used
				here: a logo is not a photograph of an office.
			--->
			<div class="about__frame">A photograph of your office or team belongs here.</div>
		</div>
		<div class="about__body">
			<span class="eyebrow">About the firm</span>
			<h2>Probate is all we do, so nothing about it surprises us</h2>
			<p class="muted">
				We act for executors and administrators across Australia, and probate is the
				whole of our practice rather than a sideline to it.
			</p>
			<a class="btn btn--line" href="/about">Read more about us</a>
		</div>
	</div>
</section>

<!--- ============ CONTACT ============ --->
<section class="section section--blue" id="contact">
	<div class="wrap contact">
		<div class="contact__intro">
			<span class="eyebrow">Get in touch</span>
			<h2>Tell us what has happened. We will tell you what comes next.</h2>
			<p class="lead">
				A lawyer will read it and reply. You do not need the will or any
				paperwork ready.
			</p>

			<cfif len( local.address ) or len( local.phone ) or len( local.email )>
				<div class="contact__facts">
					<cfif len( local.address )>
						<div class="contact__fact">
							<span class="contact__label">Office</span>
							<span>#local.addressHtml#</span>
						</div>
					</cfif>
					<cfif len( local.phone )>
						<div class="contact__fact">
							<span class="contact__label">Phone</span>
							<a href="tel:#encodeForHTMLAttribute( local.telHref )#">#encodeForHTML( local.phone )#</a>
						</div>
					</cfif>
					<cfif len( local.email )>
						<div class="contact__fact">
							<span class="contact__label">Email</span>
							<a href="mailto:#encodeForHTMLAttribute( local.email )#">#encodeForHTML( local.email )#</a>
						</div>
					</cfif>
				</div>
			</cfif>
		</div>

		<!---
			The panel is only drawn when there is a form to put in it. The
			shortcode answers with an empty string on a site that has no
			contact form yet — correct of it, but an empty white box with a
			heading and nothing under it is worse than no box at all.
		--->
		<cfif len( trim( local.enquiryForm ) )>
			<div class="contact__panel">
				<h3>Book a consultation</h3>
				#local.enquiryForm#
			</div>
		<cfelseif len( local.phone ) or len( local.email )>
			<div class="contact__panel">
				<h3>Book a consultation</h3>
				<p class="muted">Call or email and a lawyer will come back to you.</p>
				<div class="btn-row">
					<cfif len( local.phone )>
						<a class="btn" href="tel:#encodeForHTMLAttribute( local.telHref )#">Call #encodeForHTML( local.phone )#</a>
					</cfif>
					<cfif len( local.email )>
						<a class="btn btn--line" href="mailto:#encodeForHTMLAttribute( local.email )#">Email us</a>
					</cfif>
				</div>
			</div>
		</cfif>
	</div>
</section>

<!--- ============ FAQ ============ --->
<section class="section" id="faq">
	<div class="wrap">
		<div class="stack" style="margin-bottom:40px">
			<span class="eyebrow">Common questions</span>
			<h2>What executors ask us first</h2>
			<p class="muted">If yours is not here, ask it directly and a lawyer will answer.</p>
		</div>

		<div class="faq-list">
			<details class="faq-item" open>
				<summary>What is probate?<span class="faq-plus" aria-hidden="true">+</span></summary>
				<div class="faq-answer">
					Probate is the Supreme Court's formal recognition that a will is valid and that
					the executor named in it has authority to deal with the estate.
				</div>
			</details>

			<details class="faq-item">
				<summary>Is probate always required?<span class="faq-plus" aria-hidden="true">+</span></summary>
				<div class="faq-answer">
					Not always. It depends on what the person owned and how it was held. We will
					tell you at the outset whether you need one.
				</div>
			</details>

			<details class="faq-item">
				<summary>What if there is no will?<span class="faq-plus" aria-hidden="true">+</span></summary>
				<div class="faq-answer">
					The estate is distributed under the intestacy rules of the relevant state or
					territory, and the next of kin applies for Letters of Administration.
				</div>
			</details>

			<details class="faq-item">
				<summary>How long does it take?<span class="faq-plus" aria-hidden="true">+</span></summary>
				<div class="faq-answer">
					It varies between states, and with the court's workload and the
					complexity of the estate. We give you a realistic range at the outset.
				</div>
			</details>

			<details class="faq-item">
				<summary>How are your fees charged?<span class="faq-plus" aria-hidden="true">+</span></summary>
				<div class="faq-answer">
					You get the cost in writing before any work starts. Ask us for a quote
					and we will set out what is included.
				</div>
			</details>
		</div>
	</div>
</section>

<!--- ============ CLOSING CTA ============ --->
<section class="cta-band">
	<div class="cta-band__inner">
		<h2>Speak with a probate lawyer today</h2>
		<div class="btn-row" style="padding-top:0">
			<cfif len( local.phone )>
				<a class="btn" href="tel:#encodeForHTMLAttribute( local.telHref )#">Call #encodeForHTML( local.phone )#</a>
			</cfif>
			<a class="btn btn--line" href="/contact">Send an enquiry</a>
		</div>
	</div>
</section>
</cfoutput>
