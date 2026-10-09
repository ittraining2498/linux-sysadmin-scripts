#!/usr/bin/env bash
#
# cluster-health.sh — Report Proxmox VE node, cluster, storage and guest health.
#
# Usage:
#   ./cluster-health.sh
#   ./cluster-health.sh --warn 90
#   ./cluster-health.sh --quiet
#
# Options:
#   --warn PERCENT    alert at or above 0-100 (default 85; -w accepted)
#   --quiet           print only warnings and errors (-q accepted)
#   -h, --help        show this help
#
# Exit codes: 0 = healthy, 1 = problem or failed check, 2 = usage/environment error.
#
# IT Training Company Limited | https://www.ittraining.co.th | LINE @linux

set -euo pipefail
usage() { sed -n '2,/^$/p' "$0" | sed 's/^# *//'; }
die() { printf '%s [ERROR] %s\n' "$(date '+%F %T')" "$*" >&2; exit 2; }
WARN=85
QUIET=false
problems=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--warn) [[ $# -ge 2 && -n "$2" ]] || die "$1 requires a percentage"; WARN=$2; shift 2 ;;
        -q|--quiet) QUIET=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done
[[ "$WARN" =~ ^[0-9]{1,3}$ ]] || die '--warn must be an integer from 0 to 100'
WARN=$((10#$WARN))
(( WARN <= 100 )) || die '--warn must be an integer from 0 to 100'
[[ $(uname -s) == Linux ]] || die 'run this script on a Proxmox VE Linux node'
[[ $EUID -eq 0 ]] || die 'run as root on the Proxmox node (sudo bash cluster-health.sh)'
for cmd in pveversion pvecm pvesm qm pct systemctl df awk; do
    command -v "$cmd" >/dev/null || die "required command missing: $cmd; run on a Proxmox VE node"
done
ok() { if ! $QUIET; then printf '%s [OK] %s\n' "$(date '+%F %T')" "$*"; fi; }
warn() { printf '%s [WARN] %s\n' "$(date '+%F %T')" "$*"; problems=$((problems + 1)); }
if version=$(pveversion); then ok "$version"; else warn 'pveversion failed'; fi

# A failed cluster command is not evidence that the node is standalone.
if [[ -f /etc/pve/corosync.conf ]]; then
    if cluster=$(pvecm status); then
        if grep -Eiq '^[[:space:]]*Quorate:[[:space:]]+Yes[[:space:]]*$' <<< "$cluster"; then
            ok 'cluster is quorate'
        else
            warn 'cluster is NOT quorate or quorum could not be determined'
        fi
        if nodes=$(pvecm nodes); then ok "cluster nodes: $nodes"; else warn 'could not read cluster nodes'; fi
    else
        warn 'pvecm status failed for a configured cluster; check corosync and node connectivity'
    fi
else
    ok 'standalone node (no corosync configuration)'
fi
for svc in pve-cluster pvedaemon pveproxy pvestatd; do
    if systemctl is-active --quiet "$svc"; then ok "$svc is active"; else warn "$svc is NOT active"; fi
done
if storage=$(LC_ALL=C pvesm status); then
    storage_count=0
    while read -r name type status total used _ pct_value; do
        [[ -n "$name" && "$name" != Name ]] || continue
        storage_count=$((storage_count + 1))
        if [[ "$status" != active ]]; then warn "storage '$name' ($type) is $status"; continue; fi
        if [[ ! "$pct_value" =~ ^[0-9]+([.][0-9]+)?%$ ]]; then warn "invalid usage for storage '$name': $pct_value"; continue; fi
        pct_num=${pct_value%\%}; pct_num=${pct_num%%.*}; pct_num=$((10#$pct_num))
        if (( pct_num >= WARN )); then warn "storage '$name' is $pct_value full ($used of $total)"; else ok "storage '$name' $pct_value used"; fi
    done <<< "$storage"
    if (( storage_count == 0 )); then warn 'no storage rows returned'; fi
else
    warn 'pvesm status failed; storage health is unknown'
fi
if disks=$(LC_ALL=C df -hP -x tmpfs -x devtmpfs -x squashfs); then
    first=true; disk_count=0
    while read -r fs size used _ pct_value mount; do
        if $first; then first=false; continue; fi
        [[ -n "$fs" ]] || continue
        [[ "$mount" =~ ^/(dev|proc|sys|run)(/|$) ]] && continue
        if [[ ! "$pct_value" =~ ^[0-9]+%$ || -z "$mount" ]]; then warn 'invalid filesystem row'; continue; fi
        disk_count=$((disk_count + 1)); pct_num=${pct_value%\%}; pct_num=$((10#$pct_num))
        if (( pct_num >= WARN )); then warn "$mount is $pct_value full ($used of $size)"; else ok "$mount $pct_value used"; fi
    done <<< "$disks"
    if (( disk_count == 0 )); then warn 'no local filesystems were checked'; fi
else
    warn 'df failed; local filesystem health is unknown'
fi
for kind in qm pct; do
    if guests=$("$kind" list); then
        if [[ "$guests" != *VMID* ]]; then warn "$kind list returned an invalid report"; continue; fi
        status_column=3; [[ "$kind" != pct ]] || status_column=2
        counts=$(awk -v col="$status_column" 'NR>1 && NF {total++; if ($col=="running") running++} END {printf "%d running / %d total",running,total}' <<< "$guests")
        ok "$kind: $counts"
    else
        warn "$kind list failed; guest counts are unknown"
    fi
done
if (( problems > 0 )); then printf '%d problem(s) found.\n' "$problems"; exit 1; fi
ok 'All checks passed.'
exit 0
