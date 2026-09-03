<cfsilent>
<!---
	The one place the CMS actually calls ColdFusion's mail tag.

	## Why this is a template and not a line of cfscript

	`cfmail` is resolved when its containing file is **compiled**. On an
	installation without the mail package — ColdFusion 2021 and later ship
	modular, and a minimal install has no mail — putting it directly in
	`MailService.cfc` stops that whole component compiling. WireBox then cannot
	build it, every screen that injects it fails, and the symptom is an
	unrelated `Injector.InstanceNotFoundException`.

	Isolated in an included template, the same failure is an ordinary catchable
	exception at the point of the include. The caller records the message as
	`failed` with a usable reason and everything else keeps working.

	## Why `cfmail` and not `mail`

	`mail()` is Lucee and BoxLang syntax. Adobe ColdFusion does not resolve it
	and reports "Variable MAIL is undefined" — which reads like a coding slip
	and is not one. This project deploys on Adobe, so `cfmail` it is.

	`attributeCollection` is what makes that workable: the *tag* accepts it,
	while `cfmail()` in cfscript rejects it and would need every attribute
	written out twice, once with a reply-to and once without.

	Expects `local.mailArgs` and `local.mailBody` from the calling function.
--->
</cfsilent><cfmail attributeCollection="#local.mailArgs#"><cfoutput>#local.mailBody#</cfoutput></cfmail>
