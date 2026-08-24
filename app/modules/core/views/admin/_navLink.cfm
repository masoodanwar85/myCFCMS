<cfoutput><!---
	One admin navigation link. Expects `local.navItem` and `local.currentPath`.

	Its own file because the top bar renders links in two places — loose at the
	top level and inside a group panel — and the current-section logic and the
	badge should not be written twice and drift.

	The label is kept tight against the tags: whitespace inside the anchor once
	made `>Pages<` unmatchable, which silently turned a "this user must NOT see
	Pages" assertion into one that passed no matter what.
---><cfset local.linkCurrent = isCurrentSection( local.navItem, local.currentPath )><a href="#xmlFormat( local.navItem.href )#" class="#local.linkCurrent ? 'is-current' : ''#">#encodeForHTML( local.navItem.label )#<cfif ( local.navItem.badge ?: 0 ) gt 0><span class="adm-badge">#local.navItem.badge#</span></cfif></a></cfoutput>
