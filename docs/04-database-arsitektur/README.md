# 04 — Database Arsitektur (Database Architecture)

## Quick Start

**1. Install MariaDB, satu instance untuk semua aplikasi:**

```bash
sudo apt install mariadb-server -y
sudo mysql_secure_installation
```

**2. Buat database per aplikasi** (jangan campur banyak aplikasi dalam
satu database, meski satu instance server dipakai bersama):

```sql
CREATE DATABASE app_a CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE app_b CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER 'app_a_user'@'localhost' IDENTIFIED BY '<PASSWORD_KUAT_ANDA>';
GRANT ALL PRIVILEGES ON app_a.* TO 'app_a_user'@'localhost';
FLUSH PRIVILEGES;
```

**3. Buat user khusus backup, read-only, scoped per-database:**

```sql
CREATE USER 'backup'@'localhost' IDENTIFIED BY '<PASSWORD_BACKUP_ANDA>';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON app_a.* TO 'backup'@'localhost';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON app_b.* TO 'backup'@'localhost';
FLUSH PRIVILEGES;
```

**4. Pastikan data MariaDB memang di NVMe** (bukan SD card):

```bash
sudo mysql -e "SELECT @@datadir;"
# Harus menunjuk ke path di partisi NVMe Anda, biasanya /var/lib/mysql
```

## Kenapa Begini

### Kenapa 1 instance, banyak database — bukan 1 instance per aplikasi

Menjalankan MariaDB terpisah per aplikasi (misal lewat container
terpisah-terpisah) terdengar lebih "bersih" secara isolasi, tapi di
Raspberry Pi dengan RAM terbatas, **setiap instance MariaDB punya
overhead memori tetap** (buffer pool, connection handler, dll) terlepas
dari seberapa kecil database-nya. Beberapa instance kecil-kecil akan
menghabiskan RAM jauh lebih banyak dibanding satu instance besar yang
melayani semua — RAM itulah resource paling langka di server kelas
Raspberry Pi, apalagi kalau Anda juga menjalankan Docker (Chapter 07)
dan AI lokal (Chapter 10) sekaligus.

Isolasi tetap didapat lewat: database terpisah per aplikasi + user
MySQL terpisah per aplikasi dengan privilege dibatasi hanya ke
database miliknya sendiri (`GRANT ALL ... ON app_a.*`, bukan `ON *.*`).
Kalau satu aplikasi ter-compromise, dampaknya tidak otomatis menyebar
ke database aplikasi lain.

### Kenapa user backup terpisah, dan kenapa privilegenya sesempit itu

Prinsip **least privilege**: user yang menjalankan backup otomatis
TIDAK PERNAH butuh kemampuan menulis/menghapus data. Kalau script
backup Anda (atau kredensialnya) suatu saat bocor/ter-compromise,
attacker yang dapat akses lewat user `backup` **tidak bisa mengubah
apa pun** — cuma bisa membaca, yang memang tujuannya.

Kelima privilege yang di-grant punya alasan spesifik:
- `SELECT` — baca data (jelas, ini intinya).
- `LOCK TABLES` — dibutuhkan `mysqldump` untuk memastikan snapshot
  konsisten selama proses dump (mencegah data berubah di tengah-tengah
  proses backup).
- `SHOW VIEW` — supaya view (bukan cuma tabel fisik) ikut ter-backup
  dengan benar strukturnya.
- `EVENT`, `TRIGGER` — supaya scheduled event &amp; trigger MySQL
  (kalau ada) ikut tercakup di dump, bukan cuma data mentah.

### Auto-discovery backup — dan jebakan yang WAJIB diketahui

Alih-alih menulis daftar nama database secara hardcode di script
backup, pendekatan yang jauh lebih tahan-lupa adalah **auto-discovery**:
script backup query `information_schema` (atau `SHOW DATABASES`) lewat
user `backup`, lalu backup APAPUN yang muncul di hasil itu. Keuntungannya:
tambah database baru = otomatis ter-backup, tidak perlu edit script.

**Tapi ada jebakan besar**: karena ini auto-discovery lewat privilege
user `backup`, **database yang belum di-grant ke user `backup` tidak
akan pernah muncul di hasil query** — dan karena itu **tidak akan
pernah di-backup, TANPA ERROR yang terlihat sama sekali**. Script akan
terus melaporkan "backup OK" setiap hari (karena secara teknis semua
yang ia LIHAT memang berhasil di-backup) sementara database baru Anda
diam-diam tidak pernah tersentuh.

**Aturan wajib**: setiap kali membuat database baru untuk aplikasi baru,
**grant ke user `backup` di hari yang sama**, sebagai bagian dari
langkah setup, bukan langkah terpisah yang mudah terlupakan. Contoh
skrip backup sederhana:

```bash
#!/bin/bash
# scripts/backup-db.sh.example
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/<user>/Backup/database"
RETENTION_DAYS=7

DBS=$(mysql -u backup -p"<PASSWORD>" -N -e "SHOW DATABASES;" \
  | grep -vE "^(information_schema|performance_schema|mysql|sys)$")

for db in $DBS; do
  mysqldump -u backup -p"<PASSWORD>" --single-transaction "$db" \
    | gzip > "$BACKUP_DIR/${db}_${TIMESTAMP}.sql.gz"
done

find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
```

*(Template placeholder — ganti password dengan cara aman, misal baca
dari file `.my.cnf` bukan hardcode di script. Detail strategi retensi
&amp; lapisan backup lain di Chapter 11.)*

### Kenapa lokasi data harus dipastikan di NVMe

Ini terdengar sepele tapi pernah jadi sumber kebingungan nyata: kalau
Anda instalasi awal di SD card lalu pindah root filesystem ke NVMe
(pola umum di Raspberry Pi), **pastikan ulang** `datadir` MariaDB
benar-benar menunjuk ke path di NVMe, bukan sisa mount point lama.
Database yang tanpa sadar masih di SD card akan jauh lebih lambat
(I/O SD card jauh di bawah NVMe) dan lebih rentan rusak di bawah beban
tulis berkelanjutan (SD card tidak dirancang untuk itu).

## Checklist sebelum lanjut

- [ ] MariaDB terinstall, `datadir` terkonfirmasi di NVMe
- [ ] Setiap aplikasi punya database &amp; user MySQL sendiri (tidak
      dicampur, tidak pakai user `root` MySQL untuk aplikasi)
- [ ] User `backup` dibuat, privilege read-only, sudah di-grant ke
      SEMUA database yang ada saat ini
- [ ] Anda paham aturan "grant backup user di hari yang sama saat buat
      DB baru" — ini yang paling sering terlupakan

## Lanjut ke

➡️ [Chapter 05 — Remote Access: Tailscale](../05-remote-access-tailscale/)

⬅️ [Chapter 03 — Storage &amp; Reliabilitas NVMe](../03-storage-nvme-reliability/)
