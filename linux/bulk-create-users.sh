#!/usr/bin/env bash
#
# bulk-create-users.sh — Create Linux users from validated CSV, dry-run by default.
#
# Usage:
#   sudo ./bulk-create-users.sh                    # Thai menu in a terminal
#   sudo bash bulk-create-users.sh --file staff.csv
#   sudo bash bulk-create-users.sh --file staff.csv --apply --out new-users.txt
#   CSV: username,full name,groups (header optional; quote comma-containing fields)
#
# Options:
#   --menu             Thai terminal menu; preview then confirm before --apply
#   --file FILE        CSV input (required; -f accepted); requires Python 3
#   --apply            create users; otherwise preview only
#   --shell SHELL      executable login shell (default /bin/bash)
#   --no-expire        do not force password change at first login
#   --out FILE         NEW password file, mode 600 (default new-users-<date>.txt)
#                      existing files are never overwritten; -o accepted
#   -h, --help         show this help
#
# Exit codes: 0 = success/preview, 1 = action failed, 2 = invalid input/environment.
#
# IT Training Company Limited | https://www.ittraining.co.th | LINE @linux

set -euo pipefail
umask 077
usage() { sed -n '2,/^$/p' "$0" | sed 's/^# *//'; }
die() { printf '%s [ERROR] %s\n' "$(date '+%F %T')" "$*" >&2; exit 2; }
CSV=''; APPLY=false; SHELL_PATH=/bin/bash; FORCE_EXPIRE=true
OUT="./new-users-$(date +%Y%m%d-%H%M%S).txt"
LOG_FILE=/var/log/bulk-create-users.log
PROTECTED=(root daemon bin sys sync games man lp mail news uucp proxy www-data backup nobody systemd-network sshd)
# Keep interactive input separate from the original non-interactive CLI.
menu_cancel() { printf '\nยกเลิกแล้ว ไม่มีการเปลี่ยนแปลงข้อมูล\n'; exit 0; }
menu_read() { IFS= read -r -p "$1" REPLY || menu_cancel; }
thai_menu() {
    [[ -t 0 && -t 1 ]] || die 'เมนูต้องเปิดใน Terminal'
    [[ $(uname -s) == Linux && $EUID -eq 0 ]] || die 'ใช้บน Linux โดยรันด้วย sudo'
    command -v python3 >/dev/null || die 'ต้องติดตั้ง Python 3 ก่อนใช้งาน'
    local action username fullname groups input output result
    while true; do
        printf '\nสร้างบัญชีผู้ใช้ — IT Training\n1. กรอกข้อมูลผู้ใช้ใหม่ทีละคน\n2. สร้างหลายคนจากไฟล์ CSV\n0. ออกจากโปรแกรม\n'
        menu_read 'เลือกหมายเลข: '; action=$REPLY
        case "$action" in 0) menu_cancel ;; 1|2) break ;; *) printf 'กรุณาเลือก 0, 1 หรือ 2\n' ;; esac
    done
    MENU_TEMP=$(mktemp -d)
    trap 'rm -rf -- "$MENU_TEMP"' EXIT
    trap 'exit 130' INT TERM
    if [[ "$action" == 1 ]]; then
        menu_read 'ชื่อบัญชีใหม่ เช่น somchai (Enter = ยกเลิก): '; username=$REPLY
        [[ -n "$username" ]] || menu_cancel
        menu_read 'ชื่อแสดงผล เช่น สมชาย ใจดี: '; fullname=$REPLY
        printf 'กลุ่มเสริมต้องมีอยู่แล้ว เว้นว่างได้ ไม่ควรให้ sudo/docker หากไม่จำเป็น\n'
        menu_read 'กลุ่มเสริม คั่นด้วยจุลภาค หรือ Enter เพื่อไม่เพิ่ม: '; groups=$REPLY
        python3 - "$MENU_TEMP/staff.csv" "$username" "$fullname" "$groups" <<'CSV'
import csv, sys
with open(sys.argv[1], 'w', newline='', encoding='utf-8') as f:
    csv.writer(f).writerow(sys.argv[2:])
