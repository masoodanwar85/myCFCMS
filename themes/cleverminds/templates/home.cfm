<cfoutput>
<!---
	Marketing home. Chosen from the page's Advanced tab. It does not print the
	stored article copy: that read as a letter, and this page needs to sell the
	work in a glance. The old copy stays in the database if it is wanted again.
--->
<div class="home">
<cfscript>
	local.heroSlider = application.wirebox.getInstance( "SlideService@slides" ).renderHeroSlider( args.site.getId() );
</cfscript>
<cfif len( trim( local.heroSlider ) )>
	#local.heroSlider#
</cfif>

<!--- 

	<section class="hero">
		<div class="wrap hero__grid">
			<div>
				<p class="eyebrow hero__eyebrow">Fixed-fee wills &amp; estates</p>
				<h1><span class="hero__line">Put your affairs in order.</span> <em>Prepare for the future.</em></h1>
				<p class="hero__lead">
					Answer a few straightforward questions. A qualified Wills and Estates solicitor reviews every document before you sign.
				</p>
				<div class="hero__actions">
					<a class="btn btn--lg" href="/will">Start your Will</a>
					<a class="btn btn--ghost" href="/legal-services">Legal services</a>
				</div>
				<p class="hero__note">Nothing to pay until your documents have been reviewed.</p>
			</div>

			<aside class="deed" aria-label="Estate portfolio">
				<div class="deed__head">
					<p class="deed__title">Your estate portfolio</p>
					<p class="deed__sub">Three instruments<br>One appointment</p>
				</div>
				<ul class="deed__list">
					<li>
						<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>
						<div>
							<b>Last Will &amp; Testament</b>
							<span>Who inherits, and who administers it</span>
						</div>
					</li>
					<li>
						<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>
						<div>
							<b>Enduring Power of Attorney</b>
							<span>Financial &amp; legal decisions, if you cannot</span>
						</div>
					</li>
					<li>
						<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>
						<div>
							<b>Enduring Guardian</b>
							<span>Health &amp; lifestyle decisions on your behalf</span>
						</div>
					</li>
				</ul>
			</aside>
		</div>
	</section>

	<section class="home-block home-block--paper" id="how-it-works">
		<div class="wrap">
			<div class="section__head">
				<p class="eyebrow">The documents</p>
				<h2>Three instruments every adult should hold</h2>
				<p>Most people think of a Will and stop there. Complete protection also names who decides for you if illness or age take away capacity.</p>
			</div>
			<div class="instruments">
				<article class="instrument">
					<span class="instrument__num">01</span>
					<h3>Last Will &amp; Testament</h3>
					<p>Name your executor, provide for the people who matter, appoint guardians for young children, and leave specific gifts.</p>
					<a class="instrument__link" href="/legal-services/wills">Wills</a>
				</article>
				<article class="instrument">
					<span class="instrument__num">02</span>
					<h3>Enduring Power of Attorney</h3>
					<p>Appoint someone you trust to manage your finances and legal affairs, and choose exactly when that authority begins.</p>
					<a class="instrument__link" href="/legal-services/power-of-attorney">Power of Attorney</a>
				</article>
				<article class="instrument">
					<span class="instrument__num">03</span>
					<h3>Enduring Guardian</h3>
					<p>Decide who will make decisions about your health, medical treatment and where you live, should you lose capacity.</p>
					<a class="instrument__link" href="/legal-services/enduring-guardian">Enduring Guardian</a>
				</article>
			</div>
		</div>
	</section>
    
 --->   

	
		<div class="wrap">
			
                <p class="hero__lead">
				<h1 style="text-align: center;">
    				Welcome to Cleverminds Legal Centre
				</h1>
                <p>
                &nbsp;
                </p>
				<div style="justify-content: space-between;display: flex;margin-top: 70px;">
					<div class="left-col" style="width: 50%;">
						<h3>
    				<em>A Modern, Flexible Approach to Legal Services</em>
				</h3><br>
						<p>
							Cleverminds Legal Centre provides legal services in a manner designed to accommodate the needs of individuals, families, businesses and other organisations. We combine professional legal advice with modern technology and flexible service delivery, including online, telephone and in-person consultations.
						</p><br />
						<p>
							Where appropriate, matters can be managed electronically, allowing clients to obtain legal assistance without unnecessary travel or disruption to their work, business or family commitments.
						</p>

                        <br><br><h3><em>Professional Advice and Personal Service</em></h3><br>
						<p>
							We recognise that every client and every legal matter is different. We take the time to understand your circumstances, identify the issues that are important to you and provide clear, practical and considered legal advice.
						</p><br />
						<p>
							Our aim is to ensure that you understand your legal position, the options available to you and the steps required to progress your matter.
						</p><br />
						<h3><em>Flexible Appointments</em></h3><br>
						<p>
							Accessing legal advice should not always require taking time away from work or other commitments. In addition to appointments during normal business hours, Cleverminds offers appointments after hours and on weekends by arrangement.
						</p><br />
						<p>
							Consultations may be conducted in person, by telephone or by video conference, depending upon the nature of the matter and the client's requirements.
						</p><br />
						<h3><em>Serving Clients Across NSW</em></h3><br>
						<p>
							Cleverminds Legal Centre provides legal services to clients throughout New South Wales, with a particular focus on <strong>Sydney, Greater Western Sydney, the Blue Mountains, the Central Coast and Central West NSW.</strong>
						</p><br />
						<p>
							Our flexible approach to delivering legal services enables us to assist clients across these regions, whether they prefer to meet with us personally or manage their matter remotely.
						</p><br />

						<br>
					</div>
    				<div class="mid-col" style="width:10%;">&nbsp;</div>
					<div class="right-col" style="width: 40%;">
						<aside class="deed" aria-label="Estate portfolio">
							<div class="deed__head">
								<p class="deed__title">Cleverminds Legal Centre</p>
							</div>
							<ul class="deed__list">
								<li>
									<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 6 9 17l-5-5"></path></svg>
									<div>
										<b>Professional and Personal</b>
										<span>We provide professional legal advice while maintaining a personal approach, taking the time to understand each client, their circumstances and their objectives.</span>
									</div>
								</li>
								<li>
									<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 6 9 17l-5-5"></path></svg>
									<div>
										<b>Clear and Practical Advice</b>
										<span>Legal matters can be complex. We explain legal issues clearly, provide practical advice and ensure our clients understand their options and the steps involved in their matter.</span>
									</div>
								</li>
								<li>
									<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 6 9 17l-5-5"></path></svg>
									<div>
										<b>Modern and Accessible</b>
										<span>We use modern technology and flexible methods of communication to make accessing legal services simpler and more convenient, while maintaining the professional standards expected of a legal practice.</span>
									</div>
								</li>
								<li>
									<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 6 9 17l-5-5"></path></svg>
									<div>
										<b>Responsive and Client-Focused</b>
										<span>
											We recognize the importance of communication. We keep clients informed, respond promptly to enquiries and provide clear guidance as their matter progresses.
										</span>
									</div>
								</li>
								<li>
									<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 6 9 17l-5-5"></path></svg>
									<div>
										<b>Attention to Detail</b>
										<span>
											We approach each matter carefully and methodically, with close attention to the legal, practical and procedural issues that may affect our clients.
										</span>
									</div>
								</li>
							</ul>
						</aside>
					</div>
				</div>
				</p>
                
	<section class="home-block" id="our-services">
				<div class="service-showcase">
				<h2 class="service-showcase__title">Our Services</h2>
                <div>
                <p>
                &nbsp:
                </p>
                <div class="service-row">
					<div class="service-row__media">
						<img src="/media/2026/09/wills-379a4e46.jpg" alt="A solicitor meeting with clients about their will">
					</div>
					<div class="service-row__body">
						<h3>Wills &amp; Estate Planning</h3>
						<p>Ensure your estate plan sees the successful transfer of your assets in a manner that is tax effective and protective of family assets.</p>
						<p><a class="service-row__more" href="/legal-services/estate-planning">Find out more</a></p>
					</div>
				</div>

				<div class="service-row service-row--flip">
					<div class="service-row__media">
						<img src="/media/2026/09/probate-pic-d7e57652.jpeg" alt="A professional handshake after completing probate">
					</div>
					<div class="service-row__body">
						<h3>Probate</h3>
						<p>We have obtained Probate for hundreds of clients. We get the job done quickly and effectively, every time.</p>
						<p><a class="service-row__more" href="/probate-what-is-probate">Find out more</a></p>
					</div>
				</div>
                
                <div class="service-row">
					<div class="service-row__media">
						<img src="/media/2026/09/property-law-pic-8b559892.jpeg" alt="House keys representing property law services">
					</div>
					<div class="service-row__body">
						<h3>Property Law</h3>
						<p>Conveyancing, transmissions, purchases, sales and leasing &mdash; practical property advice for New South Wales families.</p>
						<p><a class="service-row__more" href="/legal-services/property-law/what-is-property-law-and-conveyancing">Find out more</a></p>
					</div>
				</div>

				<div class="service-row service-row--flip">
					<div class="service-row__media">
						<img src="/media/2026/09/power-of-attorney-7d2e8226.jpg" alt="Signing a power of attorney">
					</div>
					<div class="service-row__body">
						<h3>Leasing</h3>
						<p>Retail leases and commercial leases both involve the letting of a property to a tenant for the purpose of allowing them to take exclusive possession of a premises, usually to carry on a business.</p>
						<p><a class="service-row__more" href="/legal-services/leasing-retail-and-commercial">Find out more</a></p>
					</div>
				</div>

				<div class="service-row">
					<div class="service-row__media">
						<img src="/media/2026/09/enduring-guardian-20e63144.jpg" alt="A trusted person ready to make health decisions">
					</div>
					<div class="service-row__body">
						<h3>Intellectual Property</h3>
						<p>Intellectual property can be the most important asset owned by a business, so we work hard to protect its value.</p>
						<p><a class="service-row__more" href="/legal-services/intellectual-property">Find out more</a></p>
					</div>
				</div>

				<div class="service-row  service-row--flip">
					<div class="service-row__media">
						<img src="/media/2026/09/letters-1040a3dc.jpg" alt="Working through estate administration papers">
					</div>
					<div class="service-row__body">
						<h3>Employment Law</h3>
						<p>Employment law services include protect workplace rights and resolve disputes through contracts, compliance advice, and litigation support</p>
						<p><a class="service-row__more" href="/legal-services/employment-law">Find out more</a></p>
					</div>
				</div>

				
				<div class="service-row">
                	<div class="service-row__media">
                    	<img src="/media/2026/09/sports-law-79c606a5.png" alt="House keys representing property law services">
                    </div>          
                    <div class="service-row__body">
                    	<h3>Sports Law</h3>
                        <p>Providing clear, pragmatic advice based on our experience and knowledge of this high-profile, highly regulated and public-facing environment.</p>
                        <p><a class="service-row__more" href="/legal-services/sports-law">Find out more</a></p>
                    </div>  
                </div>   
			</div>
			<p class="home-services__foot">
				<a class="btn btn--ghost" href="/contact">Contact us</a>
				<a class="btn btn--ghost" href="/legal-services">View all services</a>
			</p>
		</div>
	</section>
	<br />
    </div>
 <!---  

	<section class="home-block home-block--paper">
		<div class="wrap">
			<div class="section__head">
				<p class="eyebrow">How it works</p>
				<h2>You do the easy part. A solicitor does the careful part.</h2>
				<p>From the first question to a signed document, the process is built around one principle: nothing is signed until it has been reviewed.</p>
			</div>
			<div class="process">
				<div class="process__step">
					<span class="process__num">1</span>
					<h4>Answer the questions</h4>
					<p>Work through a guided questionnaire at your own pace. Save and return whenever you like.</p>
				</div>
				<div class="process__step">
					<span class="process__num">2</span>
					<h4>We assemble the documents</h4>
					<p>Your answers become a properly structured Will, Enduring Power of Attorney and Enduring Guardian.</p>
				</div>
				<div class="process__step">
					<span class="process__num">3</span>
					<h4>Solicitor review</h4>
					<p>Our Wills and Estates solicitor checks every document and contacts you if anything needs a conversation.</p>
				</div>
				<div class="process__step">
					<span class="process__num">4</span>
					<h4>Sign in person</h4>
					<p>At a short appointment you review the documents. Once you are satisfied, they are signed and witnessed as the law requires.</p>
				</div>
			</div>
		</div>
	</section>

	<section class="assure">
		<div class="wrap">
			<div>
				<h2>Solicitor care, without the traditional bill.</h2>
				<p>Do-it-yourself kits are cheap for a reason: no one checks them. An invalid Will can cost a family far more than it ever saved. We keep the ease of doing it from home, and never let a Will reach signing without review.</p>
			</div>
			<div class="assure__stats">
				<div class="stat">
					<b>Fixed</b>
					<span>Three documents, one fee</span>
				</div>
				<div class="stat">
					<b>25 min</b>
					<span>Average time to answer the questions</span>
				</div>
				<div class="stat">
					<b>NSW</b>
					<span>Sydney, Blue Mountains, Central Coast &amp; regional</span>
				</div>
				<div class="stat">
					<b>0</b>
					<span>To pay until you are ready to proceed</span>
				</div>
			</div>
		</div>
	</section>

	<section class="home-block cta-band">
		<div class="wrap">
			<h2>The best time was years ago. The second best time is now.</h2>
			<p>Begin your Will, Power of Attorney and Enduring Guardian today.</p>
			<div class="hero__actions" style="justify-content:center">
				<a class="btn btn--lg btn--brass" href="/will">Create your Will</a>
				<a class="btn btn--ghost" href="/contact">Book an appointment</a>
			</div>
		</div>
	</section>
    
 --->

</div>
</cfoutput>
