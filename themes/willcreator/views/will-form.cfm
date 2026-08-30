<style>
	/* Will Wizard — multi-step estate instructions form */

@import url('https://fonts.googleapis.com/css2?family=Libre+Baskerville:wght@400;700&family=Source+Sans+3:wght@400;500;600;700&display=swap');

:root {
	--ww-cream: #f3eee6;
	--ww-cream-dark: #ebe4d8;
	--ww-paper: #ffffff;
	--ww-input: #f7f3eb;
	--ww-border: #d9d0c3;
	--ww-ink: #1a1a1a;
	--ww-muted: #6b6560;
	--ww-copper: #9a6b3f;
	--ww-forest: #1c3d34;
	--ww-forest-hover: #152e28;
	--ww-error: #b42318;
	--ww-radius: 10px;
	--ww-serif: 'Libre Baskerville', Georgia, 'Times New Roman', serif;
	--ww-sans: 'Source Sans 3', 'Segoe UI', sans-serif;
}

.will-wizard {
	font-family: var(--ww-sans);
	color: var(--ww-ink);
	background: var(--ww-cream);
	padding: 2rem 1rem 3rem;
	margin: 0 -15px;
}

.will-wizard *,
.will-wizard *::before,
.will-wizard *::after {
	box-sizing: border-box;
}

.will-wizard__shell {
	display: grid;
	grid-template-columns: minmax(220px, 260px) minmax(0, 1fr);
	gap: 1.75rem;
	max-width: 1080px;
	margin: 0 auto;
	align-items: start;
}

/* ——— Sidebar ——— */

.will-wizard__sidebar {
	padding: 0.5rem 0.25rem;
}

.will-wizard__sidebar-label {
	display: flex;
	align-items: center;
	gap: 0.65rem;
	font-size: 0.7rem;
	font-weight: 600;
	letter-spacing: 0.12em;
	text-transform: uppercase;
	color: var(--ww-copper);
	margin: 0 0 1.25rem;
}

.will-wizard__sidebar-label::before {
	content: '';
	display: block;
	width: 1.25rem;
	height: 1px;
	background: var(--ww-copper);
	flex-shrink: 0;
}

.will-wizard__steps {
	list-style: none;
	margin: 0;
	padding: 0;
}

.will-wizard__step-item {
	margin: 0 0 0.35rem;
}

.will-wizard__step-btn {
	display: grid;
	grid-template-columns: 1.75rem 1fr;
	gap: 0.75rem;
	align-items: start;
	width: 100%;
	padding: 0.7rem 0.85rem;
	border: 0;
	border-radius: 8px;
	background: transparent;
	text-align: left;
	cursor: pointer;
	color: var(--ww-muted);
	font-family: inherit;
	transition: background 0.2s ease, color 0.2s ease;
}

.will-wizard__step-btn:hover:not(:disabled) {
	background: rgba(255, 255, 255, 0.45);
	color: var(--ww-ink);
}

.will-wizard__step-btn:disabled {
	cursor: default;
	opacity: 0.55;
}

.will-wizard__step-btn.is-active {
	background: var(--ww-paper);
	color: var(--ww-ink);
	box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
	opacity: 1;
}

.will-wizard__step-btn.is-complete {
	opacity: 1;
	color: var(--ww-ink);
}

.will-wizard__step-num {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	width: 1.75rem;
	height: 1.75rem;
	border-radius: 50%;
	border: 1.5px solid currentColor;
	font-size: 0.8rem;
	font-weight: 600;
	line-height: 1;
	margin-top: 0.1rem;
}

.will-wizard__step-btn.is-active .will-wizard__step-num {
	background: var(--ww-ink);
	border-color: var(--ww-ink);
	color: #fff;
}

.will-wizard__step-btn.is-complete .will-wizard__step-num {
	background: var(--ww-forest);
	border-color: var(--ww-forest);
	color: #fff;
}

.will-wizard__step-text {
	min-width: 0;
}

.will-wizard__step-title {
	display: block;
	font-size: 0.95rem;
	font-weight: 600;
	line-height: 1.25;
	color: inherit;
}

.will-wizard__step-desc {
	display: block;
	margin-top: 0.15rem;
	font-size: 0.78rem;
	line-height: 1.3;
	color: var(--ww-muted);
}

.will-wizard__step-btn.is-active .will-wizard__step-desc {
	color: #7a746c;
}

/* ——— Panel ——— */

.will-wizard__panel {
	background: var(--ww-paper);
	border: 1px solid var(--ww-border);
	border-radius: var(--ww-radius);
	overflow: hidden;
	box-shadow: 0 8px 28px rgba(40, 30, 20, 0.06);
}

.will-wizard__panel-head {
	background: var(--ww-cream-dark);
	padding: 1.75rem 2rem 1.5rem;
	border-bottom: 1px solid var(--ww-border);
}

.will-wizard__matter {
	display: flex;
	align-items: center;
	gap: 0.75rem;
	margin: 0 0 0.85rem;
	font-size: 0.68rem;
	font-weight: 600;
	letter-spacing: 0.14em;
	text-transform: uppercase;
	color: var(--ww-copper);
}

.will-wizard__matter::before {
	content: '';
	display: block;
	width: 2rem;
	height: 1px;
	background: var(--ww-copper);
}

.will-wizard__heading {
	margin: 0 0 0.65rem;
	font-family: var(--ww-serif);
	font-size: clamp(1.75rem, 3vw, 2.15rem);
	font-weight: 700;
	line-height: 1.15;
	color: var(--ww-forest);
}

.will-wizard__lede {
	margin: 0;
	max-width: 38rem;
	font-size: 0.92rem;
	line-height: 1.5;
	color: var(--ww-muted);
}

.will-wizard__panel-body {
	padding: 1.75rem 2rem 1.25rem;
}

.will-wizard__panel-foot {
	display: flex;
	justify-content: space-between;
	align-items: center;
	gap: 1rem;
	padding: 1.25rem 2rem 1.5rem;
	border-top: 1px solid var(--ww-border);
}

/* ——— Form fields ——— */

.will-wizard__step-panel {
	display: none;
	animation: ww-fade 0.25s ease;
}

.will-wizard__step-panel.is-active {
	display: block;
}

@keyframes ww-fade {
	from { opacity: 0; transform: translateY(4px); }
	to { opacity: 1; transform: translateY(0); }
}

.will-wizard__grid {
	display: grid;
	grid-template-columns: 1fr 1fr;
	gap: 1.15rem 1.25rem;
}

.will-wizard__field {
	display: flex;
	flex-direction: column;
	gap: 0.4rem;
}

.will-wizard__field--full {
	grid-column: 1 / -1;
}

.will-wizard__label {
	font-size: 0.92rem;
	font-weight: 600;
	color: var(--ww-ink);
}

.will-wizard__req {
	color: var(--ww-error);
	margin-left: 0.15rem;
}

