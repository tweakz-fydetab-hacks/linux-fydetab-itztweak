#!/bin/bash
# Kernel build script with crash diagnostics
# Usage: ./build.sh [clean]
#   clean - removes src/pkg and starts fresh

set -o pipefail

LOGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BUILDLOG="$LOGDIR/build-$TIMESTAMP.log"
SYSLOG="$LOGDIR/system-$TIMESTAMP.log"

mkdir -p "$LOGDIR"

# Clean if requested
if [[ "$1" == "clean" ]]; then
    echo "Cleaning previous build..."
    rm -rf src pkg *.pkg.tar.zst
fi

# Capture system state before build
{
    echo "=== BUILD STARTED: $(date) ==="
    echo "=== KERNEL: $(uname -r) ==="
    echo "=== MEMORY ==="
    free -h
    echo "=== DISK ==="
    df -h /
    echo "=== TEMPERATURE ==="
    cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null || echo "N/A"
    echo "=== DMESG (last 50 lines) ==="
    dmesg | tail -50
    echo "=== END INITIAL STATE ==="
} > "$SYSLOG" 2>&1

echo "Build log: $BUILDLOG"
echo "System log: $SYSLOG"
echo "Starting build at $(date)..."

# Run build, capturing output
makepkg -sf 2>&1 | tee "$BUILDLOG"
BUILD_EXIT=${PIPESTATUS[0]}

# Capture post-build state
{
    echo ""
    echo "=== BUILD FINISHED: $(date) ==="
    echo "=== EXIT CODE: $BUILD_EXIT ==="
    echo "=== MEMORY ==="
    free -h
    echo "=== TEMPERATURE ==="
    cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null || echo "N/A"
    echo "=== DMESG (last 100 lines) ==="
    dmesg | tail -100
} >> "$SYSLOG" 2>&1

if [[ $BUILD_EXIT -eq 0 ]]; then
    echo ""
    echo "SUCCESS! Packages built:"
    ls -la *.pkg.tar.zst 2>/dev/null
else
    echo ""
    echo "BUILD FAILED (exit code: $BUILD_EXIT)"
    echo "Check logs in: $LOGDIR"
fi

# Create symlinks to latest logs
ln -sf "$BUILDLOG" "$LOGDIR/build-latest.log"
ln -sf "$SYSLOG" "$LOGDIR/system-latest.log"

echo ""
echo "Latest logs symlinked to:"
echo "  $LOGDIR/build-latest.log"
echo "  $LOGDIR/system-latest.log"
