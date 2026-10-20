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
| [`linux/bulk-delete-users.sh`](linux/bulk-delete-users.sh) | Linux | Thai menu or CLI to delete user accounts — dry-run first, backs up each home directory, refuses system accounts |
| [`linux/bulk-create-users.sh`](linux/bulk-create-users.sh) | Linux | Validate quoted CSV and groups before creating users; save passwords to a new mode-600 file |
| [`linux/check-disk.sh`](linux/check-disk.sh) | Linux | Check space/inodes; exit 1 for thresholds and 2 for failed collection or invalid options |
| [`proxmox/cluster-health.sh`](proxmox/cluster-health.sh) | Proxmox VE | Quorum, services, storage and guests; failed checks return non-zero, never a false healthy result |
| [`linux/system-info.sh`](linux/system-info.sh) | Linux | Thai read-only menu for OS, CPU, uptime, RAM/swap and disk; no sudo required |

## Beginner guide

Read the [step-by-step guide](https://ittraining2498.github.io/linux-sysadmin-scripts/#user-guide) for download/save instructions, choosing usernames, preparing CSV, previewing changes, interpreting results, and common errors. It is available in Thai, English and Lao.

Running the deletion script without arguments in a terminal opens a Thai menu. Choose a numbered account, review a dry-run, and type the exact login name to confirm. Only then does the menu invoke the existing --apply path. Non-interactive calls without arguments still exit 2; existing CLI usage is unchanged. --menu explicitly requests a terminal menu and cannot be combined with other arguments.

Create a file in a Linux terminal with `nano bulk-delete-users.sh`, paste the full source, save with Ctrl+O then Enter, and exit with Ctrl+X. Check with `bash -n bulk-delete-users.sh`, then run `chmod 700 bulk-delete-users.sh` and `sudo ./bulk-delete-users.sh`. The web guide explains each step.

### Thai menus for every script

In a terminal, run any script without arguments (or with `--menu` alone). CLI options continue to work for automation. Creation offers a single-user form or CSV input, previews a private snapshot of the input and asks for explicit confirmation before invoking `--apply`. Monitoring asks for a threshold and preserves the underlying exit code.

| File to create | Permission | Start menu |
|---|---|---|
| `nano bulk-create-users.sh` | `chmod 700 bulk-create-users.sh` | `sudo ./bulk-create-users.sh` |
| `nano check-disk.sh` | `chmod 700 check-disk.sh` | `./check-disk.sh` |
| `nano cluster-health.sh` | `chmod 700 cluster-health.sh` | `sudo ./cluster-health.sh` on the Proxmox host |

Paste the matching full script, save with Ctrl+O then Enter, exit with Ctrl+X, and run `bash -n FILENAME` before granting permission. Omit sudo in a root shell. Python 3 is required for creation. Full menu instructions are in the web guide.

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

- **Dry-run is the default.** Destructive scripts do nothing until `--apply` is supplied. The Thai menu supplies it only after a preview and exact-name confirmation.
- **System accounts are protected.** Anything below UID 1000, and a hard-coded list of
  system users, is always skipped.
- **Backup before destroy.** Home directories are archived to `/var/backups/` first.
- **Account changes are logged** to `/var/log/`, with timestamps. Preview and monitoring output go to the terminal.
- **Useful exit codes.** `0` means healthy or successful, non-zero means something needs
  attention — so these scripts work inside cron, Ansible and monitoring checks.

## Testing status

| Script | Tested on |
|---|---|
| `linux/bulk-delete-users.sh` | Ubuntu 24.04 container, 2026-10-20 — real Thai terminal menu, cancellation, exact-name confirmation, deletion, backup content, protected UIDs and unsafe-home checks |
| `linux/bulk-create-users.sh` | Ubuntu 24.04 container, 2026-10-20 — Thai single-user/CSV menu, real account creation, quoted CSV/BOM/CRLF, groups, password expiry and output permissions |
| `linux/check-disk.sh` | Ubuntu 24.04 container, 2026-10-20 — Thai menu, real block/inode checks; simulated df failure must return 2 |
| `proxmox/cluster-health.sh` | Ubuntu 24.04 container with simulated Proxmox commands, 2026-10-20 — Thai menu and quorum/storage/guest failure paths; **not tested on a real Proxmox node or cluster** |
| `linux/system-info.sh` | Ubuntu 24.04 container, 2026-10-20 — CLI, Thai menu, non-root execution and failed collection; container values may reflect the host |

CI runs ShellCheck, `bash -n`, and isolated Ubuntu container regression checks on every push and pull request. Proxmox command fixtures are not a substitute for a real-cluster test.

Latest local run (2026-10-20): **137 checks passed** in an Ubuntu 24.04 container. Real terminal tests cover all five Thai menus, cancellation/EOF, invalid choices, new accounts from typed input and CSV, password-file permissions and overwrite refusal, disk thresholds and collection failure, and Proxmox fixture success/failure. Account creation/deletion and backup-content checks use real Linux accounts. **Proxmox remains fixture-only, not a real-node test.**

Actual test output:

```text
PASS single user Thai menu exit=0
PASS CSV menu create exit=0
PASS disk menu healthy exit=0
PASS disk menu alert exit=1
PASS Proxmox menu healthy fixture exit=0
PASS Proxmox menu failed fixture exit=1
TOTAL: 137 checks passed; real Linux account operations, Proxmox command fixtures only.
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

### คู่มือสำหรับผู้เริ่มต้น

อ่าน [คู่มือทีละขั้น](https://ittraining2498.github.io/linux-sysadmin-scripts/#user-guide) ก่อนใช้ มีวิธีบันทึกไฟล์ หาชื่อบัญชี เตรียม CSV ทดลองก่อนทำจริง และแปลผลลัพธ์ครบทั้งสี่สคริปต์

### สร้างไฟล์ → กำหนดสิทธิ์ → รันเมนูภาษาไทย

1. เปิด Terminal บน Linux แล้วใช้ `nano bulk-delete-users.sh`
2. คัดลอก **สคริปต์เต็ม** จากหน้าเว็บมาวาง บรรทัดแรกต้องเป็น `#!/usr/bin/env bash`
3. บันทึกด้วย Ctrl+O แล้ว Enter จากนั้น Ctrl+X เพื่อออก
4. ตรวจไฟล์ด้วย `bash -n bulk-delete-users.sh` ถ้ามี error ให้แก้ก่อนทำต่อ
5. กำหนดสิทธิ์ด้วย `chmod 700 bulk-delete-users.sh`
6. เปิดเมนูด้วย `sudo ./bulk-delete-users.sh` ใส่รหัส sudo หากระบบถาม
7. เลือก 2 แล้วเลือกหมายเลขบัญชี เลือกเก็บหรือลบโฟลเดอร์ ตรวจผลทดลอง และพิมพ์ชื่อบัญชีให้ตรงเพื่อยืนยัน หรือกด Enter เพื่อยกเลิก

ตัวอย่างบัญชี `panya`: เลือกหมายเลขที่อยู่ข้าง panya แล้วพิมพ์ `panya` ที่คำถามยืนยันสุดท้าย เฉพาะเมื่อตั้งใจลบบัญชีนั้นจริง เมนูเรียก `--apply` ให้หลังยืนยัน ไม่ต้องจำตัวเลือกเอง การเปิดเมนูยังไม่เปลี่ยนข้อมูล

หากบันทึกชื่อ `test.sh` ให้เปลี่ยนชื่อไฟล์ในคำสั่งทั้งหมดเป็น `test.sh` สคริปต์ที่เหลือมีเมนูภาษาไทยเช่นกัน เมนูซ่อนบัญชีระบบ บัญชีผู้เรียกผ่าน sudo บัญชีที่ไม่มี login shell และผู้ล็อกอินตามรายงาน who แต่ยังต้องตรวจหน้าที่ของบัญชีก่อนลบ เพราะไม่ครอบคลุมทุกบริการเบื้องหลัง

### เมนูของสคริปต์ที่เหลือ

สร้างไฟล์ด้วย nano ตามชื่อสคริปต์ วางโค้ดเต็ม บันทึก Ctrl+O → Enter → Ctrl+X แล้วตรวจด้วย `bash -n ชื่อไฟล์` เมื่อไม่มี error ให้ `chmod 700 ชื่อไฟล์` ก่อนรัน

- สร้างผู้ใช้: `sudo ./bulk-create-users.sh` เลือกกรอกทีละคนหรือ CSV ตรวจแผน เลือกไฟล์รหัสผ่านใหม่ แล้วพิมพ์ `สร้าง` เพื่อยืนยัน
- ตรวจดิสก์: `./check-disk.sh` เลือกตรวจพื้นที่หรือ inode เพิ่ม แล้วใส่เปอร์เซ็นต์ กด Enter ใช้ 85
- Proxmox: `sudo ./cluster-health.sh` บนโฮสต์ Proxmox VE เลือกรายงานทั้งหมดหรือเฉพาะปัญหา ใส่เปอร์เซ็นต์ หากเป็น root ไม่ต้อง sudo ยังทดสอบด้วยคำสั่งจำลองเท่านั้น
- เลือก 0 เพื่อออก เมนูสร้างผู้ใช้ยกเลิกได้ที่คำถามยืนยันโดยกด Enter ห้ามนำไฟล์รหัสผ่านขึ้น GitHub

### สคริปต์ใหม่: ดูข้อมูลเครื่อง Linux

`linux/system-info.sh` อ่านข้อมูลอย่างเดียว ไม่ต้อง sudo เลือกดูภาพรวม ระบบปฏิบัติการ CPU เวลาทำงาน RAM/swap หรือดิสก์ได้ ไม่ตัดสินสุขภาพระบบและไม่แก้ข้อมูล

สร้างด้วย `nano system-info.sh` วางโค้ดเต็ม บันทึก Ctrl+O → Enter → Ctrl+X ตรวจ `bash -n system-info.sh` แล้ว `chmod 700 system-info.sh` และ `./system-info.sh` เพื่อเปิดเมนู รายงานแบบไม่เปิดเมนูใช้ `./system-info.sh --all`
