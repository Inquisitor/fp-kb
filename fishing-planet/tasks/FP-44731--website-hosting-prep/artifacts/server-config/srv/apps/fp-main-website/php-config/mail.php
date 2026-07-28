<?php
/*
 * Must-use plugin: route all WordPress mail through SendGrid (WP Mail SMTP).
 * Loaded before regular plugins, so the constants are set before WP Mail SMTP reads them.
 * The API key is read from a mounted secret - never stored in the database or the repo.
 */
if (!defined('WPMS_ON')) {
    $key = @file_get_contents('/run/secrets/sendgrid_key');
    define('WPMS_ON', true);
    define('WPMS_MAILER', 'sendgrid');
    define('WPMS_SENDGRID_API_KEY', $key !== false ? trim($key) : '');
    define('WPMS_MAIL_FROM', 'noreply@fishingplanet.com');
    define('WPMS_MAIL_FROM_NAME', 'Fishing Planet');
    define('WPMS_MAIL_FROM_FORCE', true);
}
