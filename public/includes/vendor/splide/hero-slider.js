/**
 * Mount Splide on every [data-hero-slider] on the page.
 *
 * The homepage template and the [hero-slider] shortcode both emit that
 * marker. One published slide still mounts (no carousel chrome); two or
 * more loop and autoplay. `window.Splide` is retried in case the library
 * script finishes after this file.
 */
(function (global) {
	function slideCount(root) {
		return root.querySelectorAll(".splide__slide:not(.splide__slide--clone)").length;
	}

	function mountAll() {
		var Splide = global.Splide;

		if (typeof Splide !== "function") {
			return false;
		}

		global.document.querySelectorAll("[data-hero-slider]").forEach(function (root) {
			if (root.classList.contains("is-initialized") || root.splide) {
				return;
			}

			var count = slideCount(root);

			if (!count) {
				return;
			}

			var many = count > 1;

			new Splide(root, {
				type: many ? "loop" : "slide",
				perPage: 1,
				perMove: 1,
				speed: 800,
				easing: "cubic-bezier(0.25, 1, 0.5, 1)",
				autoplay: many,
				interval: 5000,
				pauseOnHover: true,
				pauseOnFocus: true,
				arrows: many,
				pagination: many,
				drag: many,
				keyboard: true,
				reducedMotion: {
					autoplay: false,
					speed: 0
				}
			}).mount();
		});

		return true;
	}

	function start() {
		if (mountAll()) {
			return;
		}

		var tries = 0;
		var timer = global.setInterval(function () {
			tries += 1;
			if (mountAll() || tries > 40) {
				global.clearInterval(timer);
			}
		}, 50);
	}

	global.cmsMountHeroSliders = mountAll;

	if (global.document.readyState === "loading") {
		global.document.addEventListener("DOMContentLoaded", start);
	} else {
		start();
	}

	global.addEventListener("load", mountAll);
})(window);
