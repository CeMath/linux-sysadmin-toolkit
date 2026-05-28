# linux-sysadmin-toolkit

ColecciÃ³n de scripts Bash para administraciÃ³n de servidores Linux.
Desarrollados y usados en entornos reales de data center con CentOS, Debian y Ubuntu.

## Estructura

| Carpeta | Contenido |
|---|---|
| `disk/` | DiagnÃ³stico y testing de discos (SMART, dd, formateo) |
| `security/` | Hardening, certificados SSL, reglas iptables |
| `monitoring/` | DetecciÃ³n de ataques, conexiones, top de IPs |
| `system/` | GestiÃ³n de kernels, Git automÃ¡tico, info del sistema |
| `bash-examples/` | Ejemplos de referencia: strings, arrays, regex, select |

## Requisitos

- Bash 4+
- smartmontools (para `disk/`)
- openssl (para `security/check_certificates_date`)
- iptables (para `security/`)

## Autor

Cesar Mathias Arce â€” [LinkedIn](https://linkedin.com/in/mathiasarce)
