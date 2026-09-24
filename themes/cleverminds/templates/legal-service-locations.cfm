<cfscript>
	// Tabs and town names come from `services` / `locations` /
	// `services_locations`. The Legal Services menu is a different thing and
	// is not read here. A service with no attached towns is omitted.
	local.areas  = application.wirebox.getInstance( "ServiceAreaService@serviceareas" );
	local.panels = local.areas.getPanelsForSite( args.site.getId() );
</cfscript>
<style>
	/* Scoped to this template. The ordinary page stylesheet styles every
	   `main .section ul li` as a gold tick and every link as an underlined
	   navy title — which is what collapsed this widget into a stacked list. */
	main .section .areas-serve,
	.areas-serve {
		display: flex !important;
		flex-direction: row;
		align-items: stretch;
		width: 100%;
		margin: 0;
		padding: 0;
		border: 1px solid var(--paper-line);
		border-radius: 8px;
		overflow: hidden;
		background: var(--white);
		box-shadow: none;
	}
	.areas-serve__nav {
		flex: 0 0 32%;
		width: 32%;
		max-width: 22rem;
		background: var(--white);
		padding: 1.75rem 1.6rem 1.4rem;
		border-right: 1px solid var(--paper-line);
		box-sizing: border-box;
	}
	main .section .areas-serve__heading,
	.areas-serve__heading {
		font-family: var(--body) !important;
		font-weight: 700 !important;
		font-size: 1.65rem !important;
		color: var(--eucalypt) !important;
		letter-spacing: -0.01em;
		margin: 0 0 1.15rem !important;
		padding: 0 !important;
		border: 0 !important;
		display: block !important;
		text-align: left !important;
		background: none !important;
	}
	.areas-serve__list {
		display: block !important;
		margin: 0 !important;
		padding: 0 !important;
		list-style: none !important;
	}
	.areas-serve__tab {
		-webkit-appearance: none !important;
		appearance: none !important;
		display: flex !important;
		align-items: center;
		justify-content: space-between;
		gap: 0.75rem;
		width: 100% !important;
		margin: 0 !important;
		padding: 0.9rem 0.1rem !important;
		background: transparent !important;
		background-color: transparent !important;
		border: 0 !important;
		border-bottom: 1px solid var(--paper-line) !important;
		border-radius: 0 !important;
		box-shadow: none !important;
		transform: none !important;
		font-family: var(--body) !important;
		font-size: 1rem !important;
		font-weight: 500 !important;
		color: var(--ink) !important;
		text-align: left !important;
		letter-spacing: 0 !important;
		text-transform: none !important;
		cursor: pointer;
		line-height: 1.35;
	}
	.areas-serve__tab::before,
	.areas-serve__tab::after {
		content: none !important;
		display: none !important;
	}
	.areas-serve__tab::after {
		content: "" !important;
		display: block !important;
		flex: none;
		width: 0.42rem;
		height: 0.42rem;
		border: 0 !important;
		border-right: 2px solid var(--sage) !important;
		border-bottom: 2px solid var(--sage) !important;
		background: none !important;
		transform: rotate(-45deg);
	}
	.areas-serve__tab.is-active {
		color: var(--brass) !important;
		font-weight: 700 !important;
	}
	.areas-serve__tab.is-active::after {
		border-right-color: var(--brass) !important;
		border-bottom-color: var(--brass) !important;
	}
	.areas-serve__tab:hover {
		color: var(--eucalypt) !important;
		background: transparent !important;
		transform: none !important;
	}
	.areas-serve__pane {
		flex: 1 1 auto;
		min-width: 0;
		background: var(--sage-tint);
		padding: 1.8rem 1.9rem 2.1rem;
		box-sizing: border-box;
	}
	.areas-serve__panel {
		display: none !important;
	}
	.areas-serve__panel.is-active {
		display: block !important;
	}
	main .section .areas-serve__intro,
	.areas-serve__intro {
		color: var(--eucalypt) !important;
		font-family: var(--body) !important;
		font-size: 1rem !important;
		line-height: 1.55;
		margin: 0 0 1.05rem !important;
		padding: 0 !important;
		text-align: left !important;
		hyphens: none !important;
		max-width: none !important;
		background: none !important;
	}
	main .section .areas-serve__banner,
	.areas-serve__banner {
		display: block !important;
		background: var(--ink) !important;
		color: var(--white) !important;
		text-align: center !important;
		font-family: var(--body) !important;
		font-weight: 600 !important;
		font-size: 0.92rem !important;
		letter-spacing: 0.02em;
		padding: 0.72rem 1.2rem !important;
		border-radius: 999px !important;
		margin: 0 0 1.55rem !important;
		border: 0 !important;
	}
	.areas-serve__area {
		margin: 0 0 1.35rem !important;
		padding: 0 !important;
		border: 0 !important;
		background: none !important;
	}
	.areas-serve__area:last-child {
		margin-bottom: 0 !important;
	}
	main .section .areas-serve__area-name,
	.areas-serve__area-name {
		font-family: var(--body) !important;
		font-weight: 700 !important;
		font-size: 1.05rem !important;
		line-height: 1.3 !important;
		color: var(--eucalypt) !important;
		letter-spacing: 0 !important;
		text-transform: none !important;
		margin: 0 0 0.7rem !important;
		padding: 0 !important;
		border: 0 !important;
		display: block !important;
		text-align: left !important;
		background: none !important;
	}
	.areas-serve__grid {
		display: grid !important;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 1.2rem 1.5rem;
		margin: 0 !important;
		padding: 0 !important;
		list-style: none !important;
	}
	main .section .areas-serve__place-link,
	.areas-serve__place-link {
		display: grid !important;
		grid-template-columns: 0.85rem 1fr;
		grid-template-rows: auto auto;
		column-gap: 0.4rem;
		align-items: start;
		text-decoration: none !important;
		color: inherit !important;
		background: none !important;
		border: 0 !important;
		padding: 0 !important;
		box-shadow: none !important;
	}
	.areas-serve__place-link::before {
		content: "–" !important;
		display: block !important;
		grid-row: 1 / span 2;
		position: static !important;
		left: auto !important;
		top: auto !important;
		width: auto !important;
		height: auto !important;
		color: var(--ink-soft) !important;
		font-weight: 400 !important;
		font-family: var(--body) !important;
		line-height: 1.3;
		padding-top: 0.12em;
		background: none !important;
	}
	.areas-serve__svc {
		grid-column: 2;
		display: block;
		font-size: 0.78rem;
		color: var(--ink-soft);
		line-height: 1.3;
		font-weight: 400;
	}
	.areas-serve__place {
		grid-column: 2;
		display: block;
		font-weight: 700;
		font-size: 1rem;
		color: var(--ink);
		line-height: 1.3;
	}
	main .section .areas-serve__place-link:hover,
	.areas-serve__place-link:hover {
		color: inherit !important;
		text-decoration: none !important;
	}
	.areas-serve__place-link:hover .areas-serve__place {
		color: var(--brass);
	}
	@media (max-width: 900px) {
		main .section .areas-serve,
		.areas-serve {
			flex-direction: column;
		}
		.areas-serve__nav {
			flex: none;
			width: 100%;
			max-width: none;
			border-right: 0;
			border-bottom: 1px solid var(--paper-line);
		}
		.areas-serve__list {
			display: flex !important;
			overflow-x: auto;
		}
		.areas-serve__tab {
			flex: none;
			width: auto !important;
			white-space: nowrap;
			border-bottom: 0 !important;
			border-right: 1px solid var(--paper-line) !important;
			padding: 0.7rem 1rem !important;
		}
		.areas-serve__grid {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}
	@media (max-width: 560px) {
		.areas-serve__grid {
			grid-template-columns: 1fr;
		}
	}
</style>
<cfoutput>
<cfif args.breadcrumb.len() gt 1>
	<div class="wrap">
		<p class="crumbs">
			<cfloop array="#args.breadcrumb#" index="crumb">
				<cfif crumb.getId() neq args.page.getId()>
					<a href="/#xmlFormat( crumb.getPath() )#">#encodeForHTML( crumb.getTitle() )#</a>
					<span aria-hidden="true">&rsaquo;</span>
				<cfelse>
					<span aria-current="page">#encodeForHTML( crumb.getTitle() )#</span>
				</cfif>
			</cfloop>
		</p>
	</div>
</cfif>

<section class="section">
	<div class="wrap">
		<cfif args.page.getShowHeading()>
			<h1>#encodeForHTML( args.page.getTitle() )#</h1>
		</cfif>
		<cfif len( trim( args.page.getContent() ?: "" ) )>
			#args.page.getContent()#
		</cfif>

		<cfif !arrayLen( local.panels )>
			<p>No published legal services were found to list locations for.</p>
		<cfelse>
			<div class="areas-serve" data-areas-serve>
				<nav class="areas-serve__nav" aria-label="Services">
					<h2 class="areas-serve__heading">Areas We Serve</h2>
					<div class="areas-serve__list" role="tablist">
						<cfloop array="#local.panels#" index="local.i" item="local.panel">
							<button type="button"
								class="areas-serve__tab<cfif local.i eq 1> is-active</cfif>"
								id="areas-tab-#encodeForHTMLAttribute( local.panel.slug )#"
								role="tab"
								aria-selected="#local.i eq 1 ? 'true' : 'false'#"
								aria-controls="areas-panel-#encodeForHTMLAttribute( local.panel.slug )#"
								data-areas-tab="#encodeForHTMLAttribute( local.panel.slug )#">
								#encodeForHTML( local.panel.title )#
							</button>
						</cfloop>
					</div>
				</nav>

				<div class="areas-serve__pane">
					<cfloop array="#local.panels#" index="local.i" item="local.panel">
						<div class="areas-serve__panel<cfif local.i eq 1> is-active</cfif>"
							id="areas-panel-#encodeForHTMLAttribute( local.panel.slug )#"
							role="tabpanel"
							aria-labelledby="areas-tab-#encodeForHTMLAttribute( local.panel.slug )#"
							data-areas-panel="#encodeForHTMLAttribute( local.panel.slug )#">
							<p class="areas-serve__intro">
								Will Creator serves families across New South Wales, including the locations below:
							</p>
							<p class="areas-serve__banner">Serving Sydney, Regional NSW &amp; the Central Coast</p>
							<cfif arrayLen( local.panel.groups ?: [] )>
								<cfloop array="#local.panel.groups#" item="local.group">
                                	<section class="areas-serve__area">
										<h3 class="areas-serve__area-name">#encodeForHTML( local.group.name )#</h3>
										<div class="areas-serve__grid">
											<cfloop array="#local.group.places#" item="local.place">
                                            	<cfset this_url = '/' & encodeForHTMLAttribute( local.panel.slug ) />
                                                <cfif len(trim(local.place.href))>
	                                            	<cfset this_url = this_url & '/' & listRest(local.place.href,'/') />
                                                </cfif>
												<a class="areas-serve__place-link" href="#encodeForHTMLAttribute( this_url )#">
													<span class="areas-serve__svc">#encodeForHTML( local.panel.title )#</span>
													<span class="areas-serve__place">#encodeForHTML( local.place.label )#</span>
												</a>
											</cfloop>
										</div>
									</section>
								</cfloop>
							<cfelse>
								<p class="areas-serve__empty">
									See our
									<a href="#encodeForHTMLAttribute( local.panel.href )#">#encodeForHTML( local.panel.title )#</a>
									page for details.
								</p>
							</cfif>
						</div>
					</cfloop>
				</div>
			</div>
		</cfif>
	</div>
</section>

<script>
(function () {
	document.querySelectorAll( "[data-areas-serve]" ).forEach( function ( root ) {
		var tabs   = Array.prototype.slice.call( root.querySelectorAll( "[data-areas-tab]" ) );
		var panels = Array.prototype.slice.call( root.querySelectorAll( "[data-areas-panel]" ) );

		if ( !tabs.length ) {
			return;
		}

		function show( slug ) {
			tabs.forEach( function ( tab ) {
				var on = tab.getAttribute( "data-areas-tab" ) === slug;
				tab.classList.toggle( "is-active", on );
				tab.setAttribute( "aria-selected", on ? "true" : "false" );
				tab.tabIndex = on ? 0 : -1;
			} );
			panels.forEach( function ( panel ) {
				var on = panel.getAttribute( "data-areas-panel" ) === slug;
				panel.classList.toggle( "is-active", on );
			} );
		}

		tabs.forEach( function ( tab, index ) {
			tab.addEventListener( "click", function () {
				show( tab.getAttribute( "data-areas-tab" ) );
			} );
			tab.addEventListener( "keydown", function ( event ) {
				var next = index;
				if ( event.key === "ArrowDown" || event.key === "ArrowRight" ) {
					next = ( index + 1 ) % tabs.length;
				} else if ( event.key === "ArrowUp" || event.key === "ArrowLeft" ) {
					next = ( index - 1 + tabs.length ) % tabs.length;
				} else if ( event.key === "Home" ) {
					next = 0;
				} else if ( event.key === "End" ) {
					next = tabs.length - 1;
				} else {
					return;
				}
				event.preventDefault();
				tabs[ next ].focus();
				show( tabs[ next ].getAttribute( "data-areas-tab" ) );
			} );
		} );
	} );
})();
</script>
</cfoutput>
