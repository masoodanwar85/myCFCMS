<cfoutput>
<!---
	One social icon. Expects `social.key`, set by the loop in `main.cfm`.

	A partial rather than seven SVGs inline in the footer, for the same reason
	Core keeps `_link.cfm` out of `_nav.cfm`: the markup is repeated per item
	and a detail fixed in one copy gets forgotten in the other.

	Underscore-prefixed, so it reads as a partial. `ThemeService.hasView()`
	would happily find it, but nothing names it as a view and `templates()`
	only lists the templates directory, so it is not offered as a layout
	anywhere.

	Drawn rather than loaded: an icon font or an SVG sprite would be another
	request, and these are a few hundred bytes each. `currentColor` so the
	footer's own link colours — and its hover — apply without a second rule.

	`aria-hidden` on every one of them: the anchor around this carries the
	`aria-label`, and a screen reader announcing both would say the name twice.
--->
<cfswitch expression="#social.key#">

	<cfcase value="facebook">
		<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false">
			<path d="M14 9V7.5c0-.7.3-1.1 1.2-1.1H17V3.6c-.5-.1-1.4-.2-2.5-.2-2.6 0-4.1 1.4-4.1 4.3V9H7.7v3.2h2.7V21H14v-8.8h2.7l.4-3.2H14z"/>
		</svg>
	</cfcase>

	<cfcase value="instagram">
		<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true" focusable="false">
			<rect x="3.2" y="3.2" width="17.6" height="17.6" rx="5"/>
			<circle cx="12" cy="12" r="4.1"/>
			<circle cx="17.1" cy="6.9" r="1.1" fill="currentColor" stroke="none"/>
		</svg>
	</cfcase>

	<cfcase value="linkedin">
		<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false">
			<path d="M4.9 3.5a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM3.2 9.3h3.4V21H3.2zM10 9.3h3.3v1.6h.05c.46-.83 1.58-1.7 3.25-1.7 3.48 0 4.12 2.2 4.12 5.07V21h-3.4v-5.1c0-1.22-.02-2.78-1.74-2.78-1.74 0-2.01 1.32-2.01 2.69V21H10z"/>
		</svg>
	</cfcase>

	<cfcase value="x">
		<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false">
			<path d="M17.3 3h3.3l-7.2 8.2L21.8 21h-6.5l-5.1-6.2L4.4 21H1.1l7.7-8.8L1.6 3h6.6l4.6 5.7L17.3 3zm-1.2 16h1.8L7.9 4.9H6z"/>
		</svg>
	</cfcase>

	<cfcase value="tiktok">
		<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false">
			<path d="M16.1 2.6c.4 2.3 1.9 3.8 4.2 4v2.9c-1.4.1-2.8-.3-4.1-1.1v5.9c0 4.3-3.5 6.6-6.8 5.6-3.4-1-4.6-5-2.5-7.6 1.1-1.4 2.9-2.1 4.7-1.8v3c-.3-.1-.6-.1-1-.1-1.3.1-2.2 1.2-2.1 2.4.1 1.2 1.2 2.2 2.5 2.1 1.3-.1 2.2-1.1 2.2-2.4V2.6h2.9z"/>
		</svg>
	</cfcase>

	<cfcase value="youtube">
		<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false">
			<path d="M22.3 7.7c-.25-1.3-1.1-2.1-2.4-2.3C18 5.1 15.3 5.1 12 5.1s-6 0-7.9.3c-1.3.2-2.15 1-2.4 2.3C1.4 9.3 1.4 10.8 1.4 12s0 2.7.3 4.3c.25 1.3 1.1 2.1 2.4 2.3 1.9.3 4.6.3 7.9.3s6 0 7.9-.3c1.3-.2 2.15-1 2.4-2.3.3-1.6.3-3.1.3-4.3s0-2.7-.3-4.3zM9.9 15.3V8.7l5.9 3.3z"/>
		</svg>
	</cfcase>

	<cfcase value="whatsapp">
		<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false">
			<path d="M12 2.1c-5.4 0-9.8 4.4-9.8 9.8 0 1.7.45 3.4 1.3 4.9L2.1 21.9l5.2-1.4c1.4.8 3 1.2 4.7 1.2 5.4 0 9.8-4.4 9.8-9.8S17.4 2.1 12 2.1zm0 17.9c-1.5 0-3-.4-4.3-1.2l-.3-.2-3.1.8.8-3-.2-.3c-.85-1.35-1.3-2.9-1.3-4.5 0-4.5 3.7-8.2 8.2-8.2s8.2 3.7 8.2 8.2-3.7 8.2-8.2 8.2zm4.6-6c-.25-.15-1.5-.75-1.73-.83-.23-.09-.4-.13-.57.12s-.65.83-.8 1-.3.19-.55.06a6.7 6.7 0 0 1-3.3-2.9c-.25-.43.25-.4.71-1.33.08-.17.04-.31-.02-.43s-.57-1.37-.78-1.88c-.2-.49-.41-.42-.57-.43h-.48a.93.93 0 0 0-.67.31c-.23.25-.88.86-.88 2.1s.9 2.43 1.03 2.6c.12.17 1.77 2.7 4.3 3.79 1.6.69 2.22.75 3.02.63.49-.07 1.5-.61 1.71-1.21.21-.6.21-1.11.15-1.21-.06-.11-.23-.18-.48-.3z"/>
		</svg>
	</cfcase>

	<cfdefaultcase>
		<!---
			A key the theme has no icon for. A new network added to
			`FirmDetailsService.FIELDS` renders as a dot and a readable label
			rather than an empty link, so it is visibly unfinished instead of
			invisibly missing.
		--->
		<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true" focusable="false">
			<circle cx="12" cy="12" r="9"/>
			<path d="M3.5 12h17M12 3.2c2.3 2.4 2.3 15.2 0 17.6M12 3.2c-2.3 2.4-2.3 15.2 0 17.6"/>
		</svg>
	</cfdefaultcase>

</cfswitch>
</cfoutput>
