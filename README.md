# linux-sysadmin-scripts

Practical, production-minded scripts for people who actually run servers — Linux, Windows Server and Proxmox.

Every script here is used in real administration work and in the courses taught at
[IT Training](https://www.ittraining.co.th). They are written to be **safe by default**:
dry-run first, protected system accounts, backups before destructive actions, and a log of what happened.

**Browse them on the web:** https://ittraining2498.github.io/linux-sysadmin-scripts/

## Scripts

| Script | Platform | What it does |
|---|---|---|
| [`linux/bulk-delete-users.sh`](linux/bulk-delete-users.sh) | Linux | Delete many user accounts in one run — dry-run by default, backs up each home directory, refuses system accounts |
| [`linux/bulk-create-users.sh`](linux/bulk-create-users.sh) | Linux | Create users from a CSV file with generated passwords and forced change at first login |
| [`linux/check-disk.sh`](linux/check-disk.sh) | Linux | Report filesystems (and optionally inodes) above a usage threshold; exits non-zero so cron can act on it |
| [`proxmox/cluster-health.sh`](proxmox/cluster-health.sh) | Proxmox VE | Quorum, services, storage and guest overview for a node or cluster |

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
sudo ./linux/bulk-delete-users.sh -f leavers.txt --apply

# 3. delete and remove home directories too
sudo ./linux/bulk-delete-users.sh -f leavers.txt --apply --remove-home
```

### Example — onboarding from a CSV

`staff.csv`:

```csv
username,full name,groups
somchai,Somchai Jaidee,"sudo,docker"
somsri,Somsri Rakdee,
```

```bash
sudo ./linux/bulk-create-users.sh -f staff.csv           # preview
sudo ./linux/bulk-create-users.sh -f staff.csv --apply   # create
```

## Safety rules used throughout

- **Dry-run is the default.** Destructive scripts do nothing until you pass `--apply`.
- **System accounts are protected.** Anything below UID 1000, and a hard-coded list of
  system users, is always skipped.
- **Backup before destroy.** Home directories are archived to `/var/backups/` first.
- **Everything is logged** to `/var/log/`, with timestamps.
- **Useful exit codes.** `0` means healthy or successful, non-zero means something needs
  attention — so these scripts work inside cron, Ansible and monitoring checks.

## Testing status

| Script | Tested on |
|---|---|
| `linux/bulk-delete-users.sh` | Debian-family Linux — create, delete, backup and skip paths verified |
| `linux/bulk-create-users.sh` | Debian-family Linux — create, re-run/skip and password expiry verified |
| `linux/check-disk.sh` | Debian-family Linux — block and inode thresholds verified |
| `proxmox/cluster-health.sh` | Not yet verified on a live cluster — please report results |

CI runs ShellCheck and `bash -n` on every push and pull request.

## Contributing

Issues and pull requests are welcome — bug reports, support for other distributions,
or new scripts. Please keep the safety rules above intact, and make sure
`shellcheck --severity=warning` passes.

## License

[MIT](LICENSE) — free to use, modify and redistribute, including commercially.
Provided as is, without warranty. Test in a lab before running on production systems.

---

**คำอธิบายภาษาไทย**

รวมสคริปต์สำหรับผู้ดูแลระบบเซิร์ฟเวอร์ ใช้งานได้จริง ไม่ใช่ตัวอย่างสำหรับสาธิต
ทุกตัวออกแบบให้ปลอดภัยไว้ก่อน — รันครั้งแรกจะเป็น dry-run แสดงผลให้ดูเฉย ๆ
ต้องใส่ `--apply` เองถึงจะทำงานจริง และสำรองข้อมูลก่อนลบเสมอ

ดูรายการสคริปต์แบบหน้าเว็บได้ที่ https://ittraining2498.github.io/linux-sysadmin-scripts/

เนื้อหาส่วนหนึ่งมาจากคอร์สอบรมของ [ไอทีเทรนนิ่ง](https://www.ittraining.co.th) — LINE: `@linux`
