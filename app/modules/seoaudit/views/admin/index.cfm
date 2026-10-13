<cfoutput>
<!---
	The SEO report.

	Two tabs over one set of findings, because there are two different jobs:

	  * By problem — "what is wrong with this site", read once after a run.
	  * By page    — "what do I fix here", read while editing.

	Same data, grouped twice in SQL rather than reshuffled in the view.

	Severity is always shown as a word as well as a colour. A report that
	distinguishes an error from a notice only by hue is unreadable to anyone who
	cannot tell those hues apart, and this one is a list of things a person is
	being asked to prioritise.
--->
<h1>SEO</h1>
<p class="sub">
	On-page problems across every public URL of #encodeForHTML( prc.currentSite.getName() )#.
</p>

<div class="adm-toolbar">
	<cfif prc.canRun>
		<form class="inline" method="post" action="/admin/seo/run">
			<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
			<button type="submit">Run audit</button>
		</form>
	</cfif>
	<a class="btn secondary" href="/" target="_blank" rel="noopener">View site &nearr;</a>

	<cfif !isNull( prc.audit ) && isObject( prc.audit )>
		<span class="adm-count">
			#dateTimeFormat( prc.audit.getStartedAt(), "d mmm yyyy, HH:nn" )#
			&middot; #prc.audit.getUrlCount()# URLs
			<cfif len( prc.audit.getDuration() )>&middot; #prc.audit.getDuration()#</cfif>
		</span>
	</cfif>
</div>

<cfif !isNull( prc.audit ) && isObject( prc.audit ) && prc.audit.isRunning()>
	<!---
		A run in progress. It happens on a background thread, so this page is
		not waiting on it — it is reporting what the row says.

		Two counts rather than a percentage, because a crawl does not know its
		total: URLs are discovered from the links on pages already fetched, so
		there is no denominator to divide by. A bar that invented one would be
		lying in a way nobody could check.
	--->
	<p class="flash" data-seo-running>
		Audit in progress &mdash;
		<strong>#prc.audit.getUrlCount()#</strong> URL#prc.audit.getUrlCount() == 1 ? "" : "s"# fetched,
		<strong>#prc.audit.getQueuedCount()#</strong> waiting.
		<a href="/admin/seo/show/#prc.audit.getId()#">Refresh</a>
	</p>
	<script>
		/*
			Follows the run without the page having to be reloaded by hand. The
			"Refresh" link above is the version that works with no JavaScript —
			this only removes the need to click it, which is why it is a plain
			reload rather than a fetch-and-patch.
		*/
		( function () {
			var marker = document.querySelector( "[data-seo-running]" );

			if ( marker ) {
				window.setTimeout( function () { window.location.reload(); }, 4000 );
			}
		} )();
	</script>
<cfelseif prc.canRun>
	<p class="muted" style="font-size:.85rem">
		A run fetches every public URL of this site one at a time, up to #prc.maxUrls#.
		It happens in the background, so you can leave this page.
	</p>
</cfif>

<cfif isNull( prc.audit ) || !isObject( prc.audit )>
	<p class="muted">No audit has been run for this site yet.</p>
