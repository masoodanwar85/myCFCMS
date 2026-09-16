<cfset tableOf = 6 />
<cfoutput>
<cfloop from="1" to="10" index="idx">
    #tableOf# x #idx# = #val(tableOf * idx)#<br />
</cfloop>

</cfoutput>