#!/usr/bin/env bash
#
# bulk-create-users.sh — Create many Linux users at once from a CSV file.
#
# CSV format (header optional, # = comment):
#   username,full name,groups
#   somchai,Somchai Jaidee,"sudo,docker"
#   somsri,Somsri Rakdee,
#
# Usage:
#   ./bulk-create-users.sh -f staff.csv              # dry-run (default)
#   ./bulk-create-users.sh -f staff.csv --apply
#
# Options:
#   -f, --file FILE      CSV file to read (required)
#       --apply          actually create the accounts
#       --shell SHELL    login shell (default /bin/bash)
#       --no-expire      do not force a password change at first login
#   -o, --out FILE       where to write the generated passwords
#                        (default ./new-users-<date>.txt, mode 600)
#   -h, --help           show this help
#
# IT Training Company Limited | https://www.ittraining.co.th | LINE @linux

set -euo pipefail

CSV=""
APPLY=false
SHELL_PATH="/bin/bash"
FORCE_EXPIRE=true
OUT="./new-users-$(date +%Y%m%d-%H%M%S).txt"

usage() { sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }
die()   { echo "ERROR: $1" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)   CSV="$2";          shift 2 ;;
        --apply)     APPLY=true;        shift ;;
        --shell)     SHELL_PATH="$2";   shift 2 ;;
        --no-expire) FORCE_EXPIRE=false; shift ;;
        -o|--out)    OUT="$2";          shift 2 ;;
        -h|--help)   usage ;;
        *)           die "unknown option: $1" ;;
    esac
done

[[ -n "$CSV" ]]  || die "no CSV file given (use -h for help)"
[[ -r "$CSV" ]]  || die "cannot read file: $CSV"
[[ $EUID -eq 0 ]] || die "must run as root"
[[ -x "$SHELL_PATH" ]] || die "shell not found: $SHELL_PATH"

gen_password() {
    # 16 characters from a set that avoids visually ambiguous glyphs (no 0/O/1/l/I).
    # A fixed-size chunk is read first so no process in the pipe exits early and
    # triggers SIGPIPE under 'set -o pipefail'.
    LC_ALL=C tr -dc 'A-HJ-NP-Za-km-z2-9' < <(head -c 4096 /dev/urandom) | cut -c1-16
}

printf '\n%-16s %-26s %-20s %s\n' "USER" "FULL NAME" "GROUPS" "ACTION"
printf '%s\n' "------------------------------------------------------------------------------"

created=0; skipped=0
declare -a NEW_LINES=()

while IFS=, read -r username fullname groups || [[ -n "${username:-}" ]]; do
    username="$(echo "${username:-}" | tr -d '[:space:]"')"
    [[ -z "$username" || "$username" == \#* ]] && continue
    [[ "$username" == "username" ]] && continue          # skip CSV header

    fullname="$(echo "${fullname:-}" | sed 's/^ *//; s/ *$//; s/"//g')"
    groups="$(echo "${groups:-}" | tr -d '[:space:]"')"

    if id -u "$username" &>/dev/null; then
        printf '%-16s %-26s %-20s %s\n' "$username" "$fullname" "${groups:--}" "SKIP (exists)"
        skipped=$((skipped + 1)); continue
    fi

    printf '%-16s %-26s %-20s %s\n' "$username" "$fullname" "${groups:--}" "CREATE"

    if $APPLY; then
        password="$(gen_password)"
        useradd -m -s "$SHELL_PATH" -c "$fullname" "$username"
        echo "${username}:${password}" | chpasswd
        if $FORCE_EXPIRE; then chage -d 0 "$username"; fi
        if [[ -n "$groups" ]]; then
            usermod -aG "$groups" "$username" || echo "WARN: could not add $username to $groups" >&2
        fi
        NEW_LINES+=("${username},${password}")
    fi
    created=$((created + 1))
done < "$CSV"

echo
if ! $APPLY; then
    printf 'DRY-RUN - nothing was created. %d would be created, %d skipped.\n' "$created" "$skipped"
    printf 'Re-run with --apply to create the accounts.\n'
    exit 0
fi

if (( ${#NEW_LINES[@]} > 0 )); then
    umask 077
    {
        echo "# Generated $(date '+%F %T') by bulk-create-users.sh"
        echo "# username,password  - users must change the password at first login"
        printf '%s\n' "${NEW_LINES[@]}"
    } > "$OUT"
    chmod 600 "$OUT"
    printf 'Created %d user(s), skipped %d.\n' "$created" "$skipped"
    printf 'Passwords written to %s (mode 600) - deliver them securely, then delete the file.\n' "$OUT"
else
    printf 'Nothing to do. %d skipped.\n' "$skipped"
fi