.will-wizard__input,
.will-wizard__select,
.will-wizard__textarea {
	width: 100%;
	padding: 0.7rem 0.85rem;
	border: 1px solid var(--ww-border);
	border-radius: 6px;
	background: var(--ww-input);
	color: var(--ww-ink);
	font-family: inherit;
	font-size: 0.95rem;
	line-height: 1.4;
	transition: border-color 0.15s ease, box-shadow 0.15s ease;
}

.will-wizard__textarea {
	min-height: 6.5rem;
	resize: vertical;
}

.will-wizard__input::placeholder,
.will-wizard__textarea::placeholder {
	color: #9a938a;
}

.will-wizard__input:focus,
.will-wizard__select:focus,
.will-wizard__textarea:focus {
	outline: none;
	border-color: var(--ww-forest);
	box-shadow: 0 0 0 3px rgba(28, 61, 52, 0.12);
	background: #fff;
}

.will-wizard__input.is-invalid,
.will-wizard__select.is-invalid,
.will-wizard__textarea.is-invalid {
	border-color: var(--ww-error);
}

.will-wizard__input-wrap {
	position: relative;
}

.will-wizard__input-wrap .will-wizard__input {
	padding-right: 2.5rem;
}

.will-wizard__input-icon {
	position: absolute;
	right: 0.75rem;
	top: 50%;
	transform: translateY(-50%);
	width: 1.1rem;
	height: 1.1rem;
	pointer-events: none;
	opacity: 0.55;
}

.will-wizard__hint {
	margin: 0;
	font-size: 0.8rem;
	color: var(--ww-muted);
}

.will-wizard__error {
	display: none;
	margin: 0;
	font-size: 0.8rem;
	color: var(--ww-error);
}

.will-wizard__field.has-error .will-wizard__error {
	display: block;
}

.will-wizard__repeatable {
	display: flex;
	flex-direction: column;
	gap: 1rem;
}

.will-wizard__card {
	padding: 1rem;
	border: 1px dashed var(--ww-border);
	border-radius: 8px;
	background: #faf8f4;
}

.will-wizard__card-title {
	margin: 0 0 0.85rem;
	font-size: 0.85rem;
	font-weight: 600;
	color: var(--ww-forest);
}

.will-wizard__add-btn,
.will-wizard__link-btn {
	appearance: none;
	border: 0;
	background: none;
	padding: 0;
	font-family: inherit;
	font-size: 0.88rem;
	font-weight: 600;
	color: var(--ww-forest);
	cursor: pointer;
	text-decoration: underline;
	text-underline-offset: 2px;
}

.will-wizard__add-btn:hover,
.will-wizard__link-btn:hover {
	color: var(--ww-forest-hover);
}

.will-wizard__review {
	display: flex;
	flex-direction: column;
	gap: 1rem;
}

.will-wizard__review-block {
	padding: 1rem 1.1rem;
	border: 1px solid var(--ww-border);
	border-radius: 8px;
	background: var(--ww-input);
}

.will-wizard__review-block h3 {
	margin: 0 0 0.65rem;
	font-size: 0.95rem;
	font-weight: 700;
	color: var(--ww-forest);
}

.will-wizard__review-dl {
	display: grid;
	grid-template-columns: minmax(8rem, 11rem) 1fr;
	gap: 0.35rem 1rem;
	margin: 0;
	font-size: 0.9rem;
}

.will-wizard__review-dl dt {
	color: var(--ww-muted);
	font-weight: 500;
}

.will-wizard__review-dl dd {
	margin: 0;
	color: var(--ww-ink);
	word-break: break-word;
}

.will-wizard__status {
	display: none;
	margin: 0 0 1rem;
	padding: 0.75rem 1rem;
	border-radius: 6px;
	font-size: 0.9rem;
}

.will-wizard__status.is-visible {
	display: block;
}

.will-wizard__status--success {
	background: #e7f3ee;
	color: var(--ww-forest);
	border: 1px solid #b7d6c8;
}

.will-wizard__status--error {
	background: #fdeceb;
	color: var(--ww-error);
	border: 1px solid #f0c2be;
}

/* ——— Buttons ——— */

.will-wizard__btn {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	gap: 0.45rem;
	min-height: 2.75rem;
	padding: 0.65rem 1.35rem;
	border: 0;
	border-radius: 4px;
	font-family: inherit;
	font-size: 0.82rem;
	font-weight: 700;
	letter-spacing: 0.08em;
	text-transform: uppercase;
	cursor: pointer;
	transition: background 0.15s ease, transform 0.1s ease;
}

.will-wizard__btn:active {
	transform: translateY(1px);
}

.will-wizard__btn--primary {
	background: var(--ww-forest);
	color: #fff;
	margin-left: auto;
}

.will-wizard__btn--primary:hover {
	background: var(--ww-forest-hover);
}

.will-wizard__btn--ghost {
	background: transparent;
	color: var(--ww-muted);
	letter-spacing: 0.04em;
}

.will-wizard__btn--ghost:hover {
	color: var(--ww-ink);
}

.will-wizard__btn[hidden] {
	display: none !important;
}

/* ——— Responsive ——— */

@media (max-width: 860px) {
	.will-wizard__shell {
		grid-template-columns: 1fr;
		gap: 1.25rem;
	}

	.will-wizard__steps {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.25rem;
	}

	.will-wizard__step-desc {
		display: none;
	}
}

@media (max-width: 600px) {
	.will-wizard {
		padding: 1rem 0.75rem 2rem;
	}

	.will-wizard__panel-head,
	.will-wizard__panel-body,
	.will-wizard__panel-foot {
		padding-left: 1.15rem;
		padding-right: 1.15rem;
	}

	.will-wizard__grid {
		grid-template-columns: 1fr;
	}

	.will-wizard__steps {
		grid-template-columns: 1fr;
	}

	.will-wizard__panel-foot {
		flex-direction: column-reverse;
		align-items: stretch;
	}

	.will-wizard__btn--primary {
		margin-left: 0;
	}

	.will-wizard__review-dl {
		grid-template-columns: 1fr;
	}
}

form {
	max-width: 100%;
}

</style>

<script>
	/* ============================================================================
   Wardlow Estate Law — Document Wizard
   Client-side step navigation, validation, repeatable cards and review assembly.
   Server save: themes/default/modules/will_wizard/inc/save_submission.cfm
   ========================================================================== */
