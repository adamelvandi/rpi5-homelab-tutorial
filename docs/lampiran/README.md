# Lampiran — Glossary, Cheat-sheet, FAQ

## Daftar Isi Lampiran

1. [Glossary](#glossary) — istilah teknis dijelaskan untuk pembaca awam
2. [Troubleshooting Cheat-sheet](#troubleshooting-cheat-sheet) — gejala → kemungkinan sebab → command cek
3. [FAQ](#faq)
4. [Daftar Bacaan Lanjutan](#daftar-bacaan-lanjutan)

---

## Glossary

Istilah diurutkan sesuai kemunculan pertamanya di tutorial, bukan
alfabetis — supaya kalau Anda baru selesai baca satu chapter dan lupa
satu istilah, biasanya ada di sekitar posisi yang sama di sini.

| Istilah | Penjelasan sederhana |
|---|---|
| **IP statis** | Alamat jaringan yang tidak pernah berubah untuk perangkat tertentu, lawan dari IP yang dibagikan otomatis (DHCP) dan bisa berubah sewaktu-waktu. |
| **UFW** | *Uncomplicated Firewall* — alat pengatur firewall Linux yang menyederhanakan aturan `iptables`/`nftables` di baliknya. |
| **fail2ban** | Program yang memantau log (misal log gagal login SSH) dan otomatis memblokir alamat IP yang terlalu sering gagal — pertahanan dasar melawan brute-force. |
| **DRAM-less SSD** | SSD tanpa chip RAM sendiri untuk menyimpan tabel pemetaan datanya, sehingga meminjam RAM dari sistem host (lihat HMB). Lebih murah, tapi butuh dukungan software yang tepat supaya tidak lambat/rentan. |
| **HMB (Host Memory Buffer)** | Fitur yang mengizinkan SSD DRAM-less "meminjam" sepotong RAM dari komputer/perangkat host. Kalau tidak aktif, SSD jenis ini bisa jadi sangat lambat atau bahkan menyebabkan sistem freeze di bawah beban tulis berat. |
| **FTL (Flash Translation Layer)** | Tabel internal SSD yang mencatat lokasi fisik sebenarnya dari tiap data yang Anda simpan — lapisan penerjemah antara "alamat logis" yang dilihat sistem operasi dan lokasi fisik nyata di chip NAND flash. |
| **PCIe ASPM** | *Active State Power Management* — fitur hemat daya jalur PCIe yang mengistirahatkan koneksi saat idle. Kadang perlu dimatikan (`pcie_aspm=off`) demi stabilitas, dengan trade-off konsumsi daya sedikit lebih tinggi. |
| **ext4 journal** | Catatan perubahan filesystem yang disimpan sebelum benar-benar dieksekusi, supaya sistem bisa pulih ke kondisi konsisten kalau terjadi crash mendadak (lewat proses "replay"). |
| **Least privilege** | Prinsip keamanan: beri akses/izin sekecil mungkin yang benar-benar dibutuhkan suatu proses/user, tidak lebih. |
| **mysqldump** | Alat bawaan MySQL/MariaDB untuk membuat backup database dalam bentuk file teks berisi perintah SQL yang bisa dijalankan ulang untuk merekonstruksi data. |
| **Mesh VPN** | Jenis VPN di mana setiap perangkat bisa terhubung langsung (atau nyaris langsung) ke perangkat lain dalam jaringan yang sama, bukan semua traffic wajib lewat satu server pusat seperti VPN tradisional. |
| **CGNAT (Carrier-Grade NAT)** | Rentang alamat IP privat khusus (`100.64.0.0/10`) yang dipakai Tailscale &amp; beberapa ISP untuk memberi alamat ke banyak perangkat tanpa memakai IP publik asli. |
| **DERP relay** | Server perantara milik Tailscale yang meneruskan traffic terenkripsi antar perangkat ketika koneksi langsung (peer-to-peer) tidak berhasil dibentuk karena keterbatasan NAT/firewall. |
| **NAT traversal** | Teknik agar dua perangkat di belakang router/firewall berbeda bisa saling terhubung langsung, meski keduanya "tersembunyi" di balik NAT masing-masing. |
| **Reverse proxy** | Server (seperti nginx) yang menerima request dari luar lalu meneruskannya ke server/aplikasi yang sesuai di belakangnya — dari sudut pandang pengunjung, seolah reverse proxy itulah aplikasinya. |
| **Cloudflare Tunnel** | Layanan yang membuat koneksi keluar dari server Anda ke jaringan Cloudflare, sehingga traffic publik bisa sampai ke server tanpa perlu membuka port masuk apa pun di router Anda. |
| **Bridge network (Docker)** | Jaringan virtual internal yang dibuat Docker supaya container-container bisa saling berkomunikasi, terisolasi dari jaringan host kecuali port yang sengaja di-expose. |
| **Bind-mount** | Menghubungkan folder di host langsung ke dalam container, sehingga perubahan file terlihat instan di kedua sisi — beda dengan volume yang dikelola sepenuhnya oleh Docker. |
| **I2C** | Protokol komunikasi sederhana 2-kabel (data + clock) yang umum dipakai menghubungkan sensor/layar kecil ke papan seperti Raspberry Pi. |
| **Systemd unit** | Definisi sebuah layanan/proses yang dikelola oleh `systemd` (init system Linux modern) — mengatur kapan &amp; bagaimana proses itu start, restart, dan bergantung pada layanan lain. |
| **`After=` / `Requires=`** | Baris konfigurasi systemd yang mengatur urutan &amp; dependency antar service. `After=` cuma menjamin urutan start, `Requires=` membuat satu service ikut berhenti/gagal kalau service yang di-butuhkan gagal. |
| **NOPASSWD (sudoers)** | Pengaturan yang mengizinkan `sudo` dijalankan tanpa memasukkan password — sebaiknya selalu dibatasi ke command spesifik, bukan akses root penuh tanpa batas. |
| **debsums** | Alat yang membandingkan checksum file terinstall dengan checksum resmi dari paket `.deb`, untuk mendeteksi file yang berubah di luar mekanisme paket resmi. |
| **SUID/SGID binary** | Program yang saat dijalankan otomatis mendapat hak akses pemilik file (biasanya root), bukan hak akses user yang menjalankannya — berguna untuk kasus tertentu, tapi juga target umum eksploitasi kalau salah konfigurasi. |
| **On-device AI / LLM lokal** | Model kecerdasan buatan (Large Language Model) yang berjalan langsung di perangkat Anda sendiri, bukan lewat panggilan API ke server pihak ketiga. |
| **Symlink (symbolic link)** | File khusus yang isinya cuma "pointer" menunjuk ke file/direktori lain — kalau pointer ini rusak/salah, sistem yang membacanya bisa salah paham total soal apa yang seharusnya ada di situ. |

---

## Troubleshooting Cheat-sheet

| Gejala | Kemungkinan sebab | Command untuk cek |
|---|---|---|
| Server freeze/hang total saat proses tulis data besar (restore DB, copy file besar) | HMB nonaktif di SSD DRAM-less ([Chapter 03](../03-storage-nvme-reliability/)) | `dmesg \| grep -i "host memory"` |
| SSH "connection refused" (bukan timeout) | Service `sshd` tidak jalan (kemungkinan `default.target` atau target boot rusak) — jaringan sendiri sebenarnya hidup | `systemctl status ssh`, `systemctl get-default`, `ls -la /etc/systemd/system/default.target` |
| SSH timeout / tidak ada respons sama sekali | Firewall memblokir, atau jaringan/Tailscale bermasalah di jalur | `tailscale ping <ip>`, `tailscale netcheck`, `sudo ufw status verbose` |
| Boot "selesai" tapi hampir semua service tidak jalan | Target boot default rusak (bukan symlink lagi) — lihat [Chapter 99 Babak 2](../99-studi-kasus-insiden/) | `systemd-analyze verify default.target` |
| Command umum tiba-tiba "not found" atau berperilaku aneh (`iptables`, `php`, dll) | `/etc/alternatives` kehilangan isinya | `ls /etc/alternatives \| wc -l` (normal 170+) |
| Layar kosong / kursor berkedip, keyboard tidak respons | Rangkaian akibat dari `/etc/alternatives` kosong — lihat [Chapter 99 Babak 3](../99-studi-kasus-insiden/) | Sama seperti di atas |
| Server dapat IP berbeda dari yang di-set statis | Config NetworkManager hilang/rusak, jatuh ke DHCP default | `ls /etc/NetworkManager/system-connections/`, `nmcli con show` |
| nginx gagal start berulang saat boot, lalu berhenti dicoba | Race condition — nginx coba bind ke IP yang belum aktif (Tailscale/dinamis) | `journalctl -u nginx -b`, cek `listen` di config nginx menunjuk ke IP dinamis atau bukan |
| Cron job "sudah dijadwalkan" tapi efeknya tidak pernah terjadi | `sudo` di dalam cron butuh TTY, gagal senyap | Baca isi log job itu — cari baris `sudo: a password is required` |
| Log sebuah proses terjadwal kosong/tidak berubah lama | BELUM TENTU mati — bisa jadi memang tidak ada yang perlu dilaporkan | `journalctl --since "X days ago" \| grep -i "CRON.*<nama-command>"` — cek bukti eksekusi langsung |
| fail2ban tidak memblokir IP di port SSH tertentu | Baris `port =` di jail cuma cover satu port | `sudo fail2ban-client status sshd`, cek `port` di `/etc/fail2ban/jail.local` |
| Container tidak bisa diakses dari luar sama sekali | Container mungkin bind ke `127.0.0.1` (benar!) tapi nginx di depannya belum dikonfigurasi/gagal | `docker ps` (cek port mapping), `curl http://127.0.0.1:<port>` dari host langsung |
| Container BISA diakses langsung dari LAN tanpa lewat nginx (seharusnya tidak bisa) | Port container ter-bind ke `0.0.0.0`, bukan `127.0.0.1` — celah keamanan | `docker port <container>`, cek `docker-compose.yml` |
| Database baru tidak pernah muncul di backup otomatis | Lupa grant privilege ke user `backup` untuk DB baru itu ([Chapter 04](../04-database-arsitektur/)) | `mysql -u backup -p -e "SHOW DATABASES;"` — cek apakah DB baru muncul di hasil |
| Ollama/service lain restart berulang-ulang saat boot | Dependency systemd cuma ke `network-online.target`, bukan ke service spesifik yang benar-benar dibutuhkan | `journalctl -u <service> -b \| grep -c "Main process exited"` |

---

## FAQ

**Kenapa tidak pakai VPS saja, lebih simpel?**
VPS punya tempatnya sendiri &mdash; kalau Anda cuma butuh satu aplikasi kecil
jalan cepat tanpa mau pusing hardware, VPS jelas lebih praktis. Server
rumahan cocok kalau Anda memang ingin belajar mendalam, ingin kontrol
penuh atas storage &amp; jaringan, atau punya kebutuhan biaya tetap
(bukan tagihan yang naik seiring traffic). Tutorial ini tidak
mengklaim satu pendekatan selalu lebih baik dari yang lain.

**Amankah menaruh server produksi di rumah?**
Aman selama prinsip keamanan berlapis di tutorial ini diikuti: tidak
ada port yang di-forward langsung ke internet (Cloudflare Tunnel),
akses admin lewat mesh VPN bukan port terbuka (Tailscale), firewall
default-deny, fail2ban, dan monitoring aktif. Risiko terbesar server
rumahan sebenarnya bukan soal jaringan, tapi **listrik &amp; hardware**
(lihat Chapter 99) &mdash; itu sebabnya UPS sangat disarankan.

**Perlu internet berapa cepat untuk ini?**
Untuk sebagian besar beban kerja web app skala kecil-menengah, koneksi
rumahan standar (bahkan yang tidak terlalu cepat) sudah cukup &mdash;
bottleneck biasanya bukan di bandwidth, tapi di reliabilitas (uptime
koneksi) dan latensi. Cloudflare Tunnel juga membantu menyerap sebagian
beban lewat caching &amp; jaringan mereka sebelum sampai ke server Anda.

**Bagaimana kalau IP publik rumah saya berubah-ubah (dynamic IP dari ISP)?**
Ini justru salah satu alasan kuat memakai Cloudflare Tunnel: karena
`cloudflared` yang membuat koneksi KELUAR (bukan menunggu koneksi
masuk), IP publik rumah Anda **tidak relevan sama sekali** untuk
tunnel tetap bekerja &mdash; berbeda dengan pendekatan port-forward
tradisional yang mengharuskan Anda melacak &amp; update IP publik
setiap kali berubah (biasanya lewat layanan Dynamic DNS).

**Apa yang terjadi kalau Raspberry Pi/SSD-nya rusak total?**
Inilah kenapa seluruh Chapter 11 (backup berlapis) ada. Dengan backup
database, kode, dan state sistem yang terpisah &amp; terjadwal,
pemulihan ke hardware baru berarti: install OS baru (Chapter 02),
restore keempat lapis backup, dan Anda kembali beroperasi &mdash; jauh
lebih cepat &amp; kurang stres dibanding merekonstruksi semuanya dari
ingatan.

**Bisa pakai Raspberry Pi 4 (bukan 5)?**
Sebagian besar prinsip di tutorial ini (reverse proxy, Tailscale,
Docker, backup, keamanan) berlaku sama di RPi 4. Yang paling perlu
disesuaikan adalah Chapter 03 &mdash; RPi 4 tidak punya slot PCIe
native untuk NVMe HAT (butuh adapter USB, dengan karakteristik
reliabilitas berbeda), dan performa keseluruhan (terutama untuk AI
lokal di Chapter 10) akan jauh lebih terbatas.

**Perlu pengalaman Linux mendalam untuk mengikuti tutorial ini?**
Tidak untuk memulai (bagian Quick Start tiap chapter dirancang bisa
diikuti pemula), tapi tutorial ini akan jauh lebih bernilai kalau Anda
juga membaca bagian "Kenapa Begini" di tiap chapter &mdash; di situlah
Anda membangun kemampuan mendiagnosis masalah sendiri nanti, bukan
cuma bisa menjalankan langkah yang sudah ditulis orang lain.

---

## Daftar Bacaan Lanjutan

- [Tailscale Knowledge Base](https://tailscale.com/kb/) &mdash; dokumentasi resmi mesh VPN yang dipakai di Chapter 05.
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) &mdash; dokumentasi resmi Cloudflare Tunnel, Chapter 06.
- [Docker Docs](https://docs.docker.com/) &mdash; dokumentasi resmi Docker &amp; Docker Compose, Chapter 07.
- [nginx Documentation](https://nginx.org/en/docs/) &mdash; referensi lengkap konfigurasi nginx, Chapter 06.
- [systemd.unit man page (freedesktop.org)](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html) &mdash; referensi lengkap `After=`/`Requires=` dan konsep unit systemd lainnya, dirujuk di beberapa chapter.
- [fail2ban Wiki](https://github.com/fail2ban/fail2ban/wiki) &mdash; dokumentasi &amp; contoh konfigurasi jail tambahan, Chapter 12.
- [Ollama Library](https://ollama.com/library) &mdash; daftar model AI lokal yang bisa dijalankan, Chapter 10.
- [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/) &mdash; dokumentasi resmi hardware &amp; `config.txt`/`cmdline.txt`, dirujuk di Chapter 02 &amp; 03.

---

⬅️ [Kembali ke daftar isi](../../README.md)
