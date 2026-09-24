<cfoutput>
<cfset editing = isObject( prc.faq )>
<h1>#editing ? "Edit FAQ" : "New FAQ"#</h1>
<p class="sub">Shown in the accordion on <code>/faq</code> when published.</p>

<form method="post" action="#editing ? '/admin/faqs/update/' & prc.faq.getId() : '/admin/faqs/create'#">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<label for="question">Question</label>
	<input type="text" id="question" name="question" required maxlength="500"
	       value="#editing ? encodeForHTMLAttribute( prc.faq.getQuestion() ) : ''#">

	<label for="answer">Answer</label>
	<textarea id="answer" name="answer" data-editor>#editing ? encodeForHTML( prc.faq.getAnswer() ?: "" ) : ""#</textarea>

	<div class="grid2">
		<div>
			<label for="sortOrder">Sort order</label>
			<input type="number" id="sortOrder" name="sortOrder"
			       value="#editing ? encodeForHTMLAttribute( prc.faq.getSortOrder() ) : '0'#">
			<p class="muted" style="font-size:.8rem">Leave at 0 on a new FAQ to append it to the end of the list.</p>
		</div>
		<div>
			<label>&nbsp;</label>
			<div class="checks">
				<label>
					<input type="checkbox" name="isPublished"<cfif editing && prc.faq.getIsPublished()> checked</cfif>>
					Published (visible on /faq)
				</label>
			</div>
		</div>
	</div>

	<div class="actions-bar">
		<button type="submit">#editing ? "Save FAQ" : "Create FAQ"#</button>
		<a class="btn secondary" href="/admin/faqs">Cancel</a>
	</div>
</form>
</cfoutput>
