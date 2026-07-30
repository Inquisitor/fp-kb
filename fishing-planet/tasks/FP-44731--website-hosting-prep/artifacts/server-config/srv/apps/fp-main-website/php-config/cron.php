<?php
/*
 * Must-use plugin: disable the request-triggered WP-Cron. The in-container loopback to the site URL
 * does not resolve behind the reverse proxy, so it never fires; a host cron runs `wp cron event run`
 * instead. Remove this plugin's mount to fall back to the (broken here) built-in cron.
 */
if (!defined('DISABLE_WP_CRON')) {
    define('DISABLE_WP_CRON', true);
}
