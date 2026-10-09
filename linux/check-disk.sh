#!/usr/bin/env bash
#
# check-disk.sh — Report filesystem space and inode usage reliably.
#
# Usage:
#   ./check-disk.sh
#   ./check-disk.sh --warn 90 --inodes
#   ./check-disk.sh --quiet --exclude '^/mnt/archive(/|$)'
#
# Options:
#   --warn PERCENT     alert at or above 0-100 (default 85; -w accepted)
#   --exclude REGEX    skip matching mounts (default ^/(dev|proc|sys|run)(/|$))
#   --inodes           also check inode usage
#   --quiet            print only problems (-q accepted)
#   -h, --help         show this help
#
# Exit codes: 0 = healthy, 1 = threshold reached, 2 = usage or collection error.
#
# IT Training Company Limited | https://www.ittraining.co.th | LINE @linux

set -euo pipefail
usage() { sed -n '2,/^$/p' "$0" | sed 's/^# *//'; }
die() { printf '%s [ERROR] %s\n' "$(date '+%F %T')" "$*" >&2; exit 2; }
WARN=85
EXCLUDE='^/(dev|proc|sys|run)(/|$)'
CHECK_INODES=false
QUIET=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--warn) [[ $# -ge 2 && -n "$2" ]] || die "$1 requires a percentage"; WARN=$2; shift 2 ;;
        -x|--exclude) [[ $# -ge 2 ]] || die "$1 requires a regex"; EXCLUDE=$2; shift 2 ;;
        --inodes) CHECK_INODES=true; shift ;;
        -q|--quiet) QUIET=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done
[[ "$WARN" =~ ^[0-9]{1,3}$ ]] || die '--warn must be an integer from 0 to 100'
WARN=$((10#$WARN))
(( WARN <= 100 )) || die '--warn must be an integer from 0 to 100'
regex_status=0
validate_regex() { [[ '' =~ $EXCLUDE ]]; }
validate_regex || regex_status=$?
[[ $regex_status -ne 2 ]] || die '--exclude contains an invalid regex'
[[ $(uname -s) == Linux ]] || die 'Linux with GNU df is required; run this script on the target Linux server'
command -v df >/dev/null || die 'df is required'
problems=0
check_usage() {
    local kind=$1 output fs size used pct mount pct_num scanned=0 first=true
    local -a args=(-hP -x tmpfs -x devtmpfs -x squashfs)
    [[ "$kind" != INODE ]] || args+=(-i)
    if ! output=$(LC_ALL=C df "${args[@]}"); then
        die "df failed while collecting $kind usage; health is unknown"
    fi
    [[ -n "$output" ]] || die "df returned no $kind data"
    while read -r fs size used _ pct mount; do
        if $first; then first=false; continue; fi
        [[ -n "$fs" ]] || continue
        [[ -n "$mount" ]] || die "incomplete $kind row from df"
        if [[ -n "$EXCLUDE" && "$mount" =~ $EXCLUDE ]]; then continue; fi
        if [[ "$kind" == INODE && "$pct" == '-' ]]; then continue; fi
        [[ "$pct" =~ ^[0-9]+%$ ]] || die "invalid $kind percentage '$pct' on $mount"
        pct_num=${pct%\%}
        pct_num=$((10#$pct_num))
        scanned=$((scanned + 1))
        if (( pct_num >= WARN )); then
            printf '%s [WARN] %s %s: %s used (%s of %s) on %s\n' "$(date '+%F %T')" "$kind" "$mount" "$pct" "$used" "$size" "$fs"
            problems=$((problems + 1))
        fi
    done <<< "$output"
    (( scanned > 0 )) || die "no eligible filesystems with $kind data were checked; review --exclude"
}
check_usage DISK
if $CHECK_INODES; then check_usage INODE; fi
if (( problems > 0 )); then
    printf '%d threshold check(s) at or above %d%%\n' "$problems" "$WARN"
    exit 1
fi
if ! $QUIET; then printf 'OK - no filesystem is at or above %d%%\n' "$WARN"; fi
exit 0