document.addEventListener("DOMContentLoaded", function () {
(function () {
  "use strict";
  var form = document.getElementById("will-form");
  if (!form || form.getAttribute("data-ww-ready") === "1") return;
  form.setAttribute("data-ww-ready", "1");

  var steps = Array.prototype.slice.call(form.querySelectorAll(".step"));
  var railItems = Array.prototype.slice.call(document.querySelectorAll(".rail li"));
  var btnBack = document.getElementById("wiz-back");
  var btnNext = document.getElementById("wiz-next");
  var btnSubmit = document.getElementById("wiz-submit");
  var current = 0;
  var FEE_ROLES = { Solicitor: true, Accountant: true };

  function show(index) {
    steps.forEach(function (s, i) { s.setAttribute("data-active", String(i === index)); });
    railItems.forEach(function (li, i) {
      li.setAttribute("data-state", i < index ? "done" : i === index ? "active" : "");
    });
    if (btnBack) btnBack.style.visibility = index === 0 ? "hidden" : "visible";
    var last = index === steps.length - 1;
    if (btnNext) btnNext.style.display = last ? "none" : "inline-flex";
    if (btnSubmit) btnSubmit.style.display = last ? "inline-flex" : "none";
    if (last) buildReview();
    window.scrollTo({ top: form.offsetTop - 100, behavior: "smooth" });
    current = index;
  }

  function isValidDob(value) {
    var m = String(value || "").trim().match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
    if (!m) return false;
    var d = parseInt(m[1], 10);
    var mo = parseInt(m[2], 10);
    var y = parseInt(m[3], 10);
    var dt = new Date(y, mo - 1, d);
    return dt.getFullYear() === y && dt.getMonth() === mo - 1 && dt.getDate() === d;
  }

  function validateStep(index) {
    var invalid = null;
    steps[index].querySelectorAll("[required]").forEach(function (el) {
      if (el.disabled || el.offsetParent === null && el.type !== "hidden") {
        // still validate required checkboxes even if layout quirks
      }
      var empty = el.type === "checkbox" ? !el.checked : !String(el.value || "").trim();
      if (empty && !invalid) invalid = el;
    });

    var dob = steps[index].querySelector("#wm_dob");
    if (dob && String(dob.value || "").trim() && !isValidDob(dob.value) && !invalid) {
      invalid = dob;
    }

    if (invalid) {
      invalid.focus();
      invalid.style.borderColor = "var(--claret)";
      invalid.addEventListener("input", function h() {
        invalid.style.borderColor = "";
        invalid.removeEventListener("input", h);
      });
      invalid.addEventListener("change", function h() {
        invalid.style.borderColor = "";
        invalid.removeEventListener("change", h);
      });
      return false;
    }
    return true;
  }

  function fieldValue(el) {
    if (!el) return "";
    if (el.type === "checkbox") return el.checked ? "1" : "";
    return String(el.value || "").trim();
  }

  function collectCard(card) {
    var row = {};
    var hasAny = false;
    card.querySelectorAll("[data-field]").forEach(function (el) {
      var key = el.getAttribute("data-field");
      var val = fieldValue(el);
      row[key] = val;
      if (val) hasAny = true;
    });
    return hasAny ? row : null;
  }

  function collectRepeat(type) {
    var rows = [];
    form.querySelectorAll('[data-repeat][data-collect="' + type + '"] .person-card').forEach(function (card) {
      var row = collectCard(card);
      if (row) rows.push(row);
    });
    return rows;
  }

  function collectGiftsJson() {
    return JSON.stringify(collectRepeat("gift").map(function (g) {
      return { item: g.item || "", beneficiary: g.beneficiary || "" };
    }));
  }

  function syncHiddenJson() {
    var map = {
      gifts_json: collectGiftsJson(),
      substitute_executors_json: JSON.stringify(collectRepeat("substitute_executor")),
      backup_guardians_json: JSON.stringify(collectRepeat("backup_guardian")),
      additional_attorneys_json: JSON.stringify(collectRepeat("additional_attorney")),
      backup_enduring_guardians_json: JSON.stringify(collectRepeat("backup_enduring_guardian"))
    };
    Object.keys(map).forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.value = map[id];
    });
  }

  function updateFeeVisibility(scope) {
    (scope || form).querySelectorAll("[data-fee-trigger]").forEach(function (sel) {
      var field = sel.closest(".field");
      var wrap = field && field.nextElementSibling && field.nextElementSibling.hasAttribute("data-fee-wrap")
        ? field.nextElementSibling
        : null;
      if (!wrap) return;
      var show = !!FEE_ROLES[sel.value];
      wrap.style.display = show ? "" : "none";
      if (!show) {
        var cb = wrap.querySelector('input[type="checkbox"]');
        if (cb) cb.checked = false;
      }
    });
  }

  function updateActModeVisibility() {
    form.querySelectorAll("[data-repeat][data-act-mode-target]").forEach(function (container) {
      var targetId = container.getAttribute("data-act-mode-target");
      var wrap = document.getElementById(targetId);
      if (!wrap) return;
      var count = container.querySelectorAll(".person-card").length;
      // primary (1) + substitutes/additional/backups
      var show = count >= 1;
      wrap.style.display = show ? "" : "none";
      if (!show) {
        var sel = wrap.querySelector("select");
        if (sel) sel.value = "";
      }
    });
  }

  function wireDobMask() {
    var dob = document.getElementById("wm_dob");
    if (!dob) return;
    dob.addEventListener("input", function () {
      var digits = dob.value.replace(/\D/g, "").slice(0, 8);
      var out = digits;
      if (digits.length > 4) {
        out = digits.slice(0, 2) + "/" + digits.slice(2, 4) + "/" + digits.slice(4);
      } else if (digits.length > 2) {
        out = digits.slice(0, 2) + "/" + digits.slice(2);
      }
      dob.value = out;
    });
  }

  function setupRepeatables() {
    form.querySelectorAll("[data-repeat]").forEach(function (container) {
      var parent = container.parentNode;
      var addBtn = parent.querySelector(".btn-add");
      var tpl = parent.querySelector("template[data-repeat-template]");
      var min = parseInt(container.getAttribute("data-min") || "1", 10);
      if (!addBtn) return;

      function getTemplateCard() {
        if (tpl && tpl.content) {
          return tpl.content.querySelector(".person-card");
        }
        return container.querySelector(".person-card");
      }

      function reindex() {
        var label = addBtn.getAttribute("data-label") || "Item";
        var cards = container.querySelectorAll(".person-card");
        cards.forEach(function (card, i) {
          var title = card.querySelector(".person-card__head b");
          if (title) title.textContent = label + " " + (i + 1);
          var removeBtn = card.querySelector(".btn-remove");
          if (removeBtn) {
            removeBtn.style.display = cards.length > min ? "inline" : "none";
          }
        });
        updateActModeVisibility();
        updateFeeVisibility(container);
      }

      function addCard() {
        var templateCard = getTemplateCard();
        if (!templateCard) return;
        var clone = templateCard.cloneNode(true);
        clone.querySelectorAll("input, select, textarea").forEach(function (f) {
          if (f.type === "checkbox" || f.type === "radio") f.checked = false;
          else f.value = "";
        });
        clone.querySelectorAll("[data-fee-wrap]").forEach(function (w) {
          w.style.display = "none";
        });
        container.appendChild(clone);
        reindex();
      }

      container.addEventListener("click", function (e) {
        if (e.target.classList.contains("btn-remove")) {
          var cards = container.querySelectorAll(".person-card");
          if (cards.length > min) {
            e.target.closest(".person-card").remove();
            reindex();
          }
        }
      });

      container.addEventListener("change", function (e) {
        if (e.target && e.target.hasAttribute("data-fee-trigger")) {
          updateFeeVisibility(container);
        }
      });

      addBtn.addEventListener("click", addCard);
      console.log('add btn');
      reindex();
    });
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function valByName(name) {
    var radios = form.querySelectorAll('[name="' + name + '"]');
    if (radios.length > 1 && radios[0].type === "radio") {
      var checked = form.querySelector('[name="' + name + '"]:checked');
      return checked ? String(checked.value || "").trim() : "";
    }
    var el = form.querySelector('[name="' + name + '"]');
    if (!el) return "";
    if (el.type === "checkbox") return el.checked ? "Yes" : "";
    return String(el.value || "").trim();
  }

  function buildReview() {
    var target = document.getElementById("review-body");
    if (!target) return;

    syncHiddenJson();

    var groups = {
      "Will Maker": ["wm_fullname", "wm_dob", "wm_address", "wm_marital", "wm_email", "wm_phone"],
      "Executor": ["ex_name", "ex_address", "ex_relationship", "ex_email", "ex_phone", "ex_can_charge_fees", "ex_act_mode"],
      "Guardian for children": ["guard_name", "guard_address", "guard_children"],
      "Estate & beneficiaries": ["estate_residue"],
      "Enduring Power of Attorney": ["poa_name", "poa_address", "poa_email", "poa_phone", "poa_commence", "poa_act_mode"],
      "Enduring Guardian": ["eg_name", "eg_address", "eg_email", "eg_phone", "eg_directions", "eg_act_mode"],
      "Disposal of the body": ["body_disposal", "body_instructions"],
      "Digital assets": ["da_include_clauses", "da_instructions", "da_notes"]
    };
    var labels = {
      wm_fullname: "Full legal name", wm_dob: "Date of birth", wm_address: "Address", wm_marital: "Marital status",
      wm_email: "Email", wm_phone: "Contact number",
      ex_name: "Executor", ex_address: "Address", ex_relationship: "Relationship",
      ex_email: "Email", ex_phone: "Phone", ex_can_charge_fees: "May charge fees", ex_act_mode: "Act jointly/severally",
      guard_name: "Guardian", guard_address: "Address", guard_children: "For children",
      estate_residue: "Residuary estate",
      poa_name: "Attorney", poa_address: "Address", poa_email: "Email", poa_phone: "Phone",
      poa_commence: "Authority begins", poa_act_mode: "Act jointly/severally",
      eg_name: "Enduring guardian", eg_address: "Address", eg_email: "Email", eg_phone: "Phone",
      eg_directions: "Directions", eg_act_mode: "Act jointly/severally",
      body_disposal: "Cremated or buried", body_instructions: "Special instructions",
      da_include_clauses: "Include digital asset clauses", da_instructions: "Digital asset instructions", da_notes: "Miscellaneous notes"
    };

    var html = "";
    Object.keys(groups).forEach(function (title) {
      var rows = "";
      groups[title].forEach(function (name) {
        var val = valByName(name);
        if (name === "ex_can_charge_fees") {
          var feeEl = form.querySelector('[name="ex_can_charge_fees"]');
          val = feeEl && feeEl.checked ? "Yes" : "No";
        }
        rows += "<dt>" + labels[name] + "</dt><dd>" + escapeHtml(val || "—") + "</dd>";
      });

      if (title === "Executor") {
        collectRepeat("substitute_executor").forEach(function (r, i) {
          rows += "<dt>Substitute Executor " + (i + 1) + "</dt><dd>" +
            escapeHtml([r.ex_name, r.ex_relationship, r.ex_email, r.ex_phone].filter(Boolean).join(" · ") || "—") +
            "</dd>";
        });
      }
      if (title === "Guardian for children") {
        collectRepeat("backup_guardian").forEach(function (r, i) {
          rows += "<dt>Backup Guardian " + (i + 1) + "</dt><dd>" +
            escapeHtml([r.guard_name, r.guard_address].filter(Boolean).join(" · ") || "—") +
            "</dd>";
        });
      }
      if (title === "Estate & beneficiaries") {
        var gifts = collectRepeat("gift");
        if (gifts.length) {
          gifts.forEach(function (g, i) {
            rows += "<dt>Gift " + (i + 1) + "</dt><dd>" +
              escapeHtml((g.item || "—") + " ? " + (g.beneficiary || "—")) + "</dd>";
          });
        } else {
          rows += "<dt>Specific gifts</dt><dd>—</dd>";
        }
      }
      if (title === "Enduring Power of Attorney") {
        collectRepeat("additional_attorney").forEach(function (r, i) {
          rows += "<dt>Additional Attorney " + (i + 1) + "</dt><dd>" +
            escapeHtml([r.poa_name, r.poa_email, r.poa_phone].filter(Boolean).join(" · ") || "—") +
            "</dd>";
        });
      }
      if (title === "Enduring Guardian") {
        collectRepeat("backup_enduring_guardian").forEach(function (r, i) {
          rows += "<dt>Backup Enduring Guardian " + (i + 1) + "</dt><dd>" +
            escapeHtml([r.eg_name, r.eg_email, r.eg_phone].filter(Boolean).join(" · ") || "—") +
            "</dd>";
        });
      }

      html += '<div class="review-group"><h4>' + title + "</h4><dl>" + rows + "</dl></div>";
    });
    target.innerHTML = html;
  }

  if (btnNext) {
    btnNext.addEventListener("click", function () {
      if (validateStep(current)) show(Math.min(current + 1, steps.length - 1));
    });
  }
  if (btnBack) {
    btnBack.addEventListener("click", function () { show(Math.max(current - 1, 0)); });
  }

  railItems.forEach(function (li, i) {
    li.style.cursor = "pointer";
    li.addEventListener("click", function () { if (i <= current) show(i); });
  });

  form.addEventListener("change", function (e) {
    if (e.target && e.target.hasAttribute("data-fee-trigger")) {
      updateFeeVisibility();
    }
  });

  wireDobMask();
  setupRepeatables();
  updateFeeVisibility();
  updateActModeVisibility();

  function fillCard(card, row) {
    card.querySelectorAll("[data-field]").forEach(function (el) {
      var key = el.getAttribute("data-field");
      if (!Object.prototype.hasOwnProperty.call(row, key)) return;
      var val = row[key];
      if (el.type === "checkbox") {
        el.checked = val === "1" || val === true || val === "true";
      } else {
        el.value = val == null ? "" : String(val);
      }
    });
  }

  function restoreRepeat(type, jsonId, normalize) {
    var hidden = document.getElementById(jsonId);
    if (!hidden || !String(hidden.value || "").trim()) return;
    var rows;
    try {
      rows = JSON.parse(hidden.value);
    } catch (err) {
      return;
    }
    if (!Array.isArray(rows) || !rows.length) return;
    var container = form.querySelector('[data-repeat][data-collect="' + type + '"]');
    if (!container) return;
    var addBtn = container.parentNode.querySelector(".btn-add");
    rows.forEach(function (row, i) {
      var data = normalize ? normalize(row) : row;
      var cards = container.querySelectorAll(".person-card");
      if (type === "gift" && i === 0 && cards[0]) {
        fillCard(cards[0], data);
        return;
      }
      if (addBtn) addBtn.click();
      cards = container.querySelectorAll(".person-card");
      fillCard(cards[cards.length - 1], data);
    });
  }

  restoreRepeat("gift", "gifts_json", function (g) {
    return { item: g.item || "", beneficiary: g.beneficiary || "" };
  });
  restoreRepeat("substitute_executor", "substitute_executors_json");
  restoreRepeat("backup_guardian", "backup_guardians_json");
  restoreRepeat("additional_attorney", "additional_attorneys_json");
  restoreRepeat("backup_enduring_guardian", "backup_enduring_guardians_json");

  form.setAttribute("data-autowire", "false");
  form.setAttribute("data-async", "false");

  form.addEventListener("submit", function (e) {
    if (!validateStep(current)) {
      e.preventDefault();
      e.stopImmediatePropagation();
      return;
    }
    syncHiddenJson();
    e.stopImmediatePropagation();
  }, true);

  if (steps.length) show(0);
})();
});

