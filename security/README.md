# security

Scripts de seguridad: hardening de servidores, monitoreo de certificados SSL y firewall.

## Scripts

### `server_hardening.sh`
Hardening de servidor Linux:
- AuditorÃ­a de lastlog y crontabs activos
- Limpieza de malware kinsing
- Bloqueo de cron para usuarios de servicios web (www-data, apache, postgres)
- RestricciÃ³n de wget/curl via ACL por usuario
- Reglas iptables de salida por UID

### `check_certificates_date`
Verifica fechas de vencimiento de certificados SSL en Apache y Nginx.
Soporta flag `-q` para uso en scripts o cron.

**Uso:**
```bash
./check_certificates_date        # Output completo
./check_certificates_date -q     # Solo errores/warnings
```

**Exit codes:** 0 = OK, 1 = WARNING (vence en 72hs), 2 = ERROR (ya vencido)

### `iptables_template.sh`
Template de reglas iptables bÃ¡sico. Configurar las variables al inicio del archivo.
