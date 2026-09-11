# 11 — Strategi Backup Berlapis (4-Layer Backup Strategy)

## Quick Start

Empat lapis backup, jadwal cron berbeda supaya tidak saling bebani I/O
di waktu yang sama:

| Lapis | Isi | Jadwal | Retensi |
|---|---|---|---|
| **1. Database** | Semua database bisnis (auto-discovery, lihat Chapter 04) | 02:00 harian | 7 hari |
| **2. Kode/Proyek** | Kode aplikasi + `.env` + docs (self-contained per proyek) | 02:30 harian | 14 hari |
| **3. Memory/State AI Assistant** | Kalau Anda pakai AI assistant persisten untuk maintenance | 03:00 harian | 14 hari |
| **4. State Sistem** *(paling sering dilupakan)* | Crontab semua user, dpkg selections, config `/etc` kritis, unit systemd custom | 02:45 harian | 30 hari |

Contoh script lapis 4 (`scripts/system-backup.sh.example`):

```bash
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEST="/home/<user>/Backup/system"
TMP=$(mktemp -d)
mkdir -p "$DEST"

# Crontab semua user
mkdir -p "$TMP/crontabs"
for user in pi root www-data; do
  crontab -u "$user" -l > "$TMP/crontabs/${user}.txt" 2>/dev/null
done

# Paket & status dpkg
dpkg --get-selections > "$TMP/dpkg-selections.txt"
apt-mark showhold > "$TMP/apt-hold.txt"

# Config /etc kritis
mkdir -p "$TMP/etc"
cp /etc/hosts /etc/fstab /etc/modules "$TMP/etc/" 2>/dev/null
cp -r /etc/NetworkManager/system-connections "$TMP/etc/" 2>/dev/null

# Unit systemd custom (bukan bawaan paket)
mkdir -p "$TMP/systemd"
cp /etc/systemd/system/*.service /etc/systemd/system/*.timer "$TMP/systemd/" 2>/dev/null

tar -czf "$DEST/system-backup_${TIMESTAMP}.tar.gz" -C "$TMP" .
rm -rf "$TMP"

find "$DEST" -name "*.tar.gz" -mtime +30 -delete
```

## Kenapa Begini

### Kenapa 4 lapis, bukan 1 backup besar untuk semuanya

Tiap lapis punya karakteristik pemulihan yang berbeda: database perlu
konsistensi transaksional (`--single-transaction`), kode punya git
sebagai lapisan pertama (backup file cuma jaring pengaman tambahan),
state sistem nyaris tidak pernah berubah (jadi retensi lebih panjang
masuk akal), dan kalau Anda pakai AI assistant persisten untuk
maintenance server, "memori"-nya sendiri adalah aset yang perlu
dilindungi terpisah dari kode/data bisnis. Memisahkan jadwal &amp;
retensi per lapis membuat tiap lapis bisa dioptimalkan sendiri, dan
kalau satu lapis gagal, lapis lain tidak ikut terdampak.

### Kenapa lapis "state sistem" ada — dan kenapa ini yang paling sering dilupakan

Ini pelajaran paling mahal dari pengalaman nyata. Kebanyakan orang
(termasuk yang sudah cukup berpengalaman) berpikir backup itu = backup
database + backup kode. Tapi ada kategori ketiga yang nyaris selalu
terlewat: **state konfigurasi sistem operasi itu sendiri** —

- **Crontab** semua user. Kalau hilang, semua automasi (backup lain,
  monitoring, maintenance) berhenti **tanpa ada satu pun pesan error
  yang jelas** — Anda baru sadar berhari-hari kemudian lewat gejala
  tidak langsung (bot berhenti kirim pesan, backup database sendiri
  berhenti jalan, situs mulai error karena scheduled task aplikasi
  tidak jalan).
- **Metadata dpkg** (`dpkg --get-selections`, status paket ter-hold) —
  kalau korup, sistem paket bisa "lupa" apa saja yang seharusnya
  terinstall, membuat `apt` berperilaku aneh tanpa pesan error yang
  jelas menunjuk akar masalahnya.
