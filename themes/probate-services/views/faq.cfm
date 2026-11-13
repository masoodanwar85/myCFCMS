<cfoutput>
<section class="section">
	<div class="wrap">
		<div class="stack" style="margin-bottom:40px">
			<span class="eyebrow">Common questions</span>
			<h1>Questions we are asked</h1>
		</div>

		<cfif !args.faqs.len()>
			<p class="lead">No questions have been published yet.</p>
		<cfelse>
			<div class="faq-list">
				<cfloop array="#args.faqs#" index="faq">
					<details class="faq-item">
						<summary>
							#encodeForHTML( faq.getQuestion() )#
							<span class="faq-plus" aria-hidden="true">+</span>
						</summary>
						<!--- The answer is author HTML, already sanitised on save. --->
						<div class="faq-answer prose">#faq.getAnswer()#</div>
					</details>
				</cfloop>
			</div>
		</cfif>
	</div>
</section>
</cfoutput>
