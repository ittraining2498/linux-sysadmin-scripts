#!/usr/bin/env bash
#
# system-info.sh — Display Linux system information without changing the system.
#
# Usage:
#   ./system-info.sh                 # Thai menu in a terminal; full report otherwise
#   ./system-info.sh --all
#   ./system-info.sh --memory
#
# Options:
#   --menu         open the Thai menu (terminal required)
#   --all          show system, memory and disk information
#   --system       show operating system, kernel, CPU count and uptime
#   --memory       show RAM and swap usage
#   --disk         show filesystem usage
#   -h, --help     show this header
#
# Exit codes: 0 = report collected/cancelled, 1 = collection failed,
#             2 = invalid option or unsupported environment.
#
# IT Training Company Limited | https://www.ittraining.co.th | LINE @linux

set -euo pipefail
usage() { sed -n '2,/^$/p' "$0" | sed 's/^# *//'; }
die() { printf '%s [ERROR] %s\n' "$(date '+%F %T')" "$1" >&2; exit 2; }
MODE=--all
if [[ $# -eq 0 && -t 0 && -t 1 ]]; then MODE=--menu;
elif [[ $# -gt 0 ]]; then
    [[ $# -eq 1 ]] || die 'เลือกตัวเลือกครั้งละหนึ่งรายการ / use one option'
    MODE=$1
fi
case "$MODE" in
    -h|--help) usage; exit 0 ;;
    --all|--system|--memory|--disk|--menu) ;;
    *) die "unknown option: $MODE" ;;
esac
[[ $(uname -s) == Linux ]] || die 'ใช้บน Linux เท่านั้น / Linux required'
if [[ "$MODE" == --menu ]]; then
    [[ -t 0 && -t 1 ]] || die 'เมนูต้องเปิดใน Terminal'
    while true; do
        printf '\nดูข้อมูลเครื่อง Linux — IT Training\nอ่านข้อมูลเท่านั้น ไม่ต้อง sudo ไม่แก้ไขระบบ\n1. ดูภาพรวมทั้งหมด\n2. ดูระบบปฏิบัติการ CPU และเวลาทำงาน\n3. ดูหน่วยความจำ RAM และ swap\n4. ดูพื้นที่ดิสก์\n0. ออกจากโปรแกรม\n'
        if ! IFS= read -r -p 'เลือกหมายเลข: ' choice; then printf '\nยกเลิกแล้ว\n'; exit 0; fi
        case "$choice" in
            0) printf 'ออกแล้ว ไม่มีการเปลี่ยนแปลงข้อมูล\n'; exit 0 ;;
            1) MODE=--all; break ;;
            2) MODE=--system; break ;;
            3) MODE=--memory; break ;;
            4) MODE=--disk; break ;;
            *) printf 'กรุณาเลือกหมายเลข 0–4\n' ;;
        esac
    done
fi
failed=0
# Capture each command's status explicitly so a failure never looks successful.
report() {
    local title=$1
    shift
    printf '\n%s [INFO] %s\n' "$(date '+%F %T')" "$title"
    if ! "$@"; then
        printf '%s [ERROR] อ่านข้อมูลไม่สำเร็จ: %s\n' "$(date '+%F %T')" "$title" >&2
        failed=1
    fi
}
if [[ "$MODE" == --all || "$MODE" == --system ]]; then
    report 'ระบบปฏิบัติการ (ชื่อและรุ่น)' awk -F= '/^(NAME|VERSION|PRETTY_NAME)=/ {print}' /etc/os-release
    report 'เคอร์เนลและสถาปัตยกรรม' uname -srmo
    report 'จำนวน CPU ที่ใช้งานได้' getconf _NPROCESSORS_ONLN
    report 'เวลาทำงานและค่าโหลด (ไม่ใช่เปอร์เซ็นต์ CPU)' uptime
fi
if [[ "$MODE" == --all || "$MODE" == --memory ]]; then
    report 'RAM และ swap: available คือ RAM ที่พร้อมให้โปรแกรมใช้' free -h
fi
if [[ "$MODE" == --all || "$MODE" == --disk ]]; then
    report 'ดิสก์: Use% คือพื้นที่ที่ใช้; Mounted on คือจุดเชื่อมต่อ' df -hP -x tmpfs -x devtmpfs -x squashfs
fi
if (( failed )); then printf '\nรายงานไม่ครบ กรุณาตรวจข้อผิดพลาดด้านบน\n'; exit 1; fi
printf '\nอ่านข้อมูลเสร็จ รายงานนี้ไม่ได้ตัดสินว่าระบบปกติหรือผิดปกติ\n'
