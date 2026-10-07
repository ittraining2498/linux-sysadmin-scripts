#!/usr/bin/env bash
#
# cluster-health.sh — One-page health check for a Proxmox VE node or cluster.
#
# Checks: cluster quorum, node status, pvedaemon/pveproxy/pve-cluster services,
#         storage usage, local disk usage, and running guests.
#
# Usage:
#   ./cluster-health.sh              # warn when storage is 85% full
#   ./cluster-health.sh -w 90
#   ./cluster-health.sh -q           # only print problems
#
# Options:
#   -w, --warn PERCENT   storage usage considered a problem (default 85)
#   -q, --quiet          print only warnings and errors
#   -h, --help           show this help
#
# Exit codes: 0 = healthy, 1 = at least one problem found
#
# IT Training Company Limited | https://www.ittraining.co.th | LINE @linux

set -uo pipefail

WARN=85
QUIET=false
problems=0

usage() { sed -n '3,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--warn) WARN="$2"; shift 2 ;;
        -q|--quiet) QUIET=true; shift ;;
        -h|--help) usage ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

ok()   { $QUIET || printf '  [ OK ]  %s\n' "$1"; }
warn() { printf '  [WARN]  %s\n' "$1"; problems=$((problems + 1)); }
head2() { $QUIET || printf '\n%s\n%s\n' "$1" "$(printf '%.0s-' {1..60})"; }

command -v pveversion >/dev/null 2>&1 || { echo "ERROR: this is not a Proxmox VE node" >&2; exit 2; }

# ---------- version ----------
head2 "Proxmox VE"
$QUIET || printf '  %s on %s\n' "$(pveversion | head -1)" "$(hostname -f 2>/dev/null || hostname)"

# ---------- cluster quorum ----------
head2 "Cluster"
if command -v pvecm >/dev/null 2>&1 && pvecm status >/dev/null 2>&1; then
    if pvecm status 2>/dev/null | grep -qi 'Quorate:.*Yes'; then
        ok "cluster is quorate"
    else
        warn "cluster is NOT quorate - check corosync and node connectivity"
    fi
    while read -r line; do
        [[ -z "$line" ]] && continue
        $QUIET || printf '  node: %s\n' "$line"
    done < <(pvecm nodes 2>/dev/null | tail -n +5 | awk '{print $3, $4}')
else
    ok "standalone node (no cluster configured)"
fi

# ---------- services ----------
head2 "Services"
for svc in pve-cluster pvedaemon pveproxy pvestatd; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        ok "$svc is active"
    else
        warn "$svc is NOT active"
    fi
done

# ---------- storage ----------
head2 "Storage"
while read -r name type status total used avail pct; do
    [[ "$name" == "Name" || -z "$name" ]] && continue
    if [[ "$status" != "active" ]]; then
        warn "storage '$name' ($type) is $status"
        continue
    fi
    pct_num="${pct%\%}"
    pct_num="${pct_num%%.*}"
    [[ "$pct_num" =~ ^[0-9]+$ ]] || continue
    if (( pct_num >= WARN )); then
        warn "storage '$name' is ${pct_num}% full ($used of $total)"
    else
        ok "storage '$name' ${pct_num}% used"
    fi
done < <(pvesm status 2>/dev/null)

# ---------- local disks ----------
head2 "Local filesystems"
while read -r fs size used avail pct mount; do
    [[ "$mount" =~ ^/(dev|proc|sys|run) ]] && continue
    pct_num="${pct%\%}"
    if (( pct_num >= WARN )); then
        warn "$mount is ${pct} full ($used of $size)"
    else
        ok "$mount ${pct} used"
    fi
done < <(df -hP -x tmpfs -x devtmpfs 2>/dev/null | tail -n +2)

# ---------- guests ----------
head2 "Guests"
vm_run=$(qm list 2>/dev/null | awk 'NR>1 && $3=="running"' | wc -l)
vm_all=$(qm list 2>/dev/null | awk 'NR>1' | wc -l)
ct_run=$(pct list 2>/dev/null | awk 'NR>1 && $2=="running"' | wc -l)
ct_all=$(pct list 2>/dev/null | awk 'NR>1' | wc -l)
$QUIET || printf '  VMs:        %s running / %s total\n' "$vm_run" "$vm_all"
$QUIET || printf '  Containers: %s running / %s total\n' "$ct_run" "$ct_all"

# ---------- summary ----------
echo
if (( problems > 0 )); then
    printf '%d problem(s) found.\n' "$problems"
    exit 1
fi
$QUIET || printf 'All checks passed.\n'
exit 0
