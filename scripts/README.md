# Scripts

## Setup cepat

```bash
chmod +x quickstart.sh
./quickstart.sh
```

`quickstart.sh` menginstal SEMUA paket/tool yang dibahas di tutorial ini
(UFW, fail2ban, MariaDB, Tailscale, nginx, cloudflared, Docker, I2C
tools, Ollama, rkhunter, ClamAV, debsums) dalam satu jalan, aman
dijalankan berulang kali (idempotent).

**Yang SENGAJA tidak diotomatiskan oleh script ini** — dan Anda WAJIB
kerjakan manual setelahnya, sesuai urutan yang ditampilkan script di
akhir eksekusi:

1. **Konfigurasi NVMe/HMB** ([Chapter 03](../docs/03-storage-nvme-reliability/))
   — paling penting, WAJIB dicek manual per hardware. Script ini
   **tidak menyentuh** `/boot/firmware/*` sama sekali.
2. Aturan &amp; enable UFW spesifik kebutuhan Anda.
3. Pembuatan database/user MySQL per aplikasi.
4. Login Tailscale (`sudo tailscale up`).
5. Token Cloudflare Tunnel dari dashboard mereka.
6. Config nginx &amp; `docker-compose.yml` per aplikasi.
7. Isi token bot Telegram.
8. Verifikasi nyata fail2ban (tes ban IP dummy, bukan cuma baca config).

## File contoh (`*.example`)

Semua file `*.example` di folder ini adalah **template**, bukan file
yang langsung jalan — copy dulu tanpa suffix `.example`, isi semua
`<PLACEHOLDER>`, baru dipakai:

```bash
cp backup-db.sh.example backup-db.sh
nano backup-db.sh   # isi password, path, dll
chmod +x backup-db.sh
```

| File | Referensi chapter | Fungsi |
|---|---|---|
| `backup-db.sh.example` | [04](../docs/04-database-arsitektur/) | Backup semua database (auto-discovery) |
| `system-backup.sh.example` | [11](../docs/11-backup-strategi-4-lapis/) | Backup crontab/dpkg/config `/etc` kritis |
| `telegram-notify.sh.example` | [09](../docs/09-monitoring-alert-telegram/) | Fungsi kirim pesan Telegram (dipakai `health-check.sh.example`) |
| `health-check.sh.example` | [09](../docs/09-monitoring-alert-telegram/) | Monitoring + alert-hanya-saat-berubah |
| `oled-status.py.example` | [08](../docs/08-lcd-oled-status-display/) | Tampilkan status di layar OLED I2C |

**Jangan pernah commit versi tanpa `.example` (yang sudah Anda isi
password/token asli) ke git** — `.gitignore` di root repo ini sudah
mengecualikan `*.env`, tapi file `.sh`/`.py` yang Anda isi manual
TIDAK otomatis ter-exclude. Simpan kredensial di file `.env`/`.my.cnf`
terpisah yang di-`source`, jangan hardcode di script itu sendiri kalau
bisa dihindari.

⬅️ [Kembali ke daftar isi](../README.md)