</script>
<cfoutput>
<main data-view="will-form" class="wizard">
	<cfif args.errors.len()>
		<div class="flash error" role="alert">
			<cfloop array="#args.errors#" index="problem">
				<p style="margin:.15rem 0">#encodeForHTML( problem )#</p>
			</cfloop>
		</div>
	</cfif>

	<div class="wrap wizard__layout">
		<aside class="rail" aria-label="Your progress">
			<span class="eyebrow" style="margin-bottom:1.2rem;display:flex">Your documents</span>

			<ol>
				<li data-state="active" style="cursor: pointer;"><span class="rail__dot">1</span><span class="rail__label"><b>About you</b><span>The Will Maker</span></span></li>
				<li data-state="" style="cursor: pointer;"><span class="rail__dot">2</span><span class="rail__label"><b>Executor</b><span>Who administers your estate</span></span></li>
				<li data-state="" style="cursor: pointer;"><span class="rail__dot">3</span><span class="rail__label"><b>Guardianship</b><span>For children under 18</span></span></li>
				<li data-state="" style="cursor: pointer;"><span class="rail__dot">4</span><span class="rail__label"><b>Your estate</b><span>Gifts &amp; beneficiaries</span></span></li>
				<li data-state="" style="cursor: pointer;"><span class="rail__dot">5</span><span class="rail__label"><b>Power of Attorney</b><span>Financial &amp; legal</span></span></li>
				<li data-state="" style="cursor: pointer;"><span class="rail__dot">6</span><span class="rail__label"><b>Enduring Guardian</b><span>Health &amp; lifestyle</span></span></li>
				<li data-state="" style="cursor: pointer;"><span class="rail__dot">7</span><span class="rail__label"><b>Disposal of the body</b><span>Cremation or burial</span></span></li>
				<li data-state="" style="cursor: pointer;"><span class="rail__dot">8</span><span class="rail__label"><b>Digital assets</b><span>Online accounts &amp; data</span></span></li>
				<li data-state="" style="cursor: pointer;"><span class="rail__dot">9</span><span class="rail__label"><b>Review &amp; submit</b><span>Send for solicitor review</span></span></li>
			</ol>
		</aside>

	<form id="will-form" method="post" action="#xmlFormat( args.action )#" class="form-deed" novalidate>
		<input type="hidden" name="csrfToken" value="#xmlFormat( args.csrfToken )#">
		<input type="hidden" id="gifts_json" name="gifts_json" value="#encodeForHTMLAttribute( args.values.gifts_json ?: '' )#">
		<input type="hidden" id="substitute_executors_json" name="substitute_executors_json" value="#encodeForHTMLAttribute( args.values.substitute_executors_json ?: '' )#">
		<input type="hidden" id="backup_guardians_json" name="backup_guardians_json" value="#encodeForHTMLAttribute( args.values.backup_guardians_json ?: '' )#">
		<input type="hidden" id="additional_attorneys_json" name="additional_attorneys_json" value="#encodeForHTMLAttribute( args.values.additional_attorneys_json ?: '' )#">
		<input type="hidden" id="backup_enduring_guardians_json" name="backup_enduring_guardians_json" value="#encodeForHTMLAttribute( args.values.backup_enduring_guardians_json ?: '' )#">

		<div style="position:absolute;left:-9999px" aria-hidden="true">
			<label for="#xmlFormat( args.honeypotField )#">Leave this blank</label>
			<input type="text" id="#xmlFormat( args.honeypotField )#"
			       name="#xmlFormat( args.honeypotField )#" tabindex="-1" autocomplete="off">
		</div>

		<div class="form-deed__head">
			<span class="eyebrow">In the matter of the estate of</span>
			<h2 id="deed-title">Your instructions</h2>
			<p>All fields marked <span style="color:var(--claret)">*</span> are required. Your answers are saved to your account and are only shared with our reviewing solicitor.</p>
		</div>

		<div class="form-deed__body">
			<section class="step" data-active="true" aria-label="About you">
			<fieldset class="fieldset">
			<div class="field-grid">
			<div class="field field--full">
			<label for="wm_fullname">Full legal name <span class="req">*</span></label>
			<input id="wm_fullname" name="wm_fullname" type="text" required="" placeholder="e.g. John Allan Brown" value="#xmlFormat( args.values.wm_fullname ?: '' )#">
			<span class="hint">Exactly as it appears on your identification.</span>
			</div>
			<div class="field">
			<label for="wm_dob">Date of birth <span class="req">*</span></label>
			<input id="wm_dob" name="wm_dob" type="text" required="" inputmode="numeric" placeholder="DD/MM/YYYY" pattern="\d{2}/\d{2}/\d{4}" maxlength="10" autocomplete="bday" value="#xmlFormat( args.values.wm_dob ?: '' )#">
			<span class="hint">Format: DD/MM/YYYY</span>
			</div>
			<div class="field">
			<label for="wm_marital">Marital status <span class="req">*</span></label>
			<select id="wm_marital" name="wm_marital" required="">
			<option value="">Please choose…</option>
			<option value="Single"<cfif ( args.values.wm_marital ?: "" ) eq "Single"> selected</cfif>>Single</option>
			<option value="Married"<cfif ( args.values.wm_marital ?: "" ) eq "Married"> selected</cfif>>Married</option>
			<option value="De facto"<cfif ( args.values.wm_marital ?: "" ) eq "De facto"> selected</cfif>>De facto</option>
			<option value="Divorced"<cfif ( args.values.wm_marital ?: "" ) eq "Divorced"> selected</cfif>>Divorced</option>
			<option value="Widowed"<cfif ( args.values.wm_marital ?: "" ) eq "Widowed"> selected</cfif>>Widowed</option>
			</select>
			</div>
			<div class="field field--full">
			<label for="wm_address">Residential address <span class="req">*</span></label>
			<input id="wm_address" name="wm_address" type="text" required="" placeholder="Street, suburb, state, postcode" value="#xmlFormat( args.values.wm_address ?: '' )#">
			</div>
			<div class="field">
			<label for="wm_email">Email <span class="req">*</span></label>
			<input id="wm_email" name="wm_email" type="email" required="" placeholder="you@example.com" value="#xmlFormat( args.values.wm_email ?: '' )#"></div>
			<div class="field">
			<label for="wm_phone">Contact number</label>
			<input id="wm_phone" name="wm_phone" type="tel" placeholder="04XX XXX XXX" value="#xmlFormat( args.values.wm_phone ?: '' )#">
			</div>
			</div>
			</fieldset>
			</section>
			<section class="step" aria-label="Executor" data-active="false">
			<div class="notice" style="margin-bottom:1.5rem">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="10"></circle><path d="M12 16v-4M12 8h.01"></path></svg>
			<span>Your <b>executor</b> is the person who carries out the instructions in your Will. Choose someone you trust; you can also name substitute executors in case your first choice is unable to act.</span>
			</div>
			<fieldset class="fieldset">
			<div class="field-grid">
			<div class="field field--full">
			<label for="ex_name">Executor's full name <span class="req">*</span></label>
			<input id="ex_name" name="ex_name" type="text" required="" value="#xmlFormat( args.values.ex_name ?: '' )#">
			</div>
			<div class="field field--full">
			<label for="ex_address">Executor's address <span class="req">*</span></label>
			<input id="ex_address" name="ex_address" type="text" required="" value="#xmlFormat( args.values.ex_address ?: '' )#">
			</div>
			<div class="field">
			<label for="ex_relationship">Relationship to you</label>
			<select id="ex_relationship" name="ex_relationship" data-fee-trigger="">
			<option value="">Please choose…</option>
			<option value="Solicitor">Solicitor</option>
			<option value="Accountant">Accountant</option>
			<option value="Son">Son</option>
			<option value="Daughter">Daughter</option>
			<option value="Wife">Wife</option>
			<option value="Spouse">Spouse</option>
			<option value="Partner">Partner</option>
			</select>
			</div>
			<div class="field" data-fee-wrap="" style="display:none">
			<label class="checkbox-label" style="display:flex;gap:.7rem;align-items:flex-start;margin-top:1.7rem">
			<input type="checkbox" id="ex_can_charge_fees" name="ex_can_charge_fees" value="1"<cfif listFindNoCase( "1,true,yes,on", args.values.ex_can_charge_fees ?: "" )> checked</cfif>>
			<span>is able to charge fees for services provided</span>
			</label>
			</div>
			<div class="field">
			<label for="ex_email">Email Address</label>
			<input id="ex_email" name="ex_email" type="email" value="#xmlFormat( args.values.ex_email ?: '' )#">
			</div>
			<div class="field">
			<label for="ex_phone">Phone Number</label>
			<input id="ex_phone" name="ex_phone" type="tel" value="#xmlFormat( args.values.ex_phone ?: '' )#">
			</div>
			</div>
			</fieldset><div class="field field--full" style="margin-top:1.5rem">
			<label>Substitute Executor(s)</label>
			<div data-repeat="" data-min="0" data-collect="substitute_executor" data-act-mode-target="ex_act_mode_wrap">
			</div>
			<template data-repeat-template="">
			<div class="person-card">
			<div class="person-card__head"><b>Substitute Executor 1</b><button type="button" class="btn-remove">Remove</button></div>
			<div class="field-grid">
			<div class="field field--full">
			<label>Full name</label>
			<input type="text" name="sub_ex_name" data-field="ex_name">
			</div>
			<div class="field field--full">
			<label>Address</label>
			<input type="text" name="sub_ex_address" data-field="ex_address">
			</div>
			<div class="field">
			<label>Relationship to you</label>
			<select name="sub_ex_relationship" data-field="ex_relationship" data-fee-trigger="">
			<option value="">Please choose…</option>
			<option value="Solicitor">Solicitor</option>
			<option value="Accountant">Accountant</option>
			<option value="Son">Son</option>
			<option value="Daughter">Daughter</option>
			<option value="Wife">Wife</option>
			<option value="Spouse">Spouse</option>
			<option value="Partner">Partner</option>
			</select>
			</div>
			<div class="field" data-fee-wrap="" style="display:none">
			<label class="checkbox-label" style="display:flex;gap:.7rem;align-items:flex-start;margin-top:1.7rem">
			<input type="checkbox" name="sub_ex_can_charge_fees" data-field="ex_can_charge_fees" value="1">
			<span>is able to charge fees for services provided</span>
			</label>
			</div>
			<div class="field">
			<label>Email Address</label>
			<input type="email" name="sub_ex_email" data-field="ex_email">
			</div>
			<div class="field">
			<label>Phone Number</label>
			<input type="tel" name="sub_ex_phone" data-field="ex_phone">
			</div>
			</div>
			</div>
			</template>
			<button type="button" class="btn-add" data-label="Substitute Executor">+ Add substitute executor</button>
			</div><div class="field field--full" id="ex_act_mode_wrap" data-act-mode="" style="display:none;margin-top:1.2rem">
			<label for="ex_act_mode">May executors act jointly or severally?</label>
			<select id="ex_act_mode" name="ex_act_mode">
			<option value="">Please choose…</option>
			<option value="Jointly">Jointly</option>
			<option value="Severally">Severally</option>
			</select>
			<span class="hint">Shown when you have named more than one executor (including substitutes).</span>
			</div>
			</section>
			<section class="step" aria-label="Guardianship" data-active="false">
			<div class="notice" style="margin-bottom:1.5rem">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M20 21v-2a4 4 0 0 0-3-3.87M4 21v-2a4 4 0 0 1 3-3.87M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"></path></svg>
			<span>If you have children under 18, you can appoint a <b>guardian</b> to care for them. If this doesn't apply to you, you can skip to the next step.</span>
			</div>
			<fieldset class="fieldset">
			<div class="field-grid">
			<div class="field field--full">
			<label for="guard_name">Proposed guardian's full name</label>
			<input id="guard_name" name="guard_name" type="text" value="#xmlFormat( args.values.guard_name ?: '' )#">
			</div>
			<div class="field field--full">
			<label for="guard_address">Guardian's address</label>
			<input id="guard_address" name="guard_address" type="text" value="#xmlFormat( args.values.guard_address ?: '' )#">
			</div>
			<div class="field field--full">
			<label for="guard_children">Children this appointment covers</label>
			<textarea id="guard_children" name="guard_children" placeholder="Full name and date of birth of each child">#encodeForHTML( args.values.guard_children ?: '' )#</textarea>
			</div>
			</div>
			</fieldset><div class="field field--full" style="margin-top:1.5rem">
			<label>Backup Guardianship</label>
			<div data-repeat="" data-min="0" data-collect="backup_guardian">
			</div>
			<template data-repeat-template="">
			<div class="person-card">
			<div class="person-card__head"><b>Backup Guardian 1</b><button type="button" class="btn-remove">Remove</button></div>
			<div class="field-grid">
			<div class="field field--full">
			<label>Full name</label>
			<input type="text" name="bak_guard_name" data-field="guard_name">
			</div>
			<div class="field field--full">
			<label>Address</label>
			<input type="text" name="bak_guard_address" data-field="guard_address">
			</div>
			<div class="field field--full">
			<label>Children this appointment covers</label>
			<textarea name="bak_guard_children" data-field="guard_children" placeholder="Full name and date of birth of each child"></textarea>
			</div>
			</div>
			</div>
			</template>
			<button type="button" class="btn-add" data-label="Backup Guardian">+ Add backup guardian</button>
			</div>
			</section>
			<section class="step" aria-label="Your estate" data-active="false">
			<div class="field field--full" style="margin-bottom:1.4rem">
			<label>Specific gifts (optional)</label>
			<div data-repeat="" data-min="1" data-collect="gift">
			<div class="person-card">
			<div class="person-card__head"><b>Gift 1</b><button type="button" class="btn-remove" style="display:none">Remove</button></div>
			<div class="field-grid">
			<div class="field field--full">
			<label>Item or amount</label>
			<input type="text" name="gift_item" data-field="item" placeholder="e.g. My grandmother's ring, or $10,000">
			</div>
			<div class="field field--full">
			<label>To whom (name &amp; relationship)</label>
			<input type="text" name="gift_beneficiary" data-field="beneficiary" placeholder="e.g. My niece, Sarah Wardlow">
			</div>
			</div>
			</div>
			</div>
			<button type="button" class="btn-add" data-label="Gift">+ Add another specific gift</button>
			</div>
			<div class="field field--full">
			<label for="estate_residue">Everything else — the residuary estate <span class="req">*</span></label>
			<textarea id="estate_residue" name="estate_residue" required="" placeholder="e.g. Everything remaining to be divided equally between my three children. If any predeceases me, their share passes to their children.">#encodeForHTML( args.values.estate_residue ?: '' )#</textarea>
			<span class="hint">Describe in plain words how the remainder of your estate should be shared.</span>
			</div>
			</section>
			<section class="step" aria-label="Power of Attorney" data-active="false">
			<div class="notice" style="margin-bottom:1.5rem">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
			<span>An <b>Enduring Power of Attorney</b> lets someone manage your financial and legal affairs. It's optional, but recommended alongside your Will.</span>
			</div>
			<fieldset class="fieldset">
			<div class="field-grid">
			<div class="field field--full">
			<label for="poa_name">Attorney's full name</label>
			<input id="poa_name" name="poa_name" type="text" value="#xmlFormat( args.values.poa_name ?: '' )#">
			</div>
			<div class="field field--full">
			<label for="poa_address">Attorney's address</label>
			<input id="poa_address" name="poa_address" type="text" value="#xmlFormat( args.values.poa_address ?: '' )#">
			</div>
			<div class="field">
			<label for="poa_email">Email Address</label>
			<input id="poa_email" name="poa_email" type="email" value="#xmlFormat( args.values.poa_email ?: '' )#">
			</div>
			<div class="field">
			<label for="poa_phone">Phone Number</label>
			<input id="poa_phone" name="poa_phone" type="tel" value="#xmlFormat( args.values.poa_phone ?: '' )#">
			</div>
			<div class="field field--full">
			<label for="poa_commence">When should this authority begin?</label>
			<select id="poa_commence" name="poa_commence">
			<option value="">Please choose…</option>
			<option value="Immediately, once made">Immediately, once made</option>
			<option value="Only if I lose capacity to make decisions">Only if I lose capacity to make decisions</option>
			<option value="On a date or event I will specify with the solicitor">On a date or event I will specify with the solicitor</option>
			</select>
			</div>
			</div>
			</fieldset><div class="field field--full" style="margin-top:1.5rem">
			<label>Additional Attorney(s)</label>
			<div data-repeat="" data-min="0" data-collect="additional_attorney" data-act-mode-target="poa_act_mode_wrap">
			</div>
			<template data-repeat-template="">
			<div class="person-card">
			<div class="person-card__head"><b>Additional Attorney 1</b><button type="button" class="btn-remove">Remove</button></div>
			<div class="field-grid">
			<div class="field field--full">
			<label>Full name</label>
			<input type="text" name="add_poa_name" data-field="poa_name">
			</div>
			<div class="field field--full">
			<label>Address</label>
			<input type="text" name="add_poa_address" data-field="poa_address">
			</div>
			<div class="field">
			<label>Email Address</label>
			<input type="email" name="add_poa_email" data-field="poa_email">
			</div>
			<div class="field">
			<label>Phone Number</label>
			<input type="tel" name="add_poa_phone" data-field="poa_phone">
			</div>
			<div class="field field--full">
			<label>When should this authority begin?</label>
			<select name="add_poa_commence" data-field="poa_commence">
			<option value="">Please choose…</option>
			<option value="Immediately, once made">Immediately, once made</option>
			<option value="Only if I lose capacity to make decisions">Only if I lose capacity to make decisions</option>
			<option value="On a date or event I will specify with the solicitor">On a date or event I will specify with the solicitor</option>
			</select>
			</div>
			</div>
			</div>
			</template>
			<button type="button" class="btn-add" data-label="Additional Attorney">+ Add additional attorney</button>
			</div><div class="field field--full" id="poa_act_mode_wrap" data-act-mode="" style="display:none;margin-top:1.2rem">
			<label for="poa_act_mode">May attorneys act jointly or severally?</label>
			<select id="poa_act_mode" name="poa_act_mode">
			<option value="">Please choose…</option>
			<option value="Jointly">Jointly</option>
			<option value="Severally">Severally</option>
			</select>
			</div>
			</section>
			<section class="step" aria-label="Enduring Guardian" data-active="false">
			<div class="notice" style="margin-bottom:1.5rem">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path><path d="M9 12l2 2 4-4"></path></svg>
			<span>An <b>Enduring Guardian</b> makes decisions about your health, medical care and living arrangements if you can't. This is different from your attorney, who handles money and legal matters.</span>
			</div>
			<fieldset class="fieldset">
			<div class="field-grid">
			<div class="field field--full">
			<label for="eg_name">Enduring guardian's full name</label>
			<input id="eg_name" name="eg_name" type="text" value="#xmlFormat( args.values.eg_name ?: '' )#">
			</div>
			<div class="field field--full">
			<label for="eg_address">Guardian's address</label>
			<input id="eg_address" name="eg_address" type="text" value="#xmlFormat( args.values.eg_address ?: '' )#">
			</div>
			<div class="field">
			<label for="eg_email">Email Address</label>
			<input id="eg_email" name="eg_email" type="email" value="#xmlFormat( args.values.eg_email ?: '' )#">
			</div>
			<div class="field">
			<label for="eg_phone">Phone Number</label>
			<input id="eg_phone" name="eg_phone" type="tel" value="#xmlFormat( args.values.eg_phone ?: '' )#">
			</div>
			<div class="field field--full">
			<label for="eg_directions">Any directions or wishes (optional)</label>
			<textarea id="eg_directions" name="eg_directions" placeholder="e.g. Preferences about medical treatment, or where you'd wish to live.">#encodeForHTML( args.values.eg_directions ?: '' )#</textarea>
			</div>
			</div>
			</fieldset><div class="field field--full" style="margin-top:1.5rem">
			<label>Backup Enduring Guardian(s)</label>
			<div data-repeat="" data-min="0" data-collect="backup_enduring_guardian" data-act-mode-target="eg_act_mode_wrap">
			</div>
			<template data-repeat-template="">
			<div class="person-card">
			<div class="person-card__head"><b>Backup Enduring Guardian 1</b><button type="button" class="btn-remove">Remove</button></div>
			<div class="field-grid">
			<div class="field field--full">
			<label>Full name</label>
			<input type="text" name="bak_eg_name" data-field="eg_name">
			</div>
			<div class="field field--full">
			<label>Address</label>
			<input type="text" name="bak_eg_address" data-field="eg_address">
			</div>
			<div class="field">
			<label>Email Address</label>
			<input type="email" name="bak_eg_email" data-field="eg_email">
			</div>
			<div class="field">
			<label>Phone Number</label>
			<input type="tel" name="bak_eg_phone" data-field="eg_phone">
			</div>
			<div class="field field--full">
			<label>Any directions or wishes (optional)</label>
			<textarea name="bak_eg_directions" data-field="eg_directions" placeholder="e.g. Preferences about medical treatment, or where you'd wish to live."></textarea>
			</div>
			</div>
			</div>
			</template>
			<button type="button" class="btn-add" data-label="Backup Enduring Guardian">+ Add backup enduring guardian</button>
			</div><div class="field field--full" id="eg_act_mode_wrap" data-act-mode="" style="display:none;margin-top:1.2rem">
			<label for="eg_act_mode">May guardians act jointly or severally?</label>
			<select id="eg_act_mode" name="eg_act_mode">
			<option value="">Please choose…</option>
			<option value="Jointly">Jointly</option>
			<option value="Severally">Severally</option>
			</select>
			</div>
			</section>
			<section class="step" aria-label="Disposal of the body" data-active="false">
			<div class="notice" style="margin-bottom:1.5rem">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="10"></circle><path d="M12 16v-4M12 8h.01"></path></svg>
			<span>Tell us how you wish your body to be disposed of, and any special instructions for cremation or burial.</span>
			</div>
			<fieldset class="fieldset">
			<div class="field-grid">
			<div class="field field--full">
			<label for="body_disposal">Do you wish to be cremated or buried?</label>
			<select id="body_disposal" name="body_disposal">
			<option value="">Please choose…</option>
			<option value="Cremated">Cremated</option>
			<option value="Buried">Buried</option>
			</select>
			</div>
			<div class="field field--full">
			<label for="body_instructions">Any special instructions regarding cremation or burial</label>
			<textarea id="body_instructions" name="body_instructions" placeholder="e.g. Preferred cemetery, ashes to be scattered, religious rites.">#encodeForHTML( args.values.body_instructions ?: '' )#</textarea>
			</div>
			</div>
			</fieldset>
			</section>
			<section class="step" aria-label="Digital assets" data-active="false">
			<div class="notice" style="margin-bottom:1.5rem">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="2" y="3" width="20" height="14" rx="2"></rect><path d="M8 21h8M12 17v4"></path></svg>
			<span>Information relating to digital assets you own — online accounts, cryptocurrency, cloud storage, social media and similar.</span>
			</div>
			<fieldset class="fieldset">
			<div class="field-grid">
			<div class="field field--full">
			<span class="label-text" style="display:block;font-weight:600;margin-bottom:.6rem">Do you wish to include clauses in your will relating to digital assets?</span>
			<label style="display:flex;gap:.6rem;align-items:center;margin-bottom:.4rem">
			<input type="radio" name="da_include_clauses" value="Yes"<cfif ( args.values.da_include_clauses ?: "" ) eq "Yes"> checked</cfif>>
			Yes
			</label>
			<label style="display:flex;gap:.6rem;align-items:center">
			<input type="radio" name="da_include_clauses" value="No"<cfif ( args.values.da_include_clauses ?: "" ) eq "No"> checked</cfif>>
			No
			</label>
			</div>
			<div class="field field--full">
			<label for="da_instructions">Any special instructions regarding accessing, managing or deleting digital assets</label>
			<textarea id="da_instructions" name="da_instructions" placeholder="e.g. Passwords held with X, accounts to close, crypto wallets.">#encodeForHTML( args.values.da_instructions ?: '' )#</textarea>
			</div>
			<div class="field field--full">
			<label for="da_notes">Miscellaneous notes</label>
			<textarea id="da_notes" name="da_notes" placeholder="Any other notes for your solicitor.">#encodeForHTML( args.values.da_notes ?: '' )#</textarea>
			</div>
			</div>
			</fieldset>
			</section>
			<section class="step" aria-label="Review and submit" data-active="false">
			<div class="notice" style="margin-bottom:1.5rem">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M20 6L9 17l-5-5"></path></svg>
			<span>Please check your details. When you submit, we prepare your draft documents and notify a solicitor to review them. <b>Nothing is legally binding until you sign in person.</b></span>
			</div>
			<div id="review-body"></div>
			<label style="display:flex;gap:.7rem;align-items:flex-start;margin-top:1.2rem;font-size:var(--step--1);color:var(--ink-soft)">
			<input type="checkbox" name="consent_accepted" value="1" required="" style="margin-top:.3rem"<cfif listFindNoCase( "1,true,yes,on", args.values.consent_accepted ?: "" )> checked</cfif>>
			I understand these are draft instructions, that a solicitor will review them before any document is signed, and I consent to PT Legal contacting me to arrange a signing appointment.
			</label>
			</section>
			<div class="form-actions">
			<button type="button" class="btn btn--ghost" id="wiz-back" style="visibility:hidden">← Back</button>
			<div>
			<cfif len( args.recaptchaSiteKey ?: "" )>
				<div class="g-recaptcha-container" style="margin-bottom:1rem">
					<div class="g-recaptcha" data-sitekey="#xmlFormat( args.recaptchaSiteKey )#"></div>
				</div>
				<script src="https://www.google.com/recaptcha/api.js" async defer></script>
			</cfif>
			<button type="button" class="btn" id="wiz-next" style="display: inline-flex;">Continue →</button>
			<button type="submit" class="btn btn--brass" id="wiz-submit" style="display:none">Submit for solicitor review</button>
			</div>
			</div></div>
	</form>
	</div>
</main>
</cfoutput>
