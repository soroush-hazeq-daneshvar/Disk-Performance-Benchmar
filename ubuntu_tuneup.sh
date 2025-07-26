#!/bin/bash
# Ubuntu Server Performance Tuning Script (Physical Disk Detection Fix)
# Covers Disk I/O, CPU, and Memory optimizations
# Requires root privileges

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use sudo!" >&2
    exit 1
fi

# Function to detect physical disks
detect_physical_disks() {
    # Get all physical disks using lsblk
    local disks=()
    while IFS= read -r line; do
        disks+=("/dev/$line")
    done < <(lsblk -d -n -o NAME -e 7,11 2>/dev/null)
    
    # Fallback to /sys/block if lsblk fails
    if [[ ${#disks[@]} -eq 0 ]]; then
        while IFS= read -r -d '' disk; do
            disk_name=$(basename "$disk")
            [[ "$disk_name" =~ loop|ram|fd ]] && continue
            disks+=("/dev/$disk_name")
        done < <(find /sys/block -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
    fi
    
    # Return unique disks
    printf '%s\n' "${disks[@]}" | sort -u
}

# Detect physical disks
PHYSICAL_DISKS=($(detect_physical_disks))
if [[ ${#PHYSICAL_DISKS[@]} -eq 0 ]]; then
    echo "WARNING: Could not detect physical disks, using all available disks"
    PHYSICAL_DISKS=($(ls /sys/block | grep -vE 'loop|ram|fd' | awk '{print "/dev/"$1}'))
fi

echo "Detected physical disks:"
printf '  - %s\n' "${PHYSICAL_DISKS[@]}"

# Check if disk is SSD
is_ssd() {
    local disk_name=$(basename "$1")
    if [[ -e "/sys/block/$disk_name/queue/rotational" ]]; then
        [[ $(cat "/sys/block/$disk_name/queue/rotational" 2>/dev/null) -eq 0 ]]
        return
    fi
    return 1
}

# Backup original files
backup_file() {
    if [ ! -f "$1.original" ]; then
        cp "$1" "$1.original"
        echo "Backup created: $1.original"
    fi
}

# 1. DISK I/O OPTIMIZATIONS
echo -e "\n\e[1;34m=== DISK I/O TUNING ===\e[0m"

# Apply settings to each physical disk
for disk in "${PHYSICAL_DISKS[@]}"; do
    disk_name=$(basename "$disk")
    
    # Skip if device doesn't exist
    if [[ ! -b "$disk" ]]; then
        echo "Skipping $disk - not a block device"
        continue
    fi
    
    # I/O Scheduler
    if [[ -e "/sys/block/$disk_name/queue/scheduler" ]]; then
        if is_ssd "$disk"; then
            echo "SSD detected ($disk) - using kyber scheduler"
            echo "kyber" > "/sys/block/$disk_name/queue/scheduler"
        else
            echo "HDD detected ($disk) - using mq-deadline scheduler"
            echo "mq-deadline" > "/sys/block/$disk_name/queue/scheduler"
        fi
    else
        echo "WARNING: Scheduler interface not found for $disk"
    fi
done

# Filesystem mount options
backup_file /etc/fstab
if grep -q ' / ' /etc/fstab; then
    if grep -q ' / .*defaults' /etc/fstab; then
        sed -i 's|\( / .*defaults\)|\1,noatime,nodiratime|' /etc/fstab
    else
        sed -i 's|\( / .*\)|\1,noatime,nodiratime|' /etc/fstab
    fi
else
    echo "WARNING: Could not find root filesystem in /etc/fstab"
fi

# Virtual memory settings
backup_file /etc/sysctl.conf
cat >> /etc/sysctl.conf << EOF

# Custom Disk Performance Settings
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF

# 2. CPU OPTIMIZATIONS
echo -e "\n\e[1;34m=== CPU TUNING ===\e[0m"

# Enable performance governor
if which cpupower &>/dev/null; then
    if cpupower frequency-set -g performance &>/dev/null; then
        echo "CPU governor set to performance"
    else
        echo "WARNING: Failed to set CPU governor (virtual machine?)"
    fi
else
    echo "cpupower not available, skipping CPU governor setting"
fi

# CPU isolation (adjust core count based on your system)
total_cores=$(nproc)
if [[ $total_cores -gt 8 ]]; then
    reserved_cores=$((total_cores/4))
    systemctl set-property --runtime -- user.slice AllowedCPUs=$reserved_cores-$((total_cores-1))
    systemctl set-property --runtime -- system.slice AllowedCPUs=$reserved_cores-$((total_cores-1))
    echo "CPU isolation enabled (cores $reserved_cores-$((total_cores-1)) for system processes)"
fi

# IRQ balance tuning
if [ -f /etc/default/irqbalance ]; then
    backup_file /etc/default/irqbalance
    sed -i 's/^IRQBALANCE_ONESHOT=.*/IRQBALANCE_ONESHOT=1/' /etc/default/irqbalance
    if systemctl is-enabled irqbalance &>/dev/null; then
        systemctl restart irqbalance
    fi
else
    echo "irqbalance not installed, skipping configuration"
fi

# 3. MEMORY OPTIMIZATIONS
echo -e "\n\e[1;34m=== MEMORY TUNING ===\e[0m"

# Transparent Huge Pages
if [ -e /sys/kernel/mm/transparent_hugepage/enabled ]; then
    echo "madvise" > /sys/kernel/mm/transparent_hugepage/enabled
    echo "madvise" > /sys/kernel/mm/transparent_hugepage/defrag
fi

# Kernel memory management
cat >> /etc/sysctl.conf << EOF

# Memory Management
kernel.numa_balancing = 0
vm.zone_reclaim_mode = 0
vm.max_map_count = 262144
EOF

# 4. NETWORK TUNING
cat >> /etc/sysctl.conf << EOF

# Network Performance
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 12582912 16777216
net.ipv4.tcp_wmem = 4096 12582912 16777216
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 30000
net.ipv4.tcp_max_syn_backlog = 30000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_fack = 1
EOF

# 5. SECURITY HARDENING
cat >> /etc/sysctl.conf << EOF

# Security/Performance Balance
kernel.kptr_restrict = 1
kernel.yama.ptrace_scope = 1
kernel.perf_event_paranoid = 2
EOF

# 6. APPLY CHANGES
echo -e "\n\e[1;34m=== APPLYING CHANGES ===\e[0m"
sysctl -p
systemctl daemon-reload
mount -o remount /

echo -e "\n\e[1;32mTUNING COMPLETE!\e[0m"
echo "Changes applied:"
echo "  - Disk scheduler optimized for all physical disks"
echo "  - Filesystem mount options updated"
echo "  - Virtual memory settings tuned"
echo "  - CPU governor set to performance"
echo "  - Memory management optimized"
echo "  - Network stack tuned"
echo "  - Security settings balanced with performance"
echo ""
echo "Some changes require reboot to take full effect:"
echo -e "  \e[1msudo reboot\e[0m"
echo ""
echo "Verify settings with:"
echo "  - Disk scheduler: cat /sys/block/<disk>/queue/scheduler (for each physical disk)"
echo "  - CPU governor: cpupower frequency-info"
echo "  - Memory settings: cat /proc/sys/vm/swappiness"