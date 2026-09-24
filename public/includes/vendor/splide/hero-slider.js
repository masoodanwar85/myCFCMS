/**
 * Mount Splide on any [data-hero-slider] with more than one slide.
 *
 * Type is loop so each image and its overlay HTML move together. A single
 * published slide stays a static panel — there is nothing to advance to.
 */
(function () {
	function mount() {
		if (typeof Splide === "undefined") {
			return;
		}

		document.querySelectorAll("[data-hero-slider]").forEach(function (root) {
			if (root.querySelectorAll(".splide__slide").length < 2) {
				return;
			}

			new Splide(root, {
				type: "loop",
				perPage: 1,
				perMove: 1,
				speed: 800,
				easing: "cubic-bezier(0.25, 1, 0.5, 1)",
				autoplay: true,
				interval: 5000,
				pauseOnHover: true,
				pauseOnFocus: true,
				arrows: true,
				pagination: true,
				drag: true,
				keyboard: true,
				reducedMotion: {
					autoplay: false,
					speed: 0
				}
			}).mount();
		});
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", mount);
	} else {
		mount();
	}
})();
