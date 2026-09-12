<cfoutput>
<!---
	A first-visit dialog, shipped by Core and included from `_body.cfm`.

	Themes already include that file before `</body>`, so a notice appears on
	every public page without a line of theme code changing. The dialog is
	hidden until a small script decides this browser has not seen it; a visitor
	with JavaScript off never sees it, which is the right failure for a popup.

	Expects `args.notice`, built by SiteNoticeService. Degrades to emitting
	nothing rather than throwing, so a layout rendered outside the front
	controller — a preview, a test — is not a broken page.
--->
<cfset local.notice = args.notice ?: {}>
<cfif local.notice.active ?: false>
	<div id="cms-site-notice"
	     class="cms-site-notice"
	     hidden
	     data-storage-key="#encodeForHTMLAttribute( local.notice.storageKey )#">
		<div class="cms-site-notice__backdrop" data-notice-dismiss></div>
		<div class="cms-site-notice__dialog"
		     role="dialog"
		     aria-modal="true"
		     aria-labelledby="cms-site-notice-title"
		     tabindex="-1">
			<button type="button"
			        class="cms-site-notice__close"
			        data-notice-dismiss
			        aria-label="Close">&times;</button>
			<h2 id="cms-site-notice-title">#encodeForHTML( local.notice.heading )#</h2>
			<p>#encodeForHTML( local.notice.body )#</p>
			<cfif len( local.notice.ctaUrl )>
				<a class="cms-site-notice__cta"
				   href="#encodeForHTMLAttribute( local.notice.ctaUrl )#">
					#encodeForHTML( len( local.notice.ctaLabel ) ? local.notice.ctaLabel : "Continue" )#
				</a>
			</cfif>
		</div>
	</div>
	<style>
		.cms-site-notice{ position:fixed; inset:0; z-index:10000; }
		.cms-site-notice[hidden]{ display:none !important; }
		.cms-site-notice__backdrop{ position:absolute; inset:0; background:rgba(15,42,74,.55); }
		.cms-site-notice__dialog{
			position:relative; margin:min(22vh, 7rem) auto 0; max-width:32rem;
			width:calc(100% - 2rem); background:##fff;
			color:var(--brand-primary, ##0f2a4a);
			border-radius:12px; padding:2.1rem 1.85rem 1.85rem;
			box-shadow:0 24px 60px rgba(15,42,74,.28);
			font: 1rem/1.55 var(--brand-font-body, system-ui, sans-serif);
		}
		.cms-site-notice__dialog h2{
			margin:0 0 .7rem; font: 700 1.45rem/1.2 var(--brand-font-heading, Georgia, serif);
			letter-spacing:-.02em;
		}
		.cms-site-notice__dialog p{ margin:0; }
		.cms-site-notice__close{
			position:absolute; top:.45rem; right:.55rem; width:2.2rem; height:2.2rem;
			border:0; background:transparent; color:inherit; font-size:1.6rem; line-height:1;
			cursor:pointer; border-radius:6px;
		}
		.cms-site-notice__close:hover,
		.cms-site-notice__close:focus-visible{ background:rgba(15,42,74,.08); }
		.cms-site-notice__cta{
			display:inline-block; margin-top:1.35rem; padding:.7rem 1.15rem;
			background:var(--brand-accent, ##c19b43); color:var(--brand-primary, ##0f2a4a);
			font-weight:700; text-decoration:none; border-radius:8px;
		}
		.cms-site-notice__cta:hover{ filter:brightness(1.05); }
		body.cms-site-notice-open{ overflow:hidden; }
	</style>
	<script>
	(function () {
		var root = document.getElementById( "cms-site-notice" );
		if ( !root ) {
			return;
		}

		var key = root.getAttribute( "data-storage-key" );
		var remembered = false;

		try {
			remembered = !!( window.localStorage && window.localStorage.getItem( key ) );
		} catch ( e ) {}

		if ( remembered ) {
			return;
		}

		root.hidden = false;
		document.body.classList.add( "cms-site-notice-open" );

		var dialog = root.querySelector( ".cms-site-notice__dialog" );
		if ( dialog && dialog.focus ) {
			dialog.focus();
		}

		try {
			window.localStorage.setItem( key, "1" );
		} catch ( e ) {}

		function dismiss() {
			root.hidden = true;
			document.body.classList.remove( "cms-site-notice-open" );
		}

		root.addEventListener( "click", function ( e ) {
			if ( e.target.closest( "[data-notice-dismiss]" ) ) {
				dismiss();
			}
		} );

		document.addEventListener( "keydown", function ( e ) {
			if ( e.key === "Escape" && !root.hidden ) {
				dismiss();
			}
		} );
	})();
	</script>
</cfif>
</cfoutput>
