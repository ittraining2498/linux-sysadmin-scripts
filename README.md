# linux-sysadmin-scripts

Practical, production-minded scripts for people who actually run servers — Linux, Windows Server and Proxmox.

Every script here is used in real administration work and in the courses taught at
[IT Training](https://www.ittraining.co.th). They are written to be **safe by default**:
dry-run first, protected system accounts, backups before destructive actions, and a log of what happened.

## Scripts

| Script | Platform | What it does |
|---|---|---|
| [`linux/bulk-delete-users.sh`](linux/bulk-delete-users.sh) | Linux | Delete many user accounts in one run — dry-run by default, backs up each home directory, refuses system accounts |

## Usage

```bash
git clone https://github.com/ittraining2498/linux-sysadmin-scripts.git
cd linux-sysadmin-scripts
chmod +x linux/*.sh
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

## Safety rules used throughout

- **Dry-run is the default.** Destructive scripts do nothing until you pass `--apply`.
- **System accounts are protected.** Anything below UID 1000, and a hard-coded list of
  system users, is always skipped.
- **Backup before destroy.** Home directories are archived to `/var/backups/` first.
- **Everything is logged** to `/var/log/`, with timestamps.

## Contributing

Issues and pull requests are welcome — bug reports, support for other distributions,
or new scripts. Please keep the safety rules above intact.

## License

[MIT](LICENSE) — free to use, modify and redistribute, including commercially.
Provided as is, without warranty. Test in a lab before running on production systems.

---

**คำอธิบายภาษาไทย**

รวมสคริปต์สำหรับผู้ดูแลระบบเซิร์ฟเวอร์ ใช้งานได้จริง ไม่ใช่ตัวอย่างสำหรับสาธิต
ทุกตัวออกแบบให้ปลอดภัยไว้ก่อน — รันครั้งแรกจะเป็น dry-run แสดงผลให้ดูเฉย ๆ
ต้องใส่ `--apply` เองถึงจะทำงานจริง และสำรองข้อมูลก่อนลบเสมอ

เนื้อหาส่วนหนึ่งมาจากคอร์สอบรมของ [ไอทีเทรนนิ่ง](https://www.ittraining.co.th) — LINE: `@linux`
