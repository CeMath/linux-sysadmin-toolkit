# security

Security scripts: server hardening, SSL certificate monitoring, and firewall management.

## Scripts

### `server_hardening.sh`
Linux server hardening:

- Audit of lastlog and active crontabs
- Kinsing malware cleanup
- Blocking cron for web service users (`www-data`, `apache`, `postgres`)
- Restriction of `wget`/`curl` via ACL per user
- Outbound iptables rules by UID

### `check_certificates_date`
Checks expiration dates of SSL certificates in Apache and Nginx.  
Supports `-q` flag for use in scripts or cron.

**Usage:**
```bash
./check_certificates_date        # Full output
./check_certificates_date -q     # Only errors/warnings
