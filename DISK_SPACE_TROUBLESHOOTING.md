# Disk Space Troubleshooting Guide

## Common "No space left on device" Error

The error you encountered is common when installing PyTorch and ML dependencies. Here's how to fix it:

## Quick Fixes

### 1. Check Available Space
```bash
df -h /
du -sh /tmp /var/cache /var/log
```

### 2. Clean System Before Running Script
```bash
# Clean package cache
sudo apt-get clean
sudo apt-get autoremove -y

# Clean pip cache
pip3 cache purge

# Clean temporary files
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clean log files (be careful!)
sudo journalctl --vacuum-time=7d
```

### 3. Free Up More Space
```bash
# Remove old kernels (keep current + 1 backup)
sudo apt autoremove --purge

# Clean snap packages
sudo snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do sudo snap remove "$snapname" --revision="$revision"; done

# Find large files
find / -type f -size +100M 2>/dev/null | head -20
```

## Script Optimizations Included

The updated script now includes:

### Automatic Disk Space Checking
- ✅ Checks available disk space before starting
- ✅ Warns if less than 15GB available
- ✅ Errors if less than 10GB available
- ✅ Uses minimal installation for low space systems

### Cleanup Functions
- ✅ Automatic cleanup before and after execution
- ✅ Pip cache purging after installations
- ✅ Temporary file removal
- ✅ Package cache cleanup

### Optimized Installation
- ✅ `--no-cache-dir` flag to prevent caching
- ✅ Batched installations to manage memory
- ✅ Minimal package set for low-space systems
- ✅ CPU-only PyTorch for smaller footprint

## Disk Space Requirements

| Installation Type | Minimum Space | Recommended |
|------------------|---------------|-------------|
| **Minimal**      | 8GB          | 12GB        |
| **Standard**     | 12GB         | 18GB        |
| **Full**         | 15GB         | 25GB        |

## Before Running on Server

1. **Check disk space:**
   ```bash
   df -h /
   ```

2. **Clean the system:**
   ```bash
   sudo apt-get clean
   sudo apt-get autoremove -y
   ```

3. **If space is still low, consider:**
   - Moving to a larger disk/partition
   - Using external storage for the virtual environment
   - Running the minimal installation mode

## Minimal vs Full Installation

### Minimal Installation (< 15GB free space)
- ✅ Core CTGAN functionality
- ✅ Essential data generation
- ❌ Limited visualization features
- ❌ No Jupyter notebook support

### Full Installation (15GB+ free space)
- ✅ Complete feature set
- ✅ All visualization tools
- ✅ Jupyter notebook support
- ✅ Full SDK functionality

## Server-Specific Recommendations

For your VPS at `194.238.17.65`:

1. **Check available space:**
   ```bash
   ssh user@194.238.17.65 'df -h /'
   ```

2. **Pre-clean the server:**
   ```bash
   ssh user@194.238.17.65 'sudo apt-get clean && sudo apt-get autoremove -y'
   ```

3. **Monitor during installation:**
   ```bash
   ssh user@194.238.17.65 'watch df -h /'
   ```

## Recovery from Failed Installation

If the installation fails due to disk space:

1. **Clean up the failed environment:**
   ```bash
   rm -rf ~/laika-data-generator/ctgan-env
   pip3 cache purge
   ```

2. **Free up more space using the methods above**

3. **Re-run the script** - it will automatically detect the available space and choose the appropriate installation method.

The updated script is now much more resilient to disk space issues and will provide better error messages and automatic recovery options. 