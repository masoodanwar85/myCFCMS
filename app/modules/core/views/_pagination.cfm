<cfoutput>
<!---
	Shared admin pager.

	Expects `prc.pagination` (from Paginator@core) and `prc.pageBase`. The base
	may already carry a query string — the enquiries list filters by status —
	so the page parameter is appended with the right separator rather than
	assuming "?".
--->
<cfif ( prc.pagination.totalPages ?: 0 ) gt 1>
	<cfset joiner = find( "?", prc.pageBase ) ? "&" : "?">
	<nav aria-label="Pages" class="pager">
		<span class="muted">
			#prc.pagination.firstRecord#&ndash;#prc.pagination.lastRecord# of #prc.pagination.total#
		</span>

		<cfif prc.pagination.hasPrevious>
			<a href="#xmlFormat( prc.pageBase & joiner & 'page=' & prc.pagination.previousPage )#" rel="prev">Previous</a>
		</cfif>

		<cfloop array="#prc.pagination.pages#" index="n">
			<cfif n eq 0>
				<span class="muted">&hellip;</span>
			<cfelseif n eq prc.pagination.page>
				<strong aria-current="page">#n#</strong>
			<cfelse>
				<a href="#xmlFormat( prc.pageBase & joiner & 'page=' & n )#">#n#</a>
			</cfif>
		</cfloop>

		<cfif prc.pagination.hasNext>
			<a href="#xmlFormat( prc.pageBase & joiner & 'page=' & prc.pagination.nextPage )#" rel="next">Next</a>
		</cfif>
	</nav>
</cfif>
</cfoutput>
