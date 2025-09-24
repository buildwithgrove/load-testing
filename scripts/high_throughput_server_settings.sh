#!/bin/bash

# High Throughput Server Settings Script
# Applies kernel parameters and file limits for 50K+ RPS capability
# Usage: sudo ./high_throughput_server_settings.sh

set -e

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

echo "Applying high throughput server settings..."

# Backup original sysctl.conf
cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d-%H%M%S) 2>/dev/null || true

# Apply kernel parameters
cat >> /etc/sysctl.conf << 'EOF'

# High Throughput Server Settings
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535

# Connection tracking
net.netfilter.nf_conntrack_max = 2097152
net.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_buckets = 524288
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120

# TCP optimization
net.ipv4.tcp_max_orphans = 65536
net.ipv4.tcp_max_tw_buckets = 400000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# Network buffers
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

# Apply file descriptor limits
cat >> /etc/security/limits.conf << 'EOF'

# High Throughput File Limits
* soft nofile 100000
* hard nofile 100000
root soft nofile 100000
root hard nofile 100000
EOF

# Also add to /etc/pam.d/common-session if it exists (for Ubuntu/Debian)
if [ -f /etc/pam.d/common-session ]; then
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
fi

# Also add to /etc/pam.d/login if it exists
if [ -f /etc/pam.d/login ]; then
    if ! grep -q "pam_limits.so" /etc/pam.d/login; then
        echo "session required pam_limits.so" >> /etc/pam.d/login
    fi
fi

# Apply kernel settings immediately
sysctl -p

# Force reload systemd limits (for file descriptors)
systemctl daemon-reload 2>/dev/null || true

# Apply connection tracking module settings if available
if [ -f /proc/sys/net/netfilter/nf_conntrack_max ]; then
    echo 2097152 > /proc/sys/net/netfilter/nf_conntrack_max
    echo 524288 > /proc/sys/net/netfilter/nf_conntrack_buckets 2>/dev/null || true
fi

# Set systemd service limits (affects services started by systemd)
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=100000
EOF

# Reload systemd configuration
systemctl daemon-reexec 2>/dev/null || true

# Set current session file descriptor limit (temporary for this session only)
ulimit -n 100000

echo "All settings applied and activated!"
echo ""
echo "Verified current values:"
echo "Connection tracking max: $(cat /proc/sys/net/nf_conntrack_max 2>/dev/null || echo 'N/A')"
echo "Port range: $(cat /proc/sys/net/ipv4/ip_local_port_range)"
echo "Socket backlog: $(cat /proc/sys/net/core/somaxconn)"
echo "Current session file descriptor limit: $(ulimit -n)"
echo ""

# Make the important notice very visible
echo "################################################################################"
echo "#                                                                              #"
echo "#                              ⚠️  IMPORTANT  ⚠️                                 #"
echo "#                                                                              #"
echo "#  File descriptor limits require a NEW LOGIN SESSION to take effect!          #"
echo "#                                                                              #"
echo "#  Required next steps:                                                        #"
echo "#  1. Log out and log back in, OR                                              #"
echo "#  2. Start a new shell with: sudo -i -u $SUDO_USER                            #"
echo "#  3. Then verify with: ulimit -n                                              #"
echo "#                                                                              #"
echo "#  For systemd services: restart them after running this script                #"
echo "#                                                                              #"
echo "################################################################################"
