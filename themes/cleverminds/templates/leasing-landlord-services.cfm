<cfoutput>
<cfif len( args.featuredImage ?: "" )>
	<div class="wrap">
		<figure class="page-hero">
			<img src="#xmlFormat( args.featuredImage )#" alt="" loading="eager" decoding="async">
		</figure>
	</div>
</cfif>
<section class="section">
	<div class="wrap">
    <cfif args.page.getShowHeading()>
			<h1>#encodeForHTML( args.page.getTitle() )#</h1>
		</cfif>
		<cfif len( trim( args.page.getContent() ?: "" ) )>
			#args.page.getContent()#
		</cfif>
<style type="text/css">
/* Layout Container */
.tab-container {
  display: flex;
  height: 400px;
  margin: 40px auto;
  border: 1px solid ##e2e8f0;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03);
  font-family: system-ui, -apple-system, sans-serif;
  background-color: ##ffffff;
}

/* Left Sidebar */
.tab-sidebar {
  width: 240px;
  background-color: ##f8fafc;
  border-right: 1px solid ##e2e8f0;
  display: flex;
  flex-direction: column;
}

/* Tab Buttons */
.tab-btn {
  padding: 16px 20px;
  text-align: left;
  background: none;
  border: none;
  font-size: 14px;
  font-weight: 500;
  color: ##64748b;
  cursor: pointer;
  transition: all 0.2s ease;
  border-left: 3px solid transparent;
}

.tab-btn:hover {
  background-color: ##f1f5f9;
  color: ##0f172a;
}

.tab-btn.active {
  background-color: ##ffffff;
  color: ##2563eb;
  border-left-color: ##2563eb;
  font-weight: 600;
}

/* Right Content Area */
.tab-content-area {
  flex: 1;
  padding: 30px;
  background-color: ##ffffff;
  overflow-y: auto;
}

/* Tab Panels */
.tab-panel {
  display: none;
}

.tab-panel.active {
  display: block;
  animation: fadeIn 0.3s ease-in-out;
}

.tab-panel h2 {
  margin-top: 0;
  color: ##0f172a;
  font-size: 20px;
}

.tab-panel p {
  color: ##475569;
  line-height: 1.6;
}

/* Simple Fade Animation */
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(4px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>
<div class="tab-container">
  <!-- Left Side: Navigation Tabs -->
  <div class="tab-sidebar">
    <button class="tab-btn active" onclick="openTab(event, 'tab1')">Overview</button>
    <button class="tab-btn" onclick="openTab(event, 'tab2')">Lease Advice</button>
    <button class="tab-btn" onclick="openTab(event, 'tab3')">Lease Negotiations</button>
    <button class="tab-btn" onclick="openTab(event, 'tab4')">Lease Disputes</button>
    <button class="tab-btn" onclick="openTab(event, 'tab5')">Misleading and Deceptive Conduct</button>
  </div>

  <!-- Right Side: Content Area -->
  <div class="tab-content-area">
    <div id="tab1" class="tab-panel active">
      <h2>Overview</h2>
      <p>We provide comprehensive lease advice and management services for landlords, 
      covering all aspects of retail and commercial leasing. Our services include preparing Lessor’s 
      Disclosure Statements, drafting tailored Retail and Commercial Leases and Agreements for Lease, 
      and providing specialised legal advice to protect landlords’ interests throughout the leasing process.</p>
      <p>Retail and commercial leasing can present significant legal and financial risks for landlords and leasing agents. 
      Our experienced legal advice helps you navigate complex leasing requirements, avoid costly mistakes and disputes, 
      and protect your interests throughout the leasing process.</p>
      <p>Accurate and up-to-date legal advice is essential for landlords, leasing agents and property managers to protect 
      their interests and avoid costly leasing mistakes. Failure to comply with the requirements of the Retail Leases Act 1994 (NSW) 
      can have serious financial and legal consequences. For example, failing to provide a Lessor’s Disclosure Statement in accordance 
      with the Act may give a tenant the right to terminate the lease within the first six months. 
      Similarly, failing to obtain the necessary Section 16 Certificate may result in a lease having a minimum five-year term, 
      despite the landlord intending to grant a lease for only two years. Our experienced leasing lawyers help landlords and 
      their agents navigate these statutory requirements, minimise risks and ensure their leasing arrangements are properly documented and legally compliant.</p>
      
    </div>

    <div id="tab2" class="tab-panel">
      <h2>Lease Advice</h2>
      <p>We provide comprehensive retail and commercial lease advice.</p>
    </div>
    
    <div id="tab3" class="tab-panel">
      <h2>Lease Negotiations</h2>
      <p>We have extensive experience in leasing and therefore we are experienced in assisting with lease negotiations.</p>
    </div>

    <div id="tab4" class="tab-panel">
      <h2>Lease Disputes</h2>
      <p>We are able to assist clients in Lease disputes - both at the NSW Civil and Administrative Tribunal (NCAT) and in Court.</p>
      <p>We have a strong focus on commercial dispute resolution. Note it will assist both our client and the opposing party when matters are settled fairly and in a prompt manner.</p>
      <p>Unfortumately, it happens that matters csnnot be resolved to the satisfaction of both partied and therefore the only remaining option is litigation.>/p> 
    </div>
    
    <div id="tab5" class="tab-panel">
      <h2>Misleading and Deceptive Conduct</h2>
      <p>We are able to assist clients with lease negotiations, helping to protect their interests and ensure that representations made by 
         landlords and leasing agents are properly addressed and reflected in the lease agreement.</p>
      <p>We assist by representing clients in resolving disputes for misleading and deceptive conduct.</p> 
    </div>

    <div id="tab5" class="tab-panel">
      <h2>Settings</h2>
      <p>Manage your account preferences, environment credentials, and notification thresholds.</p>
    </div>
  </div>
</div>

<script type="text/javascript">
	function openTab(evt, tabId) {
  // Hide all tab panels
  const panels = document.querySelectorAll('.tab-panel');
  panels.forEach(panel => panel.classList.remove('active'));

  // Remove active state from all buttons
  const buttons = document.querySelectorAll('.tab-btn');
  buttons.forEach(btn => btn.classList.remove('active'));

  // Show current tab panel and mark button as active
  document.getElementById(tabId).classList.add('active');
  evt.currentTarget.classList.add('active');
}
</script>
</div>
</section>
</cfoutput>
