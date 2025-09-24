# High Throughput Server Quick Setup

**Goal**: Configure any Linux server for 50K+ RPS in under 30 seconds.

## Setup Steps

1. **Download and run the optimization script**:
   ```bash
   curl -O https://raw.githubusercontent.com/buildwithgrove/load-testing/server-tuning-script/scripts/high_throughput_server_settings.sh
   chmod +x ./high_throughput_server_settings.sh
   sudo ./high_throughput_server_settings.sh
   ```

2. ** Start a new shell **:
   ```bash
   bash
   ```

3. **Verify it worked**:
   ```bash
   ulimit -n    # Should show: 100000
   ```

## Performance Improvement

- **Before**: ~1K-5K RPS, connection errors at high load
- **After**: 50K+ RPS, handles 10K+ concurrent connections
- **Improvement**: 10x+ capacity increase
- **Active**: Immediately - no reboot required

## What Gets Optimized

- Connection tracking: 65K → 2M max connections
- File descriptors: 1K → 100K per process  
- Port range: Maximized for client connections
- TCP timeouts: Faster connection recycling

---
**Total time**: ~30 seconds | **Performance gain**: 10x+ RPS capability
