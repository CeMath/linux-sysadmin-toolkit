# system

Scripts de gestiÃ³n y mantenimiento del sistema operativo.

## Scripts

### `uname.sh`
Muestra el kernel en uso y todos los kernels instalados.
Compatible con Debian, Ubuntu, CentOS 6/7/8, AlmaLinux, Rocky Linux y Arch Linux.

### `remove_kernels_viejos.sh`
Detecta y purga kernels viejos en sistemas Debian/Ubuntu.
Siempre preserva el kernel activo y el mÃ¡s reciente instalado.
Pide confirmaciÃ³n antes de purgar.

### `git_commit_diario.sh`
Automatiza commits diarios en `/etc/mon`.
Ãštil para mantener historial de cambios de configuraciÃ³n de monitoreo (Mon).
