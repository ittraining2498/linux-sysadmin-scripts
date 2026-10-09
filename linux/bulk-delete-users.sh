#!/usr/bin/env bash
#
# bulk-delete-users.sh — Delete multiple Linux users safely in one run.
#
# Usage:
#   ./bulk-delete-users.sh alice bob carol          # dry-run (default)
#   ./bulk-delete-users.sh --file users.txt --apply     # actually delete
#   ./bulk-delete-users.sh --file users.txt --apply --remove-home
#
# Options:
#   -f, --file FILE     read usernames from FILE (one per line, # = comment)
#       --apply         perform the deletion (without it, dry-run only)
#       --remove-home   also remove the home directory (userdel -r)
#       --min-uid N     refuse to touch accounts below this UID (default 1000)
#   -y, --yes           do not ask for interactive confirmation
#   -h, --help          show this help
#
# Exit codes: 0 = success/preview, 1 = failed action or no eligible users,
#             2 = invalid input/environment.
#
# IT Training Company Limited | https://www.ittraining.co.th | LINE @linux

set -euo pipefail
umask 077

MIN_UID=1000
APPLY=false
REMOVE_HOME=false
ASSUME_YES=false
BACKUP_DIR="/var/backups/deleted-users"
LOG_FILE="/var/log/bulk-delete-users.log"
PROTECTED=(root daemon bin sys sync games man lp mail news uucp proxy www-data backup nobody systemd-network sshd)
USERS=()

log() {
    local message
    message="$(date '+%F %T') [$1] $2"
    printf '%s\n' "$message" >&2
    if [[ "${LOG_READY:-false}" == true ]]; then printf '%s\n' "$message" >&4; fi
}
die() { log ERROR "$1"; exit 2; }
usage() { sed -n '2,/^$/p' "$0" | sed 's/^# *//'; exit 0; }

# ---------- parse arguments ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)      [[ $# -ge 2 && -f "$2" && -r "$2" ]] || die "--file requires a readable file"
                        while IFS= read -r line || [[ -n "$line" ]]; do
                            line=${line%$'\r'}
                            [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
                            USERS+=("$line")
                        done < "$2"
                        shift 2 ;;
        --apply)        APPLY=true;        shift ;;
        --remove-home)  REMOVE_HOME=true;  shift ;;
        --min-uid)      [[ $# -ge 2 ]] || die "--min-uid requires a number"; MIN_UID="$2"; shift 2 ;;
        -y|--yes)       ASSUME_YES=true;   shift ;;
        -h|--help)      usage ;;
        -*)             die "unknown option: $1" ;;
        *)              USERS+=("$1");     shift ;;
    esac
done

[[ "$MIN_UID" =~ ^[0-9]{1,9}$ ]] || die '--min-uid must be an integer of at least 1000'
MIN_UID=$((10#$MIN_UID))
(( MIN_UID >= 1000 )) || die '--min-uid cannot be below 1000'
[[ $(uname -s) == Linux ]] || die 'run this script with Bash on a Linux server'
for cmd in id getent tar userdel pkill realpath stat; do command -v "$cmd" >/dev/null || die "required command missing: $cmd"; done
[[ ${#USERS[@]} -gt 0 ]] || die "no users specified (use -h for help)"
[[ $EUID -eq 0 ]] || die "must run as root"

# ---------- validate ----------
TARGETS=()
for u in "${USERS[@]}"; do
    u="${u%$'\r'}"
    [[ "$u" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "invalid username: $u"
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

    if [[ "$uid" == "${SUDO_UID:-0}" ]]; then log SKIP "$u - invoking operator account"; continue; fi
    if ! awk -F: -v name="$u" '$1 == name {found=1} END {exit !found}' /etc/passwd; then
        log SKIP "$u - not a local account"; continue
    fi
    duplicate=false
    for target in "${TARGETS[@]}"; do [[ "$target" != "$u" ]] || duplicate=true; done
    if $duplicate; then log SKIP "$u - duplicate input"; continue; fi
    if who | awk '{print $1}' | grep -qx "$u"; then
        log WARN "$u - currently logged in, session will be killed"
    fi

    TARGETS+=("$u")
done

if (( ${#TARGETS[@]} == 0 )); then log WARN "nothing to do: no eligible users"; exit 1; fi

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
    read -rp "Type 'yes' to permanently delete these users: " answer || die "confirmation missing; use --yes only for an intentional unattended deletion"
    [[ "$answer" == "yes" ]] || die "aborted by operator"
fi

# ---------- delete ----------
[[ ! -L "$LOG_FILE" && ( ! -e "$LOG_FILE" || -f "$LOG_FILE" ) ]] || die "unsafe log path: $LOG_FILE"
exec 4>>"$LOG_FILE"
LOG_READY=true
[[ ! -L "$BACKUP_DIR" ]] || die 'backup directory must not be a symlink'
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
# Preserve account records as well as home data before deleting any account.
record_backup=$(mktemp -d "$BACKUP_DIR/accounts-XXXXXXXX")
cp -p /etc/passwd /etc/group /etc/shadow "$record_backup/"
if [[ -f /etc/gshadow ]]; then cp -p /etc/gshadow "$record_backup/"; fi
log INFO "account records backed up to $record_backup"
failed=0

for u in "${TARGETS[@]}"; do
    home=$(getent passwd "$u" | cut -d: -f6)

    # Refuse shared/system home paths before backing up or terminating sessions.
    if [[ "$home" != /* || -L "$home" ]]; then
        log ERROR "$u - unsafe or symlink home: $home"; failed=$((failed + 1)); continue
    fi
    canonical=$(realpath -m -- "$home")
    case "$canonical" in
        /|/home|/root|/etc|/etc/*|/usr|/usr/*|/var|/bin|/sbin|/lib|/lib64|/tmp|/opt|/srv|/dev|/dev/*|/proc|/proc/*|/sys|/sys/*|/run|/run/*|"$BACKUP_DIR"|"$BACKUP_DIR"/*)
            log ERROR "$u - refusing system/shared home: $canonical"; failed=$((failed + 1)); continue ;;
    esac
    if awk -F: -v name="$u" -v home="$home" '$1 != name && ($6 == home || index($6, home "/") == 1) {found=1} END {exit !found}' /etc/passwd; then
        log ERROR "$u - home shared with another account"; failed=$((failed + 1)); continue
    fi
    if [[ -d "$home" && $(stat -c %u -- "$home") != "$(id -u "$u")" ]]; then
        log ERROR "$u - home is not owned by this user; refusing deletion"; failed=$((failed + 1)); continue
    fi
    if [[ -d "$home" ]]; then
        archive=$(mktemp "$BACKUP_DIR/${u}-XXXXXXXX.tar.gz")
        if tar -czf "$archive" -C "$(dirname "$home")" "$(basename "$home")"; then
            log INFO "$u - home backed up to $archive"
        else
            log WARN "$u - backup failed, skipping this user"
            failed=$((failed + 1)); continue
        fi
    fi

    log INFO "$u - terminating processes before userdel"
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
