# disk

Scripts for diagnosis and testing of physical disks.

## Scripts

### `health_disk.sh`
Complete diagnosis of all disks in the system:

- Formatting and partitioning before testing
- Write, read, and latency tests using `dd`
- Check of critical SMART attributes (IDs 5, 187, 188, 196, 197, 198)
- Generates logs in `./logs/` for later review
- Color-coded output for quick reading

**Usage:**
```bash
chmod +x health_disk.sh
sudo ./health_disk.sh
