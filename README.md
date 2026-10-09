# linux-sysadmin-scripts

Bash scripts for Linux and Proxmox administration, maintained by
[IT Training](https://www.ittraining.co.th). Test in a disposable lab before production.
See the testing matrix below for verified environments. **Safe defaults** include:
dry-run first, protected system accounts, backups before destructive actions, and a log of what happened.

<p align="center"><strong>IT TRAINING · OPEN SOURCE TOOLKIT</strong><br>
<a href="https://ittraining2498.github.io/linux-sysadmin-scripts/"><strong>Explore the script library →</strong></a> &nbsp; · &nbsp;
<a href="https://github.com/ittraining2498#start-of-content"><strong>Meet &amp; follow the maintainer ↗</strong></a><br>
<sub>Open the maintainer profile, then select GitHub’s Follow button below the profile photo.</sub></p>

## Scripts

| Script | Platform | What it does |
|---|---|---|
| [`linux/bulk-delete-users.sh`](linux/bulk-delete-users.sh) | Linux | Delete many user accounts in one run — dry-run by default, backs up each home directory, refuses system accounts |
| [`linux/bulk-create-users.sh`](linux/bulk-create-users.sh) | Linux | Validate quoted CSV and groups before creating users; save passwords to a new mode-600 file |
| [`linux/check-disk.sh`](linux/check-disk.sh) | Linux | Check space/inodes; exit 1 for thresholds and 2 for failed collection or invalid options |
| [`proxmox/cluster-health.sh`](proxmox/cluster-health.sh) | Proxmox VE | Quorum, services, storage and guests; failed checks return non-zero, never a false healthy result |

## Usage

```bash
git clone https://github.com/ittraining2498/linux-sysadmin-scripts.git
cd linux-sysadmin-scripts
chmod +x linux/*.sh proxmox/*.sh
```

Every script supports `-h` / `--help`:

```bash
sudo ./linux/bulk-delete-users.sh --help
```

### Example — offboarding several users

```bash
# 1. preview only, nothing is changed
sudo ./linux/bulk-delete-users.sh alice bob carol

# 2. delete for real, keeping home directories
sudo ./linux/bulk-delete-users.sh --file leavers.txt --apply

# 3. delete and remove home directories too
sudo ./linux/bulk-delete-users.sh --file leavers.txt --apply --remove-home
```

### Example — onboarding from a CSV

`staff.csv`:

```csv
username,full name,groups
somchai,Somchai Jaidee,"sudo,docker"
somsri,Somsri Rakdee,
```

```bash
sudo ./linux/bulk-create-users.sh --file staff.csv           # preview
sudo ./linux/bulk-create-users.sh --file staff.csv --apply   # create
```

## Requirements and troubleshooting

- Run with **Bash on Linux**, not `sh`, PowerShell, or the macOS host shell.
- Account scripts require root and standard Linux shadow-utils (`useradd`, `userdel`, `chpasswd`, `chage`), `getent` and GNU utilities. Creation also requires **Python 3** for proper CSV parsing and password generation. Deletion uses `pkill` from procps.
- `check-disk.sh` requires GNU `df`; Proxmox checks must run **as root on a Proxmox VE node**, not an ordinary Linux server.
- Quick-copy commands assume you cloned the repository and are inside its directory. `staff.csv` and account names are examples: prepare your own file and replace names first. If you copy a full script, save it as the displayed `.sh` filename, with Unix LF line endings, and run `bash filename.sh --help`.
- To update an existing checkout, run `git pull --ff-only`. If Git reports local changes, preserve them before updating.
- On Debian/Ubuntu, install missing creation dependencies with `sudo apt-get install python3 passwd procps`.
- CSV has exactly three columns: `username,full name,groups`. Quote fields containing commas. Existing groups must already exist; invalid input is rejected before any account changes.
- Existing password files are never overwritten. Choose a new `--out` filename on each creation run. Accounts from a failed run may already exist; inspect the log and password file before retrying.
- Dry-run is intentional. Creation/deletion only changes accounts with `--apply`. Unattended deletion additionally needs `--yes`; never apply a preview you have not reviewed.
- Exit code **1 from monitoring is an alert**, not necessarily a crash. Code **2** indicates invalid input or an unsupported environment; the disk checker also uses 2 when collection fails. Read the printed message.
- Deletion backs up account databases and existing homes, rejects UID values below 1000, and refuses system/shared/symlink homes or homes not owned by the target user. Backups contain sensitive account records and are restricted to root.

## Safety rules used throughout

- **Dry-run is the default.** Destructive scripts do nothing until you pass `--apply`.
- **System accounts are protected.** Anything below UID 1000, and a hard-coded list of
  system users, is always skipped.
- **Backup before destroy.** Home directories are archived to `/var/backups/` first.
- **Account changes are logged** to `/var/log/`, with timestamps. Preview and monitoring output go to the terminal.
- **Useful exit codes.** `0` means healthy or successful, non-zero means something needs
  attention — so these scripts work inside cron, Ansible and monitoring checks.

## Testing status

| Script | Tested on |
|---|---|
| `linux/bulk-delete-users.sh` | Ubuntu 24.04 container, 2026-10-10 — real dry-run, deletion, backup content, protected UIDs and unsafe-home checks |
| `linux/bulk-create-users.sh` | Ubuntu 24.04 container, 2026-10-10 — real account creation, quoted CSV/BOM/CRLF, groups, password expiry and output permissions |
| `linux/check-disk.sh` | Ubuntu 24.04 container, 2026-10-10 — real block/inode checks; simulated df failure must return 2 |
| `proxmox/cluster-health.sh` | Ubuntu 24.04 container with simulated Proxmox commands, 2026-10-10 — quorum/storage/guest failure paths; **not tested on a real Proxmox node or cluster** |

CI runs ShellCheck, `bash -n`, and isolated Ubuntu container regression checks on every push and pull request. Proxmox command fixtures are not a substitute for a real-cluster test.

Latest local run: **69 command/exit-code checks passed**, plus assertions for backup contents, UID limits, password-file permissions, CSV full names and password expiry. Excerpts from the actual Ubuntu container output (timestamps are UTC):

```text
2026-10-09 22:16:26 [INFO] finished: 2 created, 0 skipped, 0 failed
2026-10-09 22:16:27 [INFO] finished: 1 deleted, 0 failed
TOTAL: 69 checks passed; real Linux account operations, Proxmox command fixtures only.
```

These results do not verify every distribution or the reporter's environment. Include the exact command, OS/version and full error when reporting a failure; remove credentials first.


## Contributing

Issues and pull requests are welcome — bug reports, support for other distributions,
or new scripts. Please keep the safety rules above intact, and make sure
`shellcheck --severity=warning` passes.

## License

[MIT](LICENSE) — free to use, modify and redistribute, including commercially.
Provided as is, without warranty. Test in a lab before running on production systems.

---

**คำอธิบายภาษาไทย**

รวมสคริปต์สำหรับผู้ดูแลระบบ Linux และ Proxmox โปรดทดสอบในแล็บก่อนใช้งานจริง
สคริปต์สร้างและลบผู้ใช้เริ่มเป็น dry-run ต้องใส่ `--apply` จึงเปลี่ยนแปลงบัญชี
ส่วนตรวจดิสก์และ Proxmox เป็นการอ่านข้อมูล โปรดดูระบบที่ทดสอบจริงในตารางด้านบน

ดูรายการสคริปต์แบบหน้าเว็บได้ที่ https://ittraining2498.github.io/linux-sysadmin-scripts/

เนื้อหาส่วนหนึ่งมาจากคอร์สอบรมของ [ไอทีเทรนนิ่ง](https://www.ittraining.co.th) — LINE: `@linux`


### ติดตามผู้พัฒนาและผลงานใหม่

<a href="https://github.com/ittraining2498#start-of-content"><img src="https://raw.githubusercontent.com/ittraining2498/ittraining2498/main/assets/profile/follow-community-3d-v3.png" width="100%" alt="ติดตาม IT Training — เปิดโปรไฟล์แล้วกด Follow ใต้รูปโปรไฟล์ด้วยตนเอง"></a>

<p align="center"><a href="https://github.com/ittraining2498#start-of-content"><strong>เปิดโปรไฟล์ IT Training · ไปที่ปุ่ม Follow ↑</strong></a><br><sub>ลิงก์นี้พาไปหน้าโปรไฟล์ ไม่ได้ติดตามอัตโนมัติ กรุณาลงชื่อเข้าใช้แล้วกด Follow ด้วยตนเอง</sub></p>