<cfelse>

	<cfif prc.audit.isFailed()>
		<p class="flash error">
			This run stopped before it finished, so the findings below are incomplete.
			<cfif len( prc.audit.getNote() )><br>#encodeForHTML( prc.audit.getNote() )#</cfif>
		</p>
	<cfelseif len( prc.audit.getNote() )>
		<p class="flash">#encodeForHTML( prc.audit.getNote() )#</p>
	</cfif>

	<div class="seo-summary">
		<div class="seo-stat is-error">
			<strong>#prc.audit.getErrorCount()#</strong>
			<span>#prc.audit.getErrorCount() == 1 ? "error" : "errors"#</span>
		</div>
		<div class="seo-stat is-warning">
			<strong>#prc.audit.getWarningCount()#</strong>
			<span>#prc.audit.getWarningCount() == 1 ? "warning" : "warnings"#</span>
		</div>
		<div class="seo-stat is-notice">
			<strong>#prc.audit.getNoticeCount()#</strong>
			<span>#prc.audit.getNoticeCount() == 1 ? "notice" : "notices"#</span>
		</div>
	</div>

	<cfif !prc.issues.len() && prc.audit.isFinished()>
		<p class="flash">Nothing to report. Every URL audited passed every check.</p>
	</cfif>

	<cfif prc.issues.len()>
		<div class="tabs">
			<input type="radio" name="seoTab" id="tab-problem" checked>
			<label for="tab-problem">By problem</label>

			<input type="radio" name="seoTab" id="tab-page">
			<label for="tab-page">By page</label>

			<input type="radio" name="seoTab" id="tab-history">
			<label for="tab-history">History</label>

			<section class="tab-panel" data-for="tab-problem">
				<!--- Grouped by check, worst first: the shape of the site's
				      problem rather than a list of individual pages. --->
				<cfloop array="#prc.byCheck#" index="group">
					<cfset matching = prc.issues.filter( ( i ) => i.getCheckId() == group.checkId )>

					<cfif matching.len()>
						<details class="seo-group">
							<summary>
								<span class="pill-sev is-#encodeForHTMLAttribute( group.severity )#">#encodeForHTML( group.severity )#</span>
								#encodeForHTML( matching[ 1 ].getMessage() )#
								<span class="muted">&times;#group.total#</span>
							</summary>

							<ul class="seo-pages">
								<cfloop array="#matching#" index="issue">
									<li>
										<a href="/#xmlFormat( issue.getPath() )#" target="_blank" rel="noopener">#encodeForHTML( issue.getDisplayPath() )#</a>
										<cfif !isNull( issue.getPageId() ) && issue.getPageId()>
											<a class="ico" href="/admin/pages/edit/#issue.getPageId()#">Edit</a>
										</cfif>
										<cfif len( issue.getDetail() )>
											<div class="muted seo-detail">#encodeForHTML( issue.getDetail() )#</div>
										</cfif>
									</li>
								</cfloop>
							</ul>
						</details>
					</cfif>
				</cfloop>
			</section>

			<section class="tab-panel" data-for="tab-page">
				<table>
					<thead>
						<tr>
							<th style="width:45%">URL</th>
							<th class="c">Errors</th>
							<th class="c">Warnings</th>
							<th class="c">Notices</th>
							<th class="r">Actions</th>
						</tr>
					</thead>
					<tbody>
						<cfloop array="#prc.byPath#" index="row">
							<cfset rowPath = len( row.path ) ? "/" & row.path : "/">
							<tr>
								<td class="mono">
									<a href="/#xmlFormat( row.path )#" target="_blank" rel="noopener">#encodeForHTML( rowPath )#</a>
								</td>
								<td class="c">#row.errors ? row.errors : "&mdash;"#</td>
								<td class="c">#row.warnings ? row.warnings : "&mdash;"#</td>
								<td class="c">#row.notices ? row.notices : "&mdash;"#</td>
								<td class="r nowrap">
									<cfif row.pageId>
										<a class="ico" href="/admin/pages/edit/#row.pageId#">Edit page</a>
									</cfif>
								</td>
							</tr>
							<tr class="seo-row-detail">
								<td colspan="5">
									<ul class="seo-findings">
										<cfloop array="#prc.issues.filter( ( i ) => i.getPath() == row.path )#" index="issue">
											<li>
												<span class="pill-sev is-#encodeForHTMLAttribute( issue.getSeverity() )#">#encodeForHTML( issue.getSeverity() )#</span>
												#encodeForHTML( issue.getMessage() )#
												<cfif len( issue.getDetail() )>
													<div class="muted seo-detail">#encodeForHTML( issue.getDetail() )#</div>
												</cfif>
											</li>
										</cfloop>
									</ul>
								</td>
							</tr>
						</cfloop>
					</tbody>
				</table>
			</section>

			<section class="tab-panel" data-for="tab-history">
				<table>
					<thead>
						<tr>
							<th>Run</th>
							<th class="c">URLs</th>
							<th class="c">Errors</th>
							<th class="c">Warnings</th>
							<th class="c">Notices</th>
							<th class="r">Actions</th>
						</tr>
					</thead>
					<tbody>
						<cfloop array="#prc.audits#" index="past">
							<tr class="#past.getId() == prc.audit.getId() ? 'is-current' : ''#">
								<td>
									<a href="/admin/seo/show/#past.getId()#">#dateTimeFormat( past.getStartedAt(), "d mmm yyyy, HH:nn" )#</a>
									<cfif past.isFailed()><span class="tag alt">failed</span></cfif>
									<cfif past.isRunning()><span class="tag">running</span></cfif>
								</td>
								<td class="c">#past.getUrlCount()#</td>
								<td class="c">#past.getErrorCount()#</td>
								<td class="c">#past.getWarningCount()#</td>
								<td class="c">#past.getNoticeCount()#</td>
								<td class="r nowrap">
									<cfif prc.canRun>
										<form class="inline" method="post" action="/admin/seo/remove/#past.getId()#"
										      onsubmit="return confirm('Delete this audit?')">
											<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">
											<button type="submit" class="ico danger">Delete</button>
										</form>
									</cfif>
								</td>
							</tr>
						</cfloop>
					</tbody>
				</table>
			</section>
		</div>
	</cfif>
</cfif>

<style>
	.seo-summary{ display:flex; gap:.75rem; margin:1rem 0; flex-wrap:wrap; }
	.seo-stat{ background:var(--card); border:1px solid var(--line); border-radius:var(--radius);
	           padding:.7rem 1.1rem; min-width:7rem; }
	.seo-stat strong{ display:block; font-size:1.6rem; line-height:1.1; }
	.seo-stat span{ font-size:.8rem; color:var(--soft); }
	.seo-stat.is-error strong{ color:##b42318; }
	.seo-stat.is-warning strong{ color:##b54708; }
	.seo-stat.is-notice strong{ color:var(--soft); }

	/* The word is the signal; the colour only reinforces it. */
	.pill-sev{ display:inline-block; font-size:.68rem; font-weight:700; text-transform:uppercase;
	           letter-spacing:.03em; padding:.1rem .4rem; border-radius:3px; margin-right:.4rem;
	           border:1px solid transparent; }
	.pill-sev.is-error{ background:##fef3f2; color:##b42318; border-color:##fecdca; }
	.pill-sev.is-warning{ background:##fffaeb; color:##b54708; border-color:##fedf89; }
	.pill-sev.is-notice{ background:var(--bg); color:var(--soft); border-color:var(--line); }

	.seo-group{ border-bottom:1px solid var(--line); padding:.6rem 0; }
	.seo-group:last-child{ border-bottom:0; }
	.seo-group > summary{ cursor:pointer; list-style:none; font-size:.92rem; }
	.seo-group > summary::-webkit-details-marker{ display:none; }
	.seo-pages{ margin:.6rem 0 .2rem; padding-left:1.1rem; font-size:.88rem; }
	.seo-pages li{ margin:.3rem 0; }
	.seo-detail{ font-size:.8rem; word-break:break-word; }
	.seo-findings{ margin:0; padding-left:1.1rem; font-size:.88rem; }
	.seo-findings li{ margin:.3rem 0; }
	.seo-row-detail > td{ padding-top:0; }
	tr.is-current > td{ background:var(--bg); }
</style>
</cfoutput>
