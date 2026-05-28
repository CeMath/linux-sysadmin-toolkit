# monitoring

Scripts for real-time monitoring and attack detection.

## Scripts

### `top_connections_cron.sh`
Apache log analysis for automatic attack detection:

- IPs with more than 100 connections in the last minute
- IPs with more than 6000 connections in the current hour
- Detection of attacks on `wp-login.php` (by IP and by domain)
- Detection of `xmlrpc.php` abuse
- GeoIP support (`mmdblookup`) and Cloudflare range detection
- TEST mode to simulate without blocking

Designed to run via cron every minute.
