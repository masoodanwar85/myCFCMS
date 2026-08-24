/**
 * Turns a title into a URL segment.
 *
 * There were five copies of this, one per service, and every one of them threw
 * away characters outside a-z0-9 rather than transliterating them. A page
 * called "Café Münster" became `caf-nster` — a URL that says nothing about the
 * page and cannot be guessed. For a CMS that stores a `locale` per site and
 * expects non-English clients, silently mangling their titles is a defect, not
 * a limitation.
 *
 * Transliteration is deliberately a fixed table rather than a locale-aware
 * library: the mapping for Latin scripts is stable and small, and getting
 * "München" to `muenchen` matters far more than perfect coverage of every
 * writing system. Scripts with no Latin equivalent still fall through to being
 * dropped — see the note in the docs.
 */
component singleton {

	/**
	 * Ordered because some entries are two characters: German sharp s becomes
	 * "ss", and the umlauts follow the convention German readers expect.
	 */
	variables.TRANSLITERATIONS = [
		{ from : "ä", to : "ae" }, { from : "ö", to : "oe" }, { from : "ü", to : "ue" },
		{ from : "ß", to : "ss" }, { from : "æ", to : "ae" }, { from : "œ", to : "oe" },
		{ from : "å", to : "a"  }, { from : "ø", to : "o"  }, { from : "đ", to : "d"  },
		{ from : "þ", to : "th" }, { from : "ð", to : "d"  }, { from : "ł", to : "l"  },
		{ from : "à", to : "a"  }, { from : "á", to : "a"  }, { from : "â", to : "a"  },
		{ from : "ã", to : "a"  }, { from : "ā", to : "a"  }, { from : "ă", to : "a"  },
		{ from : "è", to : "e"  }, { from : "é", to : "e"  }, { from : "ê", to : "e"  },
		{ from : "ë", to : "e"  }, { from : "ē", to : "e"  }, { from : "ę", to : "e"  },
		{ from : "ì", to : "i"  }, { from : "í", to : "i"  }, { from : "î", to : "i"  },
		{ from : "ï", to : "i"  }, { from : "ī", to : "i"  },
		{ from : "ò", to : "o"  }, { from : "ó", to : "o"  }, { from : "ô", to : "o"  },
		{ from : "õ", to : "o"  }, { from : "ō", to : "o"  },
		{ from : "ù", to : "u"  }, { from : "ú", to : "u"  }, { from : "û", to : "u"  },
		{ from : "ū", to : "u"  }, { from : "ů", to : "u"  },
		{ from : "ç", to : "c"  }, { from : "ć", to : "c"  }, { from : "č", to : "c"  },
		{ from : "ñ", to : "n"  }, { from : "ń", to : "n"  },
		{ from : "š", to : "s"  }, { from : "ś", to : "s"  },
		{ from : "ž", to : "z"  }, { from : "ź", to : "z"  }, { from : "ż", to : "z"  },
		{ from : "ý", to : "y"  }, { from : "ÿ", to : "y"  },
		{ from : "ř", to : "r"  }, { from : "ť", to : "t"  }, { from : "ď", to : "d"  },
		{ from : "ğ", to : "g"  }, { from : "ı", to : "i"  }, { from : "ş", to : "s"  },
		{ from : "&", to : " and " }
	];

	/**
	 * @value A human-readable title.
	 *
	 * @return A lower-case, hyphen-separated slug, or an empty string when
	 *         nothing usable survives.
	 */
	string function slugify( string value = "" ){
		var slug = lCase( trim( arguments.value ?: "" ) );

		if ( !len( slug ) ) {
			return "";
		}

		for ( var mapping in variables.TRANSLITERATIONS ) {
			if ( find( mapping.from, slug ) ) {
				slug = replace( slug, mapping.from, mapping.to, "all" );
			}
		}

		slug = reReplace( slug, "[^a-z0-9]+", "-", "all" );
		slug = reReplace( slug, "^-+|-+$", "", "all" );

		return slug;
	}

}
