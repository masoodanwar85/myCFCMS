<cfoutput>
<h1>Sign in</h1>
<p class="sub">#encodeForHTML( prc.currentSite.getName() )#</p>

<form method="post" action="/admin/auth/authenticate">
	<input type="hidden" name="csrfToken" value="#encodeForHTMLAttribute( prc.csrfToken )#">

	<label for="email">Email</label>
	<input type="email" id="email" name="email" required autofocus
	       value="#encodeForHTMLAttribute( flash.get( 'email', '' ) )#">

	<label for="password">Password</label>
	<input type="password" id="password" name="password" required>

	<div class="actions-bar">
		<button type="submit">Sign in</button>
	</div>
</form>
</cfoutput>
