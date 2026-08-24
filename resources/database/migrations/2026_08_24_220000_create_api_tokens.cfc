/**
 * Credentials for the REST API.
 *
 * ## Why tokens and not the session
 *
 * The admin authenticates with a session cookie, which is right for a browser
 * and wrong for an API: a cookie is sent automatically, which is what makes
 * CSRF possible, and there is nowhere for a script or another server to put one.
 * A token is presented deliberately on every request, so an API call cannot be
 * triggered by a page a victim happens to visit.
 *
 * ## What is stored
 *
 * **Not the token.** Only a SHA-256 hash of it, exactly as passwords are only
 * ever stored hashed — a database that leaks must not hand over working
 * credentials. The token is shown to its creator once, at creation, and cannot
 * be recovered afterwards.
 *
 * SHA-256 rather than BCrypt here, deliberately, and it is the opposite trade
 * to passwords. A token is 32 bytes of `secureRandom` output, so there is no
 * dictionary to attack and no need for a slow hash; and an API verifies on
 * *every request*, where BCrypt's cost would be a self-inflicted denial of
 * service. Passwords are short, human-chosen and verified once per sign-in,
 * which is why they get the slow hash instead.
 *
 * `prefix` is the first few characters, stored in the clear so the admin can
 * show "which token is this?" in a list without being able to reconstruct one.
 *
 * ## Scope
 *
 * A token belongs to a **site** and to the **user** who created it, and it can
 * never do more than that user may do — permissions are resolved through the
 * same authorization service the admin uses. Revoking the user's access revokes
 * the token's with it.
 */
component {

	function up( schema, qb ){
		queryExecute(
			"
			CREATE TABLE `api_tokens` (
				`id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
				`site_id`      BIGINT UNSIGNED NOT NULL,
				`user_id`      BIGINT UNSIGNED NOT NULL,
				`name`         VARCHAR(100)    NOT NULL,
				-- SHA-256 hex. Unique, so a lookup by hash is an index hit
				-- rather than a scan of every token on the installation.
				`token_hash`   CHAR(64)        NOT NULL,
				`prefix`       VARCHAR(12)     NOT NULL,
				`last_used_at` DATETIME        NULL,
				`expires_at`   DATETIME        NULL,
				`revoked_at`   DATETIME        NULL,
				`created_at`   DATETIME        NOT NULL,
				`updated_at`   DATETIME        NOT NULL,
				PRIMARY KEY (`id`),
				UNIQUE KEY `uq_api_tokens_hash` (`token_hash`),
				KEY `idx_api_tokens_site` (`site_id`, `revoked_at`),
				KEY `idx_api_tokens_user` (`user_id`),
				CONSTRAINT `fk_api_tokens_site`
					FOREIGN KEY (`site_id`) REFERENCES `sites` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE,
				-- A token is the user's authority, so it goes when they do.
				CONSTRAINT `fk_api_tokens_user`
					FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
					ON DELETE CASCADE ON UPDATE CASCADE
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
			",
			{},
			arguments.schema.getDefaultOptions()
		);
	}

	function down( schema, qb ){
		queryExecute( "DROP TABLE IF EXISTS `api_tokens`", {}, arguments.schema.getDefaultOptions() );
	}

}
