# Dynamic MOTD System v2.0

A comprehensive, modular system for displaying dynamic login messages on Raspberry Pi (and other Linux systems) with parallel execution and atomic script isolation.

**Version 2.0 Changes:**
- ✅ Simplified: No more PAM complexity
- ✅ User-space: Runs from `~/Projects/dynamic-motd`
- ✅ Bashrc integration: Displays on interactive shell login
- ✅ No sudo required for viewing (sudo only needed for scripts that check system status)

## Features

- **Parallel Execution**: All scripts run simultaneously for minimal login latency
- **Atomic Scripts**: Each section fails independently without affecting others
- **Timeout Protection**: 5-second timeout per script prevents hangs
- **Failure Reporting**: Explicitly shows timed-out and failed scripts with paths for manual inspection
- **Execution Timing**: Shows how long each section took (for performance monitoring)
- **Rich Output**: Color-coded, emoji-enhanced, elegant formatting
- **RPi-Optimized**: CPU temperature (Fahrenheit), throttling status, power monitoring
- **Version Controlled**: Full git history with GitHub backup

## System Sections

### 1. System Health (10-20)
- **Failed systemd services** - Lists any failed system services
- **Cron job failures** - Recent failures for `pi` and `root` users

### 2. Hardware Status (40-50)
- **Disk usage** - Per-partition breakdown with >80% highlighting
- **Memory usage** - RAM and swap utilization

### 3. Development Tools (70-80)
- **Docker status** - Container count and run state
- **Git repos** - Detects uncommitted changes and unpushed commits

### 4. Maintenance (100-130)
- **Package updates** - Available updates with security highlighting
- **Certificate expiry** - Warns about certs expiring within 30 days
- **System uptime** - Uptime and last reboot time

### 5. RPi-Specific (150-160)
- **CPU temperature** - Displayed in Fahrenheit with color coding
- **Power status** - Detects under-voltage and throttling issues

## Architecture

### Main Orchestrator (`00-main`)
- Spawns all scripts in parallel as background jobs
- Collects output in numeric order
- Measures execution time for each script
- Enforces 5-second timeout per script
- Reports timeouts and failures with script paths for manual debugging
- Cleans up temporary files
- Shows timestamp of when MOTD was generated

**Failure Modes:**
- **Timeout (exit 124)**: Shows `✗ Timed out (>5s): ~/Projects/dynamic-motd/NN-script`
- **Script Error (non-zero exit)**: Shows `✗ Failed (exit N): ~/Projects/dynamic-motd/NN-script` with any error output
- **Not Run**: Shows `⚠ Script not run: ~/Projects/dynamic-motd/NN-script`

This ensures no silent failures - you'll always know when a script doesn't complete successfully.

### Script Pattern
Each script follows the numbering scheme: `NN-description`
- Scripts run in numeric order (00-99)
- Dividers between sections (30, 60, 90, etc.)
- Each script is independent and fails gracefully

## Installation

### 1. Clone the Repository
```bash
cd ~/Projects
git clone https://github.com/MichaelPhilippone/dynamic-motd.git
```

### 2. Add to Bashrc
Add the following to your `~/.bashrc`:

```bash
# Display dynamic MOTD on interactive login (v2.0)
if [[ $- == *i* ]] && [[ -z "$MOTD_SHOWN" ]]; then
    export MOTD_SHOWN=1
    ~/Projects/dynamic-motd/00-main 2>/dev/null
fi
```

### 3. Test
```bash
# Source your bashrc to test
source ~/.bashrc

# Or manually run
~/Projects/dynamic-motd/00-main
```

## Usage

### Manual Execution
```bash
~/Projects/dynamic-motd/00-main
```

### Debug Timed-Out or Failed Scripts
If you see a timeout or failure message, run the script manually:
```bash
~/Projects/dynamic-motd/NN-script-name
```

### Disable/Enable Sections
Prepend underscore to disable any section:
```bash
mv ~/Projects/dynamic-motd/20-cron-failures ~/Projects/dynamic-motd/_20-cron-failures

# Re-enable it
mv ~/Projects/dynamic-motd/_20-cron-failures ~/Projects/dynamic-motd/20-cron-failures
```

