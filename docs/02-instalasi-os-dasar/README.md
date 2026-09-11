# 02 — Instalasi OS & Setup Dasar (OS Install & Base Setup)

## Quick Start

1. **Download &amp; install [Raspberry Pi Imager](https://www.raspberrypi.com/software/)**
   (tersedia untuk Windows/macOS/Linux). Flash **Raspberry Pi OS**
   (64-bit, Lite atau Desktop — server tidak butuh desktop environment,
   tapi Desktop tidak masalah kalau Anda mau sekali-sekali pakai layar
   langsung) ke microSD lewat Imager ini.
2. Di Imager, sebelum flash, klik ⚙️ (Advanced Options) dan set:
   - Hostname (misal `myserver`)
   - **Enable SSH**, pakai password ATAU authorized key Anda
   - Username (jangan pakai default `pi` kalau mau sedikit lebih aman,
     tapi tutorial ini tetap pakai `pi` sebagai contoh)
   - Konfigurasi WiFi (opsional — server produksi sebaiknya kabel
     Ethernet, WiFi cuma untuk setup awal kalau perlu)
3. Boot dari SD card itu dulu (bukan NVMe — NVMe baru dipakai di
   Chapter 03). Cari IP-nya (`ping myserver.local` biasanya kerja lewat
   mDNS/Avahi), lalu SSH masuk.
4. **IP statis** — edit koneksi lewat `nmcli` (Raspberry Pi OS terbaru
   pakai NetworkManager, bukan `dhcpcd` lagi):

   ```bash
   sudo nmcli con mod "Wired connection 1" \
     ipv4.addresses 192.0.2.10/24 \
     ipv4.gateway 192.0.2.1 \
     ipv4.dns "192.0.2.1,1.1.1.1" \
     ipv4.method manual
   sudo nmcli con up "Wired connection 1"
   ```

   *(Ganti `192.0.2.10`/`192.0.2.1` dengan IP & gateway LAN Anda —
   `192.0.2.0/24` di sini cuma contoh placeholder standar dokumentasi,
   BUKAN rentang yang harus dipakai literal.)*

5. Update sistem, lalu firewall dasar:

   ```bash
   sudo apt update && sudo apt full-upgrade -y
   sudo apt install ufw fail2ban -y
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow 22/tcp        # SSH — akan diperketat lagi di Chapter 05
   sudo ufw enable
   ```

## Kenapa Begini

### Kenapa NetworkManager, bukan `/etc/dhcpcd.conf`?

Raspberry Pi OS versi baru (berbasis Debian 12/13) sudah pindah dari
`dhcpcd` ke **NetworkManager** sebagai pengelola jaringan default. Kalau
Anda menemukan tutorial lama yang menyuruh edit `/etc/dhcpcd.conf` untuk
IP statis, itu **tidak akan berpengaruh** di sistem yang sudah pindah ke
NetworkManager — file itu memang masih ada tapi tidak dibaca lagi.
Selalu cek dulu: `systemctl status NetworkManager` — kalau aktif, pakai
`nmcli`/file `.nmconnection` di `/etc/NetworkManager/system-connections/`,
bukan `dhcpcd.conf`.

### Kenapa IP statis penting untuk server (bukan cuma preferensi)

Kalau server Anda menjalankan banyak service yang saling merujuk
alamat spesifik (nginx bind ke IP tertentu, firewall rule berbasis IP,
config Tailscale/tunnel yang mengasumsikan alamat tetap), **DHCP yang
memberi IP berbeda setiap sekian waktu akan mematahkan semuanya diam-
diam**. Ini bukan skenario teoretis — router yang restart, lease
kadaluarsa, atau konflik MAC address bisa membuat server dapat IP baru
tanpa peringatan apa pun, dan semua service yang hardcode IP lama jadi
tidak terjangkau. IP statis di level OS + **reservasi DHCP di router**
(dua lapis, saling menjaga) adalah kombinasi paling aman.

### Kenapa firewall "default deny" sejak awal, bukan nanti

Prinsip paling penting dalam mengamankan server: **whitelist, bukan
blacklist**. Mulai dengan menutup SEMUA port masuk, lalu buka satu per
satu sesuai kebutuhan nyata — bukan sebaliknya (buka semua, lalu coba
ingat-ingat menutup yang tidak perlu). Kalau Anda menunda setup firewall
sampai "nanti setelah semua service jalan", risikonya Anda lupa satu
service yang ternyata sudah terekspos ke publik tanpa sengaja sejak
awal.

### Soal password vs SSH key — kejujuran trade-off

Idealnya, disable password login sepenuhnya dan pakai SSH key saja
(`PasswordAuthentication no` di `/etc/ssh/sshd_config`). Tapi ini
tutorial jujur: server nyata di balik tutorial ini **masih mengizinkan
kombinasi password + key** karena kebutuhan akses dari berbagai
perangkat. Kompensasinya: `fail2ban` (di-install sejak awal di atas,
detail konfigurasi di Chapter 12) yang otomatis mem-blokir IP setelah
beberapa kali gagal login. Kalau Anda tidak punya kebutuhan akses
multi-device yang sama, **disable password auth sepenuhnya** adalah
pilihan yang lebih aman — jangan ikuti kompromi kami kalau Anda tidak
butuh.

### User non-root

Jangan pernah menjalankan aplikasi/service sebagai `root` kalau tidak
perlu. Buat user biasa (di tutorial ini: `pi`, sesuai default Raspberry
Pi Imager) dan gunakan `sudo` untuk operasi yang benar-benar butuh akses
root — dan idealnya scoped ke command spesifik lewat
`/etc/sudoers.d/`, bukan `NOPASSWD: ALL` (lebih banyak soal ini di
Chapter 12 &amp; 13, terutama kalau Anda menjalankan automasi/cron yang
butuh sudo tanpa TTY interaktif).

## Checklist sebelum lanjut

- [ ] OS terinstall, bisa SSH masuk
- [ ] IP statis terkonfirmasi (`ip a` menunjukkan IP yang Anda set,
      tetap sama setelah reboot)
- [ ] `apt full-upgrade` sudah jalan, sistem versi terbaru
- [ ] UFW aktif dengan default deny incoming + allow SSH
- [ ] fail2ban terinstall (konfigurasi detail menyusul Chapter 12)

## Lanjut ke

➡️ [Chapter 03 — Storage & Reliabilitas NVMe](../03-storage-nvme-reliability/) — **bab paling penting di seluruh tutorial ini, jangan skip**

⬅️ [Chapter 01 — Hardware & Persiapan](../01-hardware-persiapan/)
