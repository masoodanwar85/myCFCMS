<cfoutput>
<article data-view="default-faq">
	<h1>FAQs</h1>

	<cfif !args.faqs.len()>
		<p>No frequently asked questions have been published yet.</p>
	<cfelse>
		<div class="faq-list">
			<cfloop array="#args.faqs#" index="faq">
				<details class="faq-item">
					<summary>#encodeForHTML( faq.getQuestion() )#</summary>
					<div class="faq-answer">#faq.getAnswer()#</div>
				</details>
			</cfloop>
		</div>
	</cfif>
</article>

<style>
	.faq-list{ max-width:48rem; margin:1.5rem 0 0; }
	.faq-item{ border:1px solid ##e2e5ea; border-radius:8px; margin:0 0 .6rem; background:##fff; }
	.faq-item > summary{
		list-style:none; cursor:pointer; padding:1rem 1.15rem; font-weight:600;
		display:flex; justify-content:space-between; align-items:center; gap:1rem;
	}
	.faq-item > summary::-webkit-details-marker{ display:none; }
	.faq-item > summary::after{ content:"+"; font-weight:400; font-size:1.25rem; line-height:1; color:##666; flex:none; }
	.faq-item[open] > summary{ border-bottom:1px solid ##e2e5ea; }
	.faq-item[open] > summary::after{ content:"\2212"; }
	.faq-answer{ padding:1rem 1.15rem 1.15rem; }
	.faq-answer > :first-child{ margin-top:0; }
	.faq-answer > :last-child{ margin-bottom:0; }
</style>
</cfoutput>