CSV
    else
        printf 'CSV มี 3 ช่อง: username,full name,groups เช่น somchai,Somchai,\n'
        menu_read 'เส้นทางไฟล์ CSV (Enter = ยกเลิก): '; input=$REPLY
        [[ -n "$input" ]] || menu_cancel
        [[ -f "$input" && -r "$input" ]] || die 'ไม่พบไฟล์ CSV ที่อ่านได้ กรุณาตรวจเส้นทาง'
        cp -- "$input" "$MENU_TEMP/staff.csv"
    fi
    printf '\nตรวจข้อมูลและแสดงแผน ยังไม่สร้างบัญชี:\n'
    bash "$0" --file "$MENU_TEMP/staff.csv" || die 'ข้อมูลไม่ผ่านการตรวจ ยังไม่สร้างบัญชี กรุณาแก้ข้อมูลแล้วเปิดใหม่'
    menu_read 'ไฟล์ใหม่สำหรับเก็บรหัสผ่าน (Enter = ใช้ชื่ออัตโนมัติ): '; output=$REPLY
    [[ -n "$output" ]] || output="./new-users-$(date +%Y%m%d-%H%M%S).txt"
    printf '\nรหัสผ่านจะเก็บที่: %s (สิทธิ์ 600) ห้ามเผยแพร่ไฟล์นี้\nบัญชีใหม่ต้องเปลี่ยนรหัสผ่านเมื่อเข้าใช้ครั้งแรก\n' "$output"
    menu_read 'พิมพ์ สร้าง เพื่อยืนยันสร้างจริง หรือ Enter เพื่อยกเลิก: '
    [[ "$REPLY" == สร้าง ]] || menu_cancel
    result=0
    bash "$0" --file "$MENU_TEMP/staff.csv" --apply --out "$output" || result=$?
    if (( result == 0 )); then printf '\nประมวลผลเสร็จ ตรวจจำนวนที่สร้าง/ข้ามด้านบน หากข้ามทั้งหมดจะไม่มีไฟล์รหัสผ่านใหม่\n';
    else printf '\nพบข้อผิดพลาด บางบัญชีอาจสร้างแล้ว ตรวจ /var/log/bulk-create-users.log ก่อนลองใหม่\n'; fi
    exit "$result"
}
if [[ $# -eq 0 && -t 0 && -t 1 ]] || [[ $# -eq 1 && "$1" == --menu ]]; then thai_menu; fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file|-o|--out|--shell)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "$1 requires a value"
            case "$1" in -f|--file) CSV=$2 ;; -o|--out) OUT=$2 ;; --shell) SHELL_PATH=$2 ;; esac
            shift 2 ;;
        --apply) APPLY=true; shift ;;
        --no-expire) FORCE_EXPIRE=false; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done
