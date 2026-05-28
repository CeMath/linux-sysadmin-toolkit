# monitoring

Scripts de monitoreo y detecciÃ³n de ataques en tiempo real.

## Scripts

### `top_connections_cron.sh`
AnÃ¡lisis de logs Apache para detecciÃ³n automÃ¡tica de ataques:
- IPs con mÃ¡s de 100 conexiones en el Ãºltimo minuto
- IPs con mÃ¡s de 6000 conexiones en la hora actual
- DetecciÃ³n de ataques a wp-login.php (por IP y por dominio)
- DetecciÃ³n de abuso de xmlrpc.php
- Soporte GeoIP (mmdblookup) y detecciÃ³n de rangos Cloudflare
- Modo TEST para simular sin bloquear

DiseÃ±ado para ejecutarse vÃ­a cron cada minuto.
