```markdown
# linux-sysadmin-toolkit

Collection of Bash scripts for Linux server administration.
Developed and used in real-world data center environments running CentOS, Debian, and Ubuntu.

## Structure

| Folder | Content |
|---|---|
| `disk/` | Disk diagnostics and testing (SMART, dd, formatting) |
| `security/` | Hardening, SSL certificates, iptables rules |
| `monitoring/` | Attack detection, connections, top IPs |
| `system/` | Kernel management, automated Git tasks, system info |
| `bash-examples/` | Reference examples: strings, arrays, regex, select |

## Requirements

- Bash 4+
- smartmontools (for `disk/`)
- openssl (for `security/check_certificates_date`)
- iptables (for `security/`)

## Author

Cesar Mathias Arce — [LinkedIn](https://linkedin.com/in/mathiasarce)
```

````markdown
# disk

Scripts for physical disk diagnostics and testing.

## Scripts

### `health_disk.sh`
Complete diagnostic process for all system disks:
- Formatting and partitioning before testing
- Write, read, and latency tests using `dd`
- Critical SMART attribute checks (IDs 5, 187, 188, 196, 197, 198)
- Generates logs in `./logs/` for later review
- Colored output for faster readability

**Usage:**
```bash
chmod +x health_disk.sh
sudo ./health_disk.sh
````

````

```markdown
# security

Security-related scripts: server hardening, SSL certificate monitoring, and firewall management.

## Scripts

### `server_hardening.sh`
Linux server hardening script:
- Audits `lastlog` and active crontabs
- Removes Kinsing malware
- Blocks cron usage for web service users (`www-data`, `apache`, `postgres`)
- Restricts `wget`/`curl` usage via ACLs per user
- UID-based outbound iptables rules

### `check_certificates_date`
Checks SSL certificate expiration dates for Apache and Nginx.
Supports `-q` flag for scripts or cron usage.

**Usage:**
```bash
./check_certificates_date        # Full output
./check_certificates_date -q     # Errors/warnings only
````

**Exit codes:** 0 = OK, 1 = WARNING (expires within 72h), 2 = ERROR (already expired)

### `iptables_template.sh`

Basic iptables rules template. Configure variables at the beginning of the file.

````

```markdown
# monitoring

Monitoring and real-time attack detection scripts.

## Scripts

### `top_connections_cron.sh`
Apache log analysis for automatic attack detection:
- IPs with more than 100 connections in the last minute
- IPs with more than 6000 connections during the current hour
- `wp-login.php` attack detection (per IP and per domain)
- `xmlrpc.php` abuse detection
- GeoIP support (`mmdblookup`) and Cloudflare range detection
- TEST mode for simulation without blocking

Designed to run every minute via cron.
````

```markdown
# system

Operating system management and maintenance scripts.

## Scripts

### `uname.sh`
Displays the active kernel and all installed kernels.
Compatible with Debian, Ubuntu, CentOS 6/7/8, AlmaLinux, Rocky Linux, and Arch Linux.

### `remove_kernels_viejos.sh`
Detects and purges old kernels on Debian/Ubuntu systems.
Always preserves the active kernel and the most recently installed one.
Requests confirmation before purging.

### `git_commit_diario.sh`
Automates daily commits in `/etc/mon`.
Useful for keeping a history of monitoring configuration changes (Mon).
```

```markdown
# bash-examples

Reference scripts with commented Bash examples.

## Scripts

### `ejemplos_en_bash.sh`
Practical Bash string manipulation examples:
- Length, substrings, indexes
- Simple and global replacement (sed-style)
- Uppercase/lowercase conversion
- Name-referenced variables (`${!var}`)
- Interactive menu using `select`
- awk, bc, and paste tricks
```