[[ $(uname -s) == Linux ]] || die 'run this script with Bash on a Linux server'
[[ -n "$CSV" && -f "$CSV" && -r "$CSV" ]] || die 'provide a readable CSV file with --file'
[[ $EUID -eq 0 ]] || die 'must run as root (sudo bash bulk-create-users.sh --file staff.csv)'
[[ "$SHELL_PATH" == /* && -x "$SHELL_PATH" ]] || die "invalid login shell: $SHELL_PATH"
for cmd in python3 getent id useradd chpasswd chage; do command -v "$cmd" >/dev/null || die "required command missing: $cmd"; done
# Parse all rows before changing accounts. The CSV module handles quotes, BOM and CRLF.
if ! rows=$(python3 - "$CSV" <<'PY'
import csv, re, sys
try:
    with open(sys.argv[1], encoding='utf-8-sig', newline='') as f:
        seen = set()
        for row in csv.reader(f, strict=True):
            if not row or not any(x.strip() for x in row) or row[0].lstrip().startswith('#'):
                continue
            if [x.strip().lower() for x in row] == ['username', 'full name', 'groups']:
                continue
            if len(row) != 3:
                raise ValueError('each CSV row must have exactly 3 columns; quote fields containing commas')
            username, fullname, groups = (x.strip() for x in row)
            if not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}', username):
                raise ValueError('invalid username: ' + repr(username))
            if username in seen:
                raise ValueError('duplicate username: ' + username)
            seen.add(username)
            if any(c in fullname for c in ':\t\r\n'):
                raise ValueError('full name cannot contain colon, tab or newline')
            group_list = [g.strip() for g in groups.split(',')] if groups else []
            if any(not re.fullmatch(r'[a-zA-Z_][a-zA-Z0-9_.-]*\$?', g) for g in group_list):
                raise ValueError('invalid group list for ' + username)
            print(username + ':' + fullname + ':' + ','.join(group_list))
except (OSError, UnicodeError, csv.Error, ValueError) as e:
    print('CSV ERROR: ' + str(e), file=sys.stderr)
    sys.exit(2)
PY
); then die 'CSV validation failed; no accounts changed'; fi
[[ -n "$rows" ]] || die 'CSV has no user rows'
USER_NAMES=(); FULL_NAMES=(); GROUP_LISTS=(); skipped=0
while IFS=: read -r username fullname groups; do
    protected=false
    for p in "${PROTECTED[@]}"; do [[ "$username" != "$p" ]] || protected=true; done
    if $protected || id -u "$username" >/dev/null 2>&1; then
        printf '%s [SKIP] %s: protected or already exists\n' "$(date '+%F %T')" "$username"
        skipped=$((skipped + 1)); continue
    fi
    if [[ -n "$groups" ]]; then
        IFS=, read -r -a group_names <<< "$groups"
        for group in "${group_names[@]}"; do getent group "$group" >/dev/null || die "group '$group' does not exist; no accounts changed"; done
    fi
    USER_NAMES+=("$username"); FULL_NAMES+=("$fullname"); GROUP_LISTS+=("$groups")
    printf '%s [PLAN] create %s; name=%s; groups=%s\n' "$(date '+%F %T')" "$username" "$fullname" "${groups:--}"
done <<< "$rows"
if ! $APPLY; then
    printf 'DRY-RUN - nothing was created. %d would be created, %d skipped.\n' "${#USER_NAMES[@]}" "$skipped"
    exit 0
fi
if (( ${#USER_NAMES[@]} == 0 )); then printf 'Nothing to do. %d skipped.\n' "$skipped"; exit 0; fi
# Open output before useradd so an unwritable path cannot lose generated passwords.
[[ ! -L "$OUT" && ! -e "$OUT" ]] || die "password output already exists: $OUT; choose a new --out path"
if ! (set -o noclobber; : > "$OUT"); then die "cannot create password output: $OUT; no accounts changed"; fi
chmod 600 "$OUT"
exec 3>>"$OUT"
[[ ! -L "$LOG_FILE" && ( ! -e "$LOG_FILE" || -f "$LOG_FILE" ) ]] || die "unsafe log path: $LOG_FILE"
exec 4>>"$LOG_FILE"
log() { printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" | tee -a /dev/fd/4 >&2; }
printf '# username,password\n' >&3
created=0; failed=0
for i in "${!USER_NAMES[@]}"; do
    username=${USER_NAMES[$i]}; groups=${GROUP_LISTS[$i]}
    password=$(python3 -c 'import secrets,string; print("".join(secrets.choice(string.ascii_letters+string.digits) for _ in range(20)))')
    args=(-m -K UID_MIN=1000 -s "$SHELL_PATH" -c "${FULL_NAMES[$i]}")
    [[ -z "$groups" ]] || args+=(-G "$groups")
    log INFO "creating $username"
    if ! useradd "${args[@]}" "$username"; then log ERROR "$username: useradd failed"; failed=$((failed + 1)); continue; fi
    printf '%s,%s\n' "$username" "$password" >&3
    if ! printf '%s:%s\n' "$username" "$password" | chpasswd; then
        log ERROR "$username: password setup failed; account needs administrator attention"
        failed=$((failed + 1)); continue
    fi
    if $FORCE_EXPIRE && ! chage -d 0 "$username"; then
        log ERROR "$username: forcing password expiry failed"; failed=$((failed + 1)); continue
    fi
    created=$((created + 1)); log INFO "$username: created"
done
log INFO "finished: $created created, $skipped skipped, $failed failed"
printf 'Passwords written to %s (mode 600). Deliver securely; check errors before use.\n' "$OUT"
exit $(( failed > 0 ))
