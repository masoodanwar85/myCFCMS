<cfoutput>
<article class="section">
<cfif args.page.getShowHeading()>
		<h1>#args.breadcrumb[1].getTitle()# - #encodeForHTML( args.page.getTitle() )#</h1>
	</cfif>
<div class="wrap" style="display:flex">
	<div class="left-col" style="padding-right:25px;">
    	#args.page.getContent()#
    </div>
	<div class="right-col">
		<form method="post" action="/contact">
		<input type="hidden" name="csrfToken" value="e082d224f6acd480c5ec36fdba129560f565fd8aa106765bc3276becaaebb757">
		<input type="hidden" name="form" value="contact-us">

		
		<div style="position:absolute;left:-9999px" aria-hidden="true">
			<label for="website">Leave this blank</label>
			<input type="text" id="website" name="website" tabindex="-1" autocomplete="off" data-sharkid="__0">
		</div>

		<label for="name">Your name</label>
		<input type="text" id="name" name="name" required="" maxlength="150" value="" data-sharkid="__1" data-sharklabel="name">

		<label for="email">Your email</label>
		<input type="email" id="email" name="email" required="" maxlength="191" value="" data-sharkid="__2" data-sharklabel="email">

		<label for="subject">Subject</label>
		<input type="text" id="subject" name="subject" maxlength="255" value="" data-sharkid="__3">

		<label for="message">Message</label>
		<textarea id="message" name="message" required="" rows="8" maxlength="10000" data-sharkid="__4"></textarea>


		
			
			
			<div class="g-recaptcha-container">
				<div class="g-recaptcha" data-sitekey="6LeCc3gtAAAAACfX22saXvx3sC_7AnqBsYUt1TSi"><div style="width: 304px; height: 78px;"><div><iframe title="reCAPTCHA" width="304" height="78" role="presentation" name="a-49ufgui88jgt" frameborder="0" scrolling="no" sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-top-navigation allow-modals allow-popups-to-escape-sandbox allow-storage-access-by-user-activation" src="https://www.google.com/recaptcha/api2/anchor?ar=1&amp;k=6LeCc3gtAAAAACfX22saXvx3sC_7AnqBsYUt1TSi&amp;co=aHR0cHM6Ly9jbGV2ZXJtaW5kcy5jb20uYXU6NDQz&amp;hl=en&amp;v=zqB-6Xpbd3lCIvi7Tr2D0pob&amp;size=normal&amp;anchor-ms=20000&amp;execute-ms=30000&amp;cb=5gok1z4qpfz8"></iframe></div><textarea id="g-recaptcha-response" name="g-recaptcha-response" class="g-recaptcha-response" style="width: 250px; height: 40px; border: 1px solid rgb(193, 193, 193); margin: 10px 25px; padding: 0px; resize: none; display: none;"></textarea></div><iframe style="display: none;"></iframe></div>
			</div>
			<script src="https://www.google.com/recaptcha/api.js" async="" defer=""></script>
		
		<p style="margin-top:1.5rem"><button type="submit">Send message</button></p>
	<shark-icon-container data-sharkidcontainer="__2" style="position: absolute;"></shark-icon-container></form>
	
	</div>
</div>
</article>
</cfoutput>