### Timing Monitoring
Scripts that take >= 100ms show their timing:
```
📊 Disk Usage:
  /      13G /  56G (25%)
  (131ms)
```

Use this to identify slow sections.

## Color Codes

- 🔴 Red: Critical issues (under-voltage, failed services, script failures)
- 🟡 Yellow: Warnings (uncommitted changes, expiring certs, timeouts)
- 🟢 Green: Normal status
- ⚫ Gray: Timing information, timestamp

## Development

### Editing Scripts
```bash
# Edit a script
nano ~/Projects/dynamic-motd/40-disk-usage

# Test it individually
bash ~/Projects/dynamic-motd/40-disk-usage

# Test full MOTD
~/Projects/dynamic-motd/00-main
```

### Committing Changes
```bash
cd ~/Projects/dynamic-motd
git add .
git commit -m "Update disk usage thresholds

Co-Authored-By: Warp <agent@warp.dev>"
git push
```

## Environment

- **Location**: `~/Projects/dynamic-motd` (user-space, no system directories)
- **Privileges**: Most scripts run as user; some may need sudo for system info
- **Temperature**: Requires `/sys/class/thermal/thermal_zone0/temp` for CPU temp
- **Docker**: Requires docker group membership for container status
- **Git**: Checks common directories for repos (`/home/pi`, `/home/pi/Projects`, `/home/pi/Scripts`, `/opt`)

## Customization

### Change Timeout
Edit `TIMEOUT` variable in `~/Projects/dynamic-motd/00-main`:
```bash
TIMEOUT=10  # Increase to 10 seconds
```

### Add New Section
1. Create script with appropriate number: `nano ~/Projects/dynamic-motd/85-new-section`
2. Make it executable: `chmod +x ~/Projects/dynamic-motd/85-new-section`
3. Use color codes: `\033[1m` (bold), `\033[33m` (yellow), `\033[0m` (reset)
4. Test it: `bash ~/Projects/dynamic-motd/85-new-section`

## Repository Structure

```
~/Projects/dynamic-motd/
├── 00-main                 # Main orchestrator
├── 10-systemd-failed       # Failed services check
├── 20-cron-failures        # Cron job failures
├── 30-divider-1           # Visual separator
├── 40-disk-usage          # Disk space monitoring
├── 50-memory-usage        # RAM/swap usage
├── 60-divider-2           # Visual separator
├── 70-docker-status       # Docker containers
├── 80-git-repos           # Git repository status
├── 90-divider-3           # Visual separator
├── 100-package-updates    # Available updates
├── 110-divider-4          # Visual separator
├── 120-cert-expiry        # SSL certificate expiry
├── 130-uptime             # System uptime
├── 140-divider-5          # Visual separator
├── 150-rpi-temperature    # CPU temperature
├── 160-rpi-power          # Power/throttling status
└── README.md              # This file
```

## Performance

Typical execution times:
- Disk usage: ~130ms
- Memory usage: ~130ms
- Docker status: ~700ms
- Git repos: ~500ms
- Package updates: ~2-3s

**Note**: Scripts exceeding 5s timeout will be marked as timed out with full path shown for manual inspection.

## Migration from v1.0 (PAM-based)

If you're upgrading from v1.0:

1. Remove PAM integration:
```bash
# Disable custom PAM exec lines
sudo sed -i 's/^session optional pam_exec.so/# session optional pam_exec.so  # Disabled v2.0/' /etc/pam.d/sshd
sudo sed -i 's/^session optional pam_exec.so/# session optional pam_exec.so  # Disabled v2.0/' /etc/pam.d/login
```

2. The old `/etc/update-motd.d` directory can be kept as a backup or removed

3. Follow the v2.0 installation steps above

## Why v2.0?

Version 1.0 used PAM (Pluggable Authentication Modules) integration which was complex and had issues:
- Multiple PAM modules competing (system default vs custom)
- Timing/race conditions during login
- Difficult to debug
- Required root privileges and system file modifications

Version 2.0 is simpler:
- Runs in user-space from `~/.bashrc`
- No system configuration changes needed
- Easy to debug (just check your bashrc)
- Works consistently every time

## License & Attribution

Developed with assistance from Warp AI Agent.

Temperature displayed in Fahrenheit for Los Angeles timezone preference.

All outputs designed for atomic operation - one script failure doesn't affect others.
