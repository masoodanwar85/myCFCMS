<cftry>

	<!--- Location testing --->
	<cfquery name="qryGetLocations" datasource="myCFCMS">
    	SELECT name,region 
    	FROM locations
    	WHERE site_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#args.site.getId()#" /> 
    	ORDER BY name
	</cfquery>

	<div class="wrap">
    	<h1>Location List</h1>
		<ol>
    		<cfoutput query="qryGetLocations">
        		<li> #qryGetLocations.name# </li>
    		</cfoutput>
        </ol>
	</div>
    
    
	<cfcatch>
    	<cfdump var="#cfcatch#" abort="true" />
    </cfcatch>
</cftry>