<cfoutput>
<cfif args.slides.len()>
<div class="splide hero-slider" data-hero-slider data-view="hero-slider" aria-label="Featured">
	<div class="splide__track">
		<ul class="splide__list">
			<cfset local.slideIndex = 0>
			<cfloop array="#args.slides#" index="slide">
				<cfset local.slideIndex++>
				<li class="splide__slide hero-slide is-#encodeForHTMLAttribute( slide.getHAlign() )# is-#encodeForHTMLAttribute( slide.getVAlign() )##local.slideIndex eq 1 ? ' is-active' : ''#"
					<cfif len( slide.getImageUrl() ?: "" )>
						style="background-image:url('#xmlFormat( slide.getImageUrl() )#')"
					</cfif>
					<cfif len( slide.getImageAlt() ?: "" )> role="img" aria-label="#encodeForHTMLAttribute( slide.getImageAlt() )#"</cfif>>
					<div class="hero-slide__inner">
						<div class="hero-slide__content">
							#slide.getOverlayHtml()#
						</div>
					</div>
				</li>
			</cfloop>
		</ul>
	</div>
	<cfif args.slides.len() gt 1>
		<button class="splide__toggle" type="button">
			<span class="splide__toggle__play">Play</span>
			<span class="splide__toggle__pause">Pause</span>
		</button>
	</cfif>
</div>
<script>
(function () {
	function boot() {
		if (typeof window.cmsMountHeroSliders === "function") {
			window.cmsMountHeroSliders();
		}
	}
	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", boot);
	} else {
		boot();
	}
})();
</script>
</cfif>
</cfoutput>
