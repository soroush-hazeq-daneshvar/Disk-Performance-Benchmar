#!/bin/bash
# Advanced Disk Performance Test Installer
# Requires root privileges

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

echo "Installing benchmark tools and dependencies..."
apt-get update -qq
apt-get install -y -qq \
    fio \
    ioping \
    hdparm \
    sysstat \
    bc \
    jq \
    lsscsi \
    smartmontools \
    pv \
    html2text

echo "Installing latest FIO from upstream..."
add-apt-repository -y ppa:patrickdk/fio-latest >/dev/null 2>&1
apt-get update -qq
apt-get install -y -qq fio >/dev/null 2>&1

echo "Verifying installations..."
for tool in fio ioping hdparm sar bc jq lsscsi smartctl pv; do
    if ! command -v $tool &>/dev/null; then
        echo "ERROR: Installation failed for $tool"
        exit 1
    fi
done

echo "All components installed successfully"
