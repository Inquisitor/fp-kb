<?php
/*
 * Must-use plugin: core update policy. Keep minor/security auto-updates on (they run via WP-Cron,
 * which the host cron drives). Remove this plugin's mount to turn core auto-updates off.
 */
if (!defined('WP_AUTO_UPDATE_CORE')) {
    define('WP_AUTO_UPDATE_CORE', 'minor');
}
