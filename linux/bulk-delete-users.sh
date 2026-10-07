#!/usr/bin/env bash
#
# bulk-delete-users.sh — Delete multiple Linux users safely in one run.
#
# Usage:
#   ./bulk-delete-users.sh alice bob carol          # dry-run (default)
#   ./bulk-delete-users.sh -f users.txt --apply     # actually delete
#   ./bulk-delete-users.sh -f users.txt --apply --remove-home
#
# Options:
#   -f, --file FILE     read usernames from FILE (one per line, # = comment)
#       --apply         perform the deletion (without it, dry-run only)
#       --remove-home   also remove the home directory (userdel -r)
#       --min-uid N     refuse to touch accounts below this UID (default 1000)
#   -y, --yes           do not ask for interactive confirmation
#   -h, --help          show this help
#
# IT Training Company Limited | https://www.ittraining.co.th | LINE @linux

set -euo pipefail

MIN_UID=1000
APPLY=false
REMOVE_HOME=false
ASSUME_YES=false
BACKUP_DIR="/var/backups/deleted-users"
LOG_FILE="/var/log/bulk-delete-users.log"
PROTECTED=(root daemon bin sys sync games man lp mail news uucp proxy www-data backup nobody systemd-network sshd)
USERS=()

log() { printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" | tee -a "$LOG_FILE" >&2; }
die() { log ERROR "$1"; exit 1; }

usage() {
    sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

# ---------- parse arguments ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)      [[ -r "${2:-}" ]] || die "cannot read file: ${2:-<missing>}"
                        mapfile -t -O "${#USERS[@]}" USERS < <(grep -vE '^[[:space:]]*(#|$)' "$2")
                        shift 2 ;;
        --apply)        APPLY=true;        shift ;;
        --remove-home)  REMOVE_HOME=true;  shift ;;
        --min-uid)      MIN_UID="$2";      shift 2 ;;
        -y|--yes)       ASSUME_YES=true;   shift ;;
        -h|--help)      usage ;;
        -*)             die "unknown option: $1" ;;
        *)              USERS+=("$1");     shift ;;
    esac
done

[[ ${#USERS[@]} -gt 0 ]] || die "no users specified (use -h for help)"
[[ $EUID -eq 0 ]] || die "must run as root"

# ---------- validate ----------
TARGETS=()
for u in "${USERS[@]}"; do
    u="${u//[[:space:]]/}"
    [[ -n "$u" ]] || continue

    if ! id -u "$u" &>/dev/null; then
        log SKIP "$u - no such user"; continue
    fi

    for p in "${PROTECTED[@]}"; do
        if [[ "$u" == "$p" ]]; then
            log SKIP "$u - protected account"
            continue 2
        fi
    done

    uid=$(id -u "$u")
    if (( uid < MIN_UID )); then
        log SKIP "$u - UID $uid below minimum $MIN_UID"; continue
    fi

    if who | awk '{print $1}' | grep -qx "$u"; then
        log WARN "$u - currently logged in, session will be killed"
    fi

    TARGETS+=("$u")
done

[[ ${#TARGETS[@]} -gt 0 ]] || die "nothing to do"

# ---------- preview ----------
printf '\n%-18s %-8s %-28s\n' "USER" "UID" "HOME"
printf '%s\n' "---------------------------------------------------------"
for u in "${TARGETS[@]}"; do
    printf '%-18s %-8s %-28s\n' "$u" "$(id -u "$u")" "$(getent passwd "$u" | cut -d: -f6)"
done
printf '\nTotal: %d user(s)   remove-home=%s\n\n' "${#TARGETS[@]}" "$REMOVE_HOME"

if ! $APPLY; then
    echo "DRY-RUN - nothing was changed. Re-run with --apply to delete."
    exit 0
fi

if ! $ASSUME_YES; then
    read -rp "Type 'yes' to permanently delete these users: " answer
    [[ "$answer" == "yes" ]] || die "aborted by operator"
fi

# ---------- delete ----------
mkdir -p "$BACKUP_DIR"
failed=0

for u in "${TARGETS[@]}"; do
    home=$(getent passwd "$u" | cut -d: -f6)

    if [[ -d "$home" ]]; then
        archive="$BACKUP_DIR/${u}-$(date +%Y%m%d-%H%M%S).tar.gz"
        if tar -czf "$archive" -C "$(dirname "$home")" "$(basename "$home")" 2>/dev/null; then
            log INFO "$u - home backed up to $archive"
        else
            log WARN "$u - backup failed, skipping this user"
            failed=$((failed + 1)); continue
        fi
    fi

    pkill -KILL -u "$u" 2>/dev/null || true
    sleep 1

    if $REMOVE_HOME; then
        if userdel -r "$u"; then log INFO "$u - deleted (home removed)"; else log ERROR "$u - userdel failed"; failed=$((failed + 1)); fi
    else
        if userdel "$u"; then log INFO "$u - deleted (home kept)"; else log ERROR "$u - userdel failed"; failed=$((failed + 1)); fi
    fi
done

log INFO "finished: $(( ${#TARGETS[@]} - failed )) deleted, $failed failed"
exit $(( failed > 0 ))
