#!/usr/bin/env bash
# Read-only RHEL/Linux health snapshot. Writes a timestamped text report.
set -u
OUT_DIR="${1:-./reports}"
SERVICE="${2:-sshd}"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR" || { echo "Cannot create output directory: $OUT_DIR" >&2; exit 1; }
OUT_FILE="$OUT_DIR/linux-health-$STAMP.txt"
{
  echo "Linux Basic Health Check"
  echo "Generated: $(date --iso-8601=seconds 2>/dev/null || date)"
  echo "Hostname: $(hostname 2>&1)"
  echo
  echo "=== Operating System ==="
  if [[ -r /etc/os-release ]]; then cat /etc/os-release; else uname -a; fi
  echo
  echo "=== Uptime / Load ==="
  uptime 2>&1 || true
  echo
  echo "=== Memory ==="
  free -h 2>&1 || true
  echo
  echo "=== Filesystem Usage ==="
  df -hT 2>&1 || true
  echo
  echo "=== Block Devices ==="
  lsblk 2>&1 || true
  echo
  echo "=== Service: $SERVICE ==="
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active "$SERVICE" 2>&1 || true
    systemctl status "$SERVICE" --no-pager -l 2>&1 | head -n 18 || true
  else
    echo "systemctl is unavailable on this system."
  fi
  echo
  echo "=== IP Addresses ==="
  ip -brief address 2>&1 || true
  echo
  echo "=== Default Route ==="
  ip route show default 2>&1 || true
  echo
  echo "NOTE: This report is a diagnostic snapshot, not an automated repair or definitive health verdict."
} > "$OUT_FILE"
printf 'Report saved to: %s\n' "$OUT_FILE"
