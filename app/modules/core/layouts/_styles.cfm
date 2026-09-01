<style>
	/* =================================================================
	   Admin styles.

	   Layout follows the CFCMS admin: a dark top bar, a centred content
	   column, bordered cards and tables, small outlined action buttons.

	   One deliberate departure. That admin performs Publish, Activate and
	   Delete through GET links carrying a CSRF token in the query string.
	   These are styled to match but are POST forms underneath: a link that
	   changes data can be followed by a prefetcher, a crawler, or anything
	   that scans a page, and no token in a URL prevents that.
	   ================================================================= */
	:root{
		--ink:#1a1d23; --soft:#666f7d; --line:#e2e5ea; --bg:#f4f6f8; --card:#fff;
		--accent:#1f6feb; --danger:#c0392b; --ok:#1e8e4a; --radius:10px;
		--bar:#12161c;
		--font: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
		--mono: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
	}
	*,*::before,*::after{ box-sizing:border-box; }
	html{ background:var(--bg); }
	body{ margin:0; min-height:100vh; font-family:var(--font); font-size:15px;
	      color:var(--ink); background:var(--bg); }
	a{ color:var(--accent); }
	/* Table cells read as data, not as a wall of underlines; the underline
	   comes back on hover so the link affordance is still discoverable. */
	table a{ text-decoration:none; }
	table a:hover{ text-decoration:underline; }
	code{ font-family:var(--mono); font-size:.88em; background:#eef0f3; padding:.1rem .3rem; border-radius:4px; }

	.adm-wrap{ max-width:1200px; margin:0 auto; padding:0 1.25rem; }

	/* ---- top bar ---------------------------------------------------- */
	.adm-top{ background:var(--bar); color:#fff; }
	.adm-top .adm-wrap{ display:flex; align-items:center; gap:1.25rem; min-height:56px; flex-wrap:wrap; }
	.adm-brand{ color:#fff; font-weight:700; text-decoration:none; letter-spacing:-.01em; white-space:nowrap; }
	.adm-brand span{ opacity:.55; font-weight:400; }
	.adm-nav{ display:flex; gap:.25rem; margin-right:auto; flex-wrap:wrap; }
	.adm-nav a{ color:#cfd6e0; text-decoration:none; padding:.4rem .7rem; border-radius:6px; font-size:.9rem; }
	.adm-nav a:hover{ background:rgba(255,255,255,.1); color:#fff; }
	.adm-nav a.is-current{ background:rgba(255,255,255,.14); color:#fff; font-weight:600; }
	.adm-site{ font-size:.8rem; color:#9aa5b3; display:flex; align-items:center; gap:.4rem; white-space:nowrap; }
	.adm-site strong{ color:#e6eaef; font-weight:600; }
	.adm-user{ font-size:.85rem; color:#9aa5b3; display:flex; align-items:center; gap:.5rem; white-space:nowrap; }
	.adm-user a,.adm-user button{ color:#cfd6e0; }
	.adm-tag-super{ font-size:.65rem; text-transform:uppercase; letter-spacing:.06em;
	                background:rgba(255,255,255,.14); padding:.1rem .35rem; border-radius:4px; }
	.adm-badge{ display:inline-block; min-width:1.1rem; padding:0 .35rem; border-radius:999px;
	            background:var(--accent); color:#fff; font-size:.7rem; line-height:1.4; text-align:center; }

	/* ---- page ------------------------------------------------------- */
	.adm-main{ padding:1.75rem 1.25rem 3rem; }
	h1{ font-size:1.5rem; margin:0 0 .35rem; letter-spacing:-.02em; }
	h2{ font-size:1rem; margin:1.75rem 0 .6rem; color:var(--soft);
	    text-transform:uppercase; letter-spacing:.06em; }
	.sub{ color:var(--soft); margin:0 0 1.25rem; font-size:.9rem; }
	.muted{ color:var(--soft); }

	.flash{ background:#e7f6ec; border:1px solid #b7e2c6; color:#155f33;
	        padding:.7rem 1rem; border-radius:8px; margin:0 0 1rem; }
	.flash.error{ background:#fdecea; border-color:#f5b7b1; color:#922b21; }
	/* Not an error and not a confirmation: something that worked and that the
	   reader should think about before using. */
	.flash.warn{ background:#fef6e7; border-color:#f5d79b; color:#7a5300; }

	/* ---- toolbar ---------------------------------------------------- */
	.adm-toolbar,.actions-bar{ display:flex; align-items:center; gap:.6rem; margin:0 0 1rem; flex-wrap:wrap; }
	/* The selected filter in a toolbar group. Solid so it reads as state,
	   not as the one action the toolbar wants you to take. */
	.btn.secondary.is-current{ background:var(--ink); border-color:var(--ink); color:#fff; }
	.adm-count{ margin-left:auto; color:var(--soft); font-size:.85rem; }

	/* ---- buttons ---------------------------------------------------- */
	.btn,button{ display:inline-block; background:var(--accent); color:#fff; border:0;
	             padding:.55rem 1rem; border-radius:8px; font:inherit; font-weight:600;
	             text-decoration:none; cursor:pointer; }
	.btn:hover,button:hover{ filter:brightness(1.06); }
	.btn.secondary,button.secondary{ background:transparent; color:var(--accent); border:1px solid var(--line); }
	button.danger,.btn.danger{ background:#fff; color:#8a1c12; border:1px solid #e5b4ae; }

	/* Small outlined action, for a row's Edit / Delete / reorder controls. */
	.ico,button.ico{ display:inline-block; padding:.2rem .45rem; text-decoration:none; color:var(--soft);
	                 border:1px solid var(--line); border-radius:6px; font-size:.8rem; font-weight:500;
	                 margin-left:.2rem; background:#fff; cursor:pointer; }
	.ico:hover,button.ico:hover{ color:var(--accent); border-color:var(--accent); filter:none; }
	.ico.danger,button.ico.danger{ color:var(--soft); }
	.ico.danger:hover,button.ico.danger:hover{ color:var(--danger); border-color:var(--danger); }

	/* A status that is also the control that changes it. */
	.pill,button.pill{ display:inline-block; font-size:.75rem; padding:.15rem .55rem; border-radius:999px;
	                   text-decoration:none; border:1px solid transparent; font-weight:500;
	                   background:#f1f2f4; color:#6b7280; border-color:#e0e3e8; cursor:default; }
	button.pill{ cursor:pointer; }
	.pill.on,button.pill.on{ background:#e7f6ec; color:#155f33; border-color:#b7e2c6; }
	.pill.off,button.pill.off{ background:#f1f2f4; color:#6b7280; border-color:#e0e3e8; }
	button.pill:hover{ filter:brightness(.97); }

	.tag{ display:inline-block; font-size:.68rem; text-transform:uppercase; letter-spacing:.05em;
	      background:#e8f0fe; color:#1a4fa0; padding:.1rem .4rem; border-radius:4px; margin-left:.35rem; }
	.tag.alt{ background:#fdf2e3; color:#8a5a10; }

	button.linkish{ background:none; border:0; color:var(--accent); padding:0; font:inherit; cursor:pointer; }

	/* ---- table ------------------------------------------------------ */
	table{ width:100%; border-collapse:collapse; background:var(--card);
	       border:1px solid var(--line); border-radius:var(--radius); overflow:hidden; }
	th{ text-align:left; font-size:.75rem; text-transform:uppercase; letter-spacing:.05em;
	    color:var(--soft); padding:.6rem .8rem; background:#fafbfc; border-bottom:1px solid var(--line); }
	td{ padding:.55rem .8rem; border-bottom:1px solid var(--line); vertical-align:middle; }
	tr:last-child td{ border-bottom:0; }
	tr.is-off{ opacity:.55; }
	td.actions,.r{ text-align:right; white-space:nowrap; }
	.c{ text-align:center; }
	.nowrap{ white-space:nowrap; }
	.indent{ display:inline-block; }
	form.inline{ display:inline; }

	/* ---- forms ------------------------------------------------------ */
	label{ display:block; margin:.9rem 0 .25rem; font-weight:600; font-size:.85rem; }
	input[type=text],input[type=email],input[type=password],input[type=url],
	input[type=number],input[type=file],select,textarea{
		width:100%; padding:.5rem .65rem; border:1px solid var(--line); border-radius:8px;
		font:inherit; font-weight:400; background:#fff; color:var(--ink); }
	input:focus,select:focus,textarea:focus{
		outline:2px solid rgba(31,111,235,.35); outline-offset:1px; border-color:var(--accent); }
	textarea{ resize:vertical; line-height:1.5; }
	/*
	   Monospace and a tall default belong to textareas holding *markup* — the
	   editor fallback, raw head/body markup, JSON-LD. Prose fields like a meta
	   description are ordinary text and should look like it; before this they
	   inherited both and a three-row description rendered eleven rems tall in
	   a code font.
	*/
	textarea[data-editor],
	textarea[data-code]{ min-height:11rem; font-family:var(--mono); font-size:.85rem; }
	.grid2{ display:grid; grid-template-columns:1fr 1fr; gap:0 1.25rem; }
	@media (max-width:760px){ .grid2{ grid-template-columns:1fr; } }
	.checks{ display:grid; grid-template-columns:repeat(auto-fill,minmax(14rem,1fr)); gap:.35rem; margin-top:.5rem; }
	.checks label{ display:flex; gap:.4rem; align-items:center; margin:0; color:var(--ink);
	               font-size:.85rem; font-weight:400; }
	.checks input{ width:auto; }

	/* ---- editor ----------------------------------------------------- */
	.ck-editor__editable_inline{ min-height:420px; }
	.ck.ck-toolbar{ border-radius:6px 6px 0 0; }
	.ck.ck-editor__editable_inline:not(.ck-comment__input *){ border-radius:0 0 6px 6px; }
	.ck-source-editing-area textarea{ font-family:var(--mono); font-size:.85rem; line-height:1.5; }

	/* ---- media ------------------------------------------------------ */
	.media-grid{ display:grid; grid-template-columns:repeat(auto-fill,minmax(11rem,1fr)); gap:1rem; margin:1.25rem 0; }
	.media-card{ background:var(--card); border:1px solid var(--line); border-radius:var(--radius); padding:.6rem; font-size:.8rem; }
	.media-card img{ width:100%; height:7rem; object-fit:cover; border-radius:6px; display:block; background:var(--bg); }
	.media-card .media-file{ display:grid; place-items:center; height:7rem; border-radius:6px;
	                         background:var(--bg); color:var(--soft); font-weight:600; text-decoration:none; }
	.media-meta{ margin:.45rem 0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
	.media-card input[type=text]{ font-size:.78rem; padding:.3rem .4rem; }
	.media-actions{ display:flex; gap:.35rem; margin-top:.4rem; }
	.media-actions .ico{ margin-left:0; }

	/* A text input paired with picker buttons: the input takes the slack so the
	   buttons stay their natural size at any width. */
	.media-field{ display:flex; gap:.4rem; align-items:center; }
	.media-field input[type=text]{ flex:1 1 auto; min-width:0; }
	.media-field .ico{ margin-left:0; white-space:nowrap; }

	/* Two fields side by side, stacking rather than shrinking on a narrow
	   screen — a colour and a font stack are both unreadable in a 6rem box. */
	.grid-2{ display:grid; grid-template-columns:repeat(auto-fit,minmax(14rem,1fr)); gap:0 1rem; }

	/* ---- grouped navigation ------------------------------------------ */
	.adm-menu{ position:relative; }
	.adm-menu > summary{ list-style:none; cursor:pointer; color:#cfd6e0;
	                     padding:.4rem .7rem; border-radius:6px; font-size:.9rem;
	                     white-space:nowrap; }
	/* Safari draws its own disclosure triangle unless this is removed too. */
	.adm-menu > summary::-webkit-details-marker{ display:none; }
	.adm-menu > summary::after{ content:" \25be"; opacity:.6; }
	.adm-menu > summary:hover{ background:rgba(255,255,255,.1); color:#fff; }
	.adm-menu > summary.is-current{ background:rgba(255,255,255,.14); color:#fff; font-weight:600; }
	.adm-menu[open] > summary{ background:rgba(255,255,255,.14); color:#fff; }
	.adm-menu > summary:focus-visible{ outline:2px solid rgba(255,255,255,.6); outline-offset:1px; }

	.adm-menu-panel{ position:absolute; top:calc(100% + .35rem); left:0; z-index:50;
	                 min-width:11rem; padding:.35rem; background:var(--card);
	                 border:1px solid var(--line); border-radius:8px;
	                 box-shadow:0 12px 28px rgba(0,0,0,.18); }
	/* Inside the panel a link is dark-on-light, not the bar's light-on-dark. */
	.adm-menu-panel a{ display:block; padding:.45rem .6rem; border-radius:6px;
	                   color:var(--ink); font-size:.9rem; }
	.adm-menu-panel a:hover{ background:var(--bg); color:var(--ink); }
	.adm-menu-panel a.is-current{ background:var(--bg); color:var(--accent); font-weight:600; }

		/* ---- tabbed forms ------------------------------------------------ */
	/*
	   CSS-only tabs. Every panel stays in the DOM and inside the one form, so
	   switching tabs cannot lose what has been typed and a save posts every
	   field regardless of which tab is showing — which is not true of tabs that
	   swap panels in and out with script.
	*/
	.tabs{ background:var(--card); border:1px solid var(--line); border-radius:var(--radius); }
	.tabs > input[type=radio]{ position:absolute; opacity:0; pointer-events:none; }
	.tabs > label{ display:inline-block; padding:.8rem 1.1rem; margin:0; cursor:pointer;
	               font-weight:600; font-size:.9rem; color:var(--soft);
	               border-bottom:2px solid transparent; }
	.tabs > label:hover{ color:var(--ink); }
	.tabs > input[type=radio]:checked + label{ color:var(--accent); border-bottom-color:var(--accent); }
	/* Keyboard users must be able to see which tab they are on. */
	.tabs > input[type=radio]:focus-visible + label{ outline:2px solid var(--accent); outline-offset:-2px; }
	.tabs > .tab-panel{ display:none; padding:1.25rem; border-top:1px solid var(--line); }

	/*
	   Which panel shows is matched by POSITION, not by id: the nth radio
	   reveals the nth panel. These rules used to name #tab-content, #tab-seo
	   and #tab-advanced one at a time, which meant every new tabbed screen had
	   to come back and edit this file — and Settings alone has six sections.

	   Two constraints come with it, and both are load-bearing:

	     1. The radios must be the ONLY direct-child input elements of .tabs.
	        :nth-of-type counts by element type and ignores the attribute
	        filter, so a hidden input dropped in here would shift every panel by
	        one. Put hidden fields inside a panel, or outside .tabs entirely.
	     2. Panels must appear in the same order as their radios.

	   data-for stays on each panel as documentation and as a hook for tests;
	   nothing here selects on it.
	*/
	.tabs > input[type=radio]:nth-of-type(1):checked ~ section.tab-panel:nth-of-type(1),
	.tabs > input[type=radio]:nth-of-type(2):checked ~ section.tab-panel:nth-of-type(2),
	.tabs > input[type=radio]:nth-of-type(3):checked ~ section.tab-panel:nth-of-type(3),
	.tabs > input[type=radio]:nth-of-type(4):checked ~ section.tab-panel:nth-of-type(4),
	.tabs > input[type=radio]:nth-of-type(5):checked ~ section.tab-panel:nth-of-type(5),
	.tabs > input[type=radio]:nth-of-type(6):checked ~ section.tab-panel:nth-of-type(6),
	.tabs > input[type=radio]:nth-of-type(7):checked ~ section.tab-panel:nth-of-type(7),
	.tabs > input[type=radio]:nth-of-type(8):checked ~ section.tab-panel:nth-of-type(8){ display:block; }
	.tabs h2{ margin-top:1.6rem; font-size:.8rem; text-transform:uppercase;
	          letter-spacing:.05em; color:var(--soft); }
	.tabs h2:first-child{ margin-top:0; }

	.grid3{ display:grid; grid-template-columns:repeat(3,1fr); gap:1rem; align-items:start; }
	@media (max-width:800px){
		.grid3{ grid-template-columns:1fr; }
	}

		/* ---- media library picker --------------------------------------- */
	.picker-overlay{ position:fixed; inset:0; z-index:1000; background:rgba(18,22,28,.55);
	                 display:flex; align-items:center; justify-content:center; padding:1.5rem; }
	.picker{ background:var(--card); border-radius:var(--radius); width:min(880px,100%);
	         max-height:min(680px,90vh); display:flex; flex-direction:column;
	         box-shadow:0 24px 60px rgba(0,0,0,.28); }
	.picker-head{ display:flex; align-items:center; gap:.6rem; padding:.85rem 1rem;
	              border-bottom:1px solid var(--line); }
	.picker-head .ico{ margin-left:auto; }
	.picker-body{ padding:1rem; overflow-y:auto; flex:1; }
	.picker-foot{ display:flex; align-items:center; gap:.6rem; padding:.7rem 1rem;
	              border-top:1px solid var(--line); }
	.picker-foot:empty{ display:none; }
	.picker-foot .muted{ margin:0 auto; font-size:.85rem; }
	.picker-grid{ display:grid; grid-template-columns:repeat(auto-fill,minmax(9.5rem,1fr)); gap:.75rem; }
	.picker-item{ display:block; width:100%; text-align:left; background:var(--card); cursor:pointer;
	              border:1px solid var(--line); border-radius:8px; padding:.45rem; font:inherit;
	              font-size:.78rem; color:var(--ink); overflow:hidden; }
	.picker-item:hover,.picker-item:focus-visible{ border-color:var(--accent);
	                                               box-shadow:0 0 0 2px rgba(31,111,235,.15); }
	.picker-item img{ width:100%; height:6.5rem; object-fit:cover; border-radius:5px;
	                  display:block; background:var(--bg); margin-bottom:.35rem; }
	.picker-item span{ display:block; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }

		/* ---- pager ------------------------------------------------------ */
	.pager{ display:flex; gap:.5rem; align-items:center; flex-wrap:wrap; margin:1.25rem 0; font-size:.9rem; }
	.pager .muted{ margin-right:.5rem; }
	.pager strong{ background:var(--accent); color:#fff; padding:.1rem .45rem; border-radius:4px; }

	/* A short form (one field and a button) should not stretch the full
	   1200px column - it reads as an unbounded text area at that width. */
	form.narrow{ max-width:26rem; }

	/* ---- sign in ---------------------------------------------------- */
	body.adm-login-body{ display:flex; min-height:100vh; align-items:center; justify-content:center; }
	.adm-login{ background:var(--card); border:1px solid var(--line); border-radius:14px;
	            padding:2rem; width:min(400px,92vw); box-shadow:0 18px 45px rgba(0,0,0,.07); }
	.adm-login h1{ margin:0 0 .25rem; font-size:1.25rem; }
	.adm-login .sub{ margin:0 0 1.2rem; }
	.adm-login button{ width:100%; margin-top:.6rem; }
	.adm-login .flash{ margin-bottom:1rem; }

	/* ---- footer ----------------------------------------------------- */
	.adm-foot{ padding:1rem 0 2rem; color:var(--soft); font-size:.8rem; }
</style>