- **Config `/etc` kritis** — profil jaringan (`NetworkManager`), unit
  systemd custom yang Anda buat sendiri (bukan bawaan paket), file
  seperti `/etc/fstab`/`/etc/modules`.

Kerusakan filesystem tingkat rendah (misalnya dari mati listrik yang
menginterupsi proses `fsck` — kasus nyata dibahas lengkap di
[Chapter 99](../99-studi-kasus-insiden/)) bisa menghapus atau mengacak
APA PUN, termasuk kategori "boring" seperti ini yang tidak pernah
terpikir perlu di-backup karena "kan sudah ada dari awal, tidak
mungkin hilang". Sampai suatu hari memang hilang.

### Aturan retensi: kenapa harus otomatis, dan kenapa harus diberi tanggal

Backup yang menumpuk tanpa batas akan menghabiskan disk cepat atau
lambat — `find ... -mtime +N -delete` di akhir tiap script (seperti
contoh di atas) memastikan backup lama otomatis terhapus tanpa
intervensi manual.

Tapi untuk **backup manual** (yang Anda buat sendiri sesaat sebelum
melakukan perubahan berisiko — misalnya sebelum migrasi database besar,
sebelum ubah config produksi), jangan andalkan skrip retensi otomatis.
Beri **penanda tanggal boleh-hapus eksplisit**, misalnya file
`namafile.bak-20260911.NOTE` berisi `BOLEH DIHAPUS SETELAH 2026-10-11`.
Ini mencegah dua kegagalan berlawanan: backup manual terhapus otomatis
sebelum Anda yakin perubahan aman (kalau ikut skrip retensi umum), ATAU
backup manual menumpuk selamanya karena tidak ada yang pernah eksplisit
memutuskan kapan aman dihapus.

### Kenapa lapis "memory AI assistant" masuk sebagai kategori sendiri

Kalau Anda menggunakan asisten AI (seperti Claude Code atau sejenisnya)
sebagai bagian dari cara Anda mengelola &amp; melakukan maintenance
server — dengan asisten itu menyimpan "memori" persisten (preferensi
Anda, konteks proyek, pelajaran dari insiden masa lalu) di luar sesi
chat biasa — **memori itu sendiri adalah aset kerja yang bernilai**,
bukan cuma cache yang bisa dibangun ulang. Kehilangannya berarti mulai
dari nol lagi setiap kali menjelaskan konteks server Anda ke asisten
yang sama. Detail lebih lanjut soal pola kerja ini ada di
[Chapter 13 — Operasional &amp; Dokumentasi](../13-operasional-dokumentasi-ai-assisted/).

### Verifikasi backup — jangan cuma percaya "backup selesai" di log

Backup yang "berhasil" menurut log (`Backup OK`) belum tentu benar-
benar bisa dipulihkan. Lakukan **uji restore berkala** (setidaknya
sesekali, tidak perlu tiap hari) ke lingkungan terpisah/sementara,
untuk memverifikasi file backup benar-benar valid dan lengkap — bukan
cuma percaya proses backup "selesai tanpa error" sebagai bukti cukup.

## Checklist sebelum lanjut

- [ ] Keempat lapis backup berjalan lewat cron dengan jadwal berbeda
      (tidak numpuk di jam yang sama)
- [ ] Retensi otomatis terpasang di tiap lapis, terbukti bekerja (cek
      folder backup tidak terus membesar tanpa batas)
- [ ] Backup manual (sebelum perubahan berisiko) selalu diberi penanda
      tanggal boleh-hapus eksplisit
- [ ] Minimal pernah sekali uji restore dari salah satu lapis, untuk
      memverifikasi file backup benar-benar valid

## Lanjut ke

➡️ [Chapter 12 — Keamanan Lanjutan](../12-keamanan-lanjutan/)

⬅️ [Chapter 10 — AI Lokal (Ollama)](../10-ai-lokal-ollama/)
