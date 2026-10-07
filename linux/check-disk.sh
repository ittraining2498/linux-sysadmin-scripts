#!/usr/bin/env bash
#
# check-disk.sh — Report filesystems whose usage is above a threshold.
#
# Usage:
#   ./check-disk.sh                  # warn at 85% (default)
#   ./check-disk.sh -w 90            # warn at 90%
#   ./check-disk.sh -w 80 --inodes   # also check inode usage
#   ./check-disk.sh -q               # quiet: print nothing when healthy
#
# Options:
#   -w, --warn PERCENT   usage percentage that counts as a problem (default 85)
#   -x, --exclude REGEX  skip mount points matching this regex
#       --inodes         also check inode usage, not just blocks
#   -q, --quiet          print only when something is over the threshold
#   -h, --help           show this help
#
# Exit codes: 0 = all healthy, 1 = at least one filesystem over threshold
#
# IT Training Company Limited | https://www.ittraining.co.th | LINE @linux

set -euo pipefail

WARN=85
EXCLUDE='^/(dev|proc|sys|run)'
CHECK_INODES=false
QUIET=false

usage() { sed -n '3,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--warn)    WARN="$2";        shift 2 ;;
        -x|--exclude) EXCLUDE="$2";     shift 2 ;;
        --inodes)     CHECK_INODES=true; shift ;;
        -q|--quiet)   QUIET=true;       shift ;;
        -h|--help)    usage ;;
        *)            echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

[[ "$WARN" =~ ^[0-9]+$ ]] || { echo "--warn must be a number" >&2; exit 2; }

problems=0
report=""

# ---------- block usage ----------
while read -r fs size used avail pct mount; do
    [[ "$mount" =~ $EXCLUDE ]] && continue
    pct_num="${pct%\%}"
    if (( pct_num >= WARN )); then
        report+=$(printf 'DISK  %-24s %4s used (%s of %s)  on %s\n' "$mount" "$pct" "$used" "$size" "$fs")
        report+=$'\n'
        problems=$((problems + 1))
    fi
done < <(df -hP -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2)

# ---------- inode usage ----------
if $CHECK_INODES; then
    while read -r fs inodes iused ifree ipct mount; do
        [[ "$mount" =~ $EXCLUDE ]] && continue
        [[ "$ipct" == "-" ]] && continue
        ipct_num="${ipct%\%}"
        if (( ipct_num >= WARN )); then
            report+=$(printf 'INODE %-24s %4s used (%s of %s)  on %s\n' "$mount" "$ipct" "$iused" "$inodes" "$fs")
            report+=$'\n'
            problems=$((problems + 1))
        fi
    done < <(df -iPh -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2)
fi

# ---------- output ----------
if (( problems > 0 )); then
    printf '%s' "$report"
    printf '\n%d filesystem(s) at or above %d%%\n' "$problems" "$WARN"
    exit 1
fi

$QUIET || printf 'OK - no filesystem is at or above %d%%\n' "$WARN"
exit 0
