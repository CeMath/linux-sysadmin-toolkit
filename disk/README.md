# disk

Scripts para diagnÃ³stico y testing de discos fÃ­sicos.

## Scripts

### `health_disk.sh`
DiagnÃ³stico completo de todos los discos del sistema:
- Formateo y particionado previo al testeo
- Test de escritura, lectura y latencia con `dd`
- Chequeo de atributos SMART crÃ­ticos (IDs 5, 187, 188, 196, 197, 198)
- Genera logs en `./logs/` para revisiÃ³n posterior
- Output coloreado para lectura rÃ¡pida

**Uso:**
```bash
chmod +x health_disk.sh
sudo ./health_disk.sh
```
