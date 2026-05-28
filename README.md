# linux-sysadmin-toolkit

Collection of Bash scripts for Linux server administration.  
Developed and used in real data center environments with CentOS, Debian, and Ubuntu.

## Structure

| Folder              | Content |
|---------------------|---------|
| `disk/`             | Disk diagnosis and testing (SMART, dd, formatting) |
| `security/`         | Hardening, SSL certificates, iptables rules |
| `monitoring/`       | Attack detection, connections, top IPs |
| `system/`           | Kernel management, automatic Git, system information |
| `bash-examples/`    | Reference examples: strings, arrays, regex, select |

## Requirements

- Bash 4+
- smartmontools (for `disk/`)
- openssl (for `security/check_certificates_date`)
- iptables (for `security/`)

## Author

Cesar Mathias Arce — [LinkedIn](https://linkedin.com/in/mathiasarce)
