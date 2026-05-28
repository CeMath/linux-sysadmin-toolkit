# system

Scripts for operating system management and maintenance.

## Scripts

### `uname.sh`
Displays the currently running kernel and all installed kernels.  
Compatible with Debian, Ubuntu, CentOS 6/7/8, AlmaLinux, Rocky Linux, and Arch Linux.

### `remove_kernels_viejos.sh`
Detects and removes old kernels on Debian/Ubuntu systems.  
Always preserves the currently running kernel and the newest installed one.  
Requests confirmation before purging.

### `git_commit_diario.sh`
Automates daily commits in `/etc/mon`.  
Useful for keeping a configuration change history for monitoring tools (Mon).
