<cfoutput>
<!---
	Email chrome. Inline styles and a table because email clients ignore most
	CSS; this is deliberately not the admin's stylesheet.
--->
<div style="font:15px/1.55 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:##1c1c1e">
	<div style="max-width:34rem;margin:0 auto;padding:1.5rem">
		#args.body#
		<hr style="border:0;border-top:1px solid ##e5e7eb;margin:1.5rem 0">
		<p style="font-size:.8rem;color:##6b7280;margin:0">
			Sent by #encodeForHTML( args.siteName ?: "myCFCMS" )#.
		</p>
	</div>
</div>
</cfoutput>
