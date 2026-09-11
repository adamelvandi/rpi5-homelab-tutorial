# 99 — Studi Kasus Insiden (Real Incident Case Studies)

> Ini bab yang paling ingin kami tulis dengan baik, karena ini yang
> membedakan tutorial ini dari "panduan instalasi" biasa. Semua yang
> Anda baca di bawah ini **benar-benar terjadi** di server yang sama
> yang menjadi dasar seluruh tutorial ini. Nama domain, IP, dan detail
> bisnis sudah digeneralisasi — tapi kronologi teknis, gejala, jalan
> buntu investigasi, dan akar masalah sebenarnya **dipertahankan
> sepenuhnya apa adanya**. Kalau Anda menjalankan Raspberry Pi sebagai
> server produksi, kemungkinan besar Anda akan menghadapi setidaknya
> satu dari pola-pola ini suatu hari nanti.

## Insiden #1: Mati Listrik yang Berubah Jadi Lima Insiden Sekaligus

### Pemicu

Sebuah mati listrik mendadak. Server ini, seperti banyak server
rumahan, **belum punya UPS** saat itu (lihat pengakuan jujur soal ini
di [Chapter 01](../01-hardware-persiapan/)). Saat listrik kembali dan
server boot ulang, semua terlihat baik-baik saja sekilas — sampai
`unsafe_shutdowns` counter di SMART data SSD menunjukkan lonjakan, dan
gejala aneh mulai bermunculan satu per satu selama beberapa hari
berikutnya. Yang awalnya terlihat seperti "sedikit tidak stabil pasca
listrik mati" ternyata adalah **lima masalah terpisah**, tersembunyi
satu di balik yang lain, yang baru terungkap penuh lewat investigasi
berlapis.

### Babak 1: SSD yang Membeku Total

**Gejala**: Server freeze total di tengah beban tulis. Bukan lambat —
benar-benar berhenti merespons, bahkan lewat SSH dari perangkat lain.

**Jalan buntu pertama**: Kecurigaan awal wajar mengarah ke "bug
software" atau "filesystem corrupt" — investigasi menghabiskan waktu
mengejar kemungkinan itu.

**Petunjuk yang akhirnya jadi kunci**: Pola yang muncul konsisten
adalah **"baca sempurna, tulis mati"** — sistem bisa membaca data
tanpa masalah, tapi operasi tulis apa pun membuat semuanya hang.
Pola inilah yang mengarahkan investigasi ke lapisan yang jauh lebih
rendah dari filesystem: **firmware &amp; driver storage itu sendiri.**

**Akar masalah sebenarnya**: SSD NVMe yang dipakai adalah jenis
**DRAM-less** (dijelaskan lengkap di [Chapter 03](../03-storage-nvme-reliability/)),
dan firmware Raspberry Pi ternyata **menonaktifkan Host Memory Buffer
(HMB) secara diam-diam** — parameter yang menonaktifkannya
(`nvme.max_host_mem_size_mb=0`) disuntikkan otomatis ke kernel command
line dan **tidak terlihat sama sekali** kalau Anda cuma membuka file
`cmdline.txt` biasa; ia cuma muncul di `/proc/cmdline` (command line
yang benar-benar diterima kernel). Tanpa HMB, SSD terpaksa menyimpan
tabel pemetaan datanya (FTL) langsung ke NAND flash setiap kali —
lambat, dan di bawah beban tulis berkelanjutan, latensinya melewati
timeout controller.

**Fix**: Parameter eksplisit di `cmdline.txt` untuk memaksa HMB tetap
aktif dengan ukuran tertentu (`nvme.max_host_mem_size_mb=64`), plus
beberapa parameter pendukung (`nvme_core.io_timeout=180`,
`pcie_aspm=off`). Detail lengkap &amp; cara verifikasi ada di
Chapter 03.

**Pelajaran**: Kalau Anda melihat pola "baca sempurna, tulis mati" di
Raspberry Pi + NVMe, jangan buang waktu mengejar bug filesystem —
curigai HMB sejak awal.

### Babak 2: Boot yang "Selesai" Tapi Hampir Kosong

**Gejala**: Setelah HMB diperbaiki dan filesystem dipastikan bersih,
boot **masih** bermasalah. Kali ini bukan freeze — boot terlihat
selesai (mencapai tahap akhir proses boot normal), tapi nyaris tidak
ada layanan yang benar-benar berjalan. SSH menolak koneksi dengan
**connection refused** (bukan timeout) — sinyal penting: jaringan
&amp; kernel hidup (paket TCP RST berhasil terkirim balik), tapi
`sshd` sendiri tidak pernah start sehingga portnya benar-benar
tertutup.

**Investigasi**: Kalau hampir semua service (web server, database,
SSH, container) tidak pernah start padahal boot "selesai", curigai
**target systemd** yang jadi titik masuk boot ke mode normal.

**Akar masalah sebenarnya**: File `default.target` — yang **seharusnya
berupa symlink** menunjuk ke target boot normal sistem — ternyata
sudah berubah jadi **file biasa berisi data yang sama sekali tidak
berhubungan** (isinya kebetulan berupa tabel data ukuran kertas dari
paket printing yang terpasang di sistem — bukti nyata kerusakan filesystem
level rendah, bukan kesalahan konfigurasi manual). Karena file itu
bukan symlink ke target yang tepat, systemd memuatnya sebagai target
**kosong tanpa dependency apa pun** — target normal yang seharusnya
"mewajibkan" puluhan service inti untuk start, sekarang tidak
mewajibkan apa pun. Boot jadi "selesai" dalam arti proses booting tidak
error, tapi nyaris semua service inti tidak pernah diminta untuk mulai.

**Fix**: Kembalikan symlink `default.target` ke target yang benar.

**Pelajaran**: `systemctl` bisa "sukses" secara superfisial padahal
substansinya kosong. Kalau nyaris semua service tidak start tapi boot
tidak menunjukkan error jelas, curigai integritas target boot itu
sendiri — apakah ia benar-benar symlink seperti seharusnya.

### Babak 3: Kursor Berkedip, Keyboard Mati

**Gejala**: Boot berikutnya sudah lebih jauh (melewati titik masalah di
Babak 2), tapi layar hanya menampilkan kursor teks `_` berkedip, dan
keyboard sama sekali tidak merespons.

**Akar masalah sebenarnya**: Direktori `/etc/alternatives` — sistem
symlink Debian untuk memilih versi command yang aktif ketika ada lebih
dari satu pilihan terpasang (contoh: `iptables`, `php`, editor
default) — **kehilangan HAMPIR SELURUH isinya** (tersisa hanya 1 dari
ratusan entri yang seharusnya ada). Efeknya berantai luas karena
banyak command penting sebenarnya cuma symlink lewat direktori ini:
`iptables`/`ip6tables` yang hilang membuat firewall &amp; Docker gagal,
binary terkait console/keyboard membuat konsol teks kehilangan
kemampuan menerima input, dan command yang dipakai desktop environment
membuat tampilan grafis gagal total start — semuanya bermuara ke
**kursor berkedip tanpa respons apa pun**.

**Cara deteksi cepat untuk kasus serupa**: `ls /etc/alternatives | wc -l`
— sistem yang sehat biasanya punya 170+ entri. Jauh lebih sedikit dari
itu adalah tanda jelas.

**Fix**: Selama database internal paket (`/var/lib/dpkg/alternatives`)
masih utuh, semua entri bisa dibangun ulang dengan memanggil
`update-alternatives --auto` untuk tiap nama yang terdaftar di
database itu.

**Pelajaran**: Satu direktori kecil yang jarang dipikirkan orang bisa
jadi titik gagal tunggal untuk lusinan fungsi sistem yang sekilas
tidak berhubungan sama sekali.

### Babak 4: Jaringan yang Menghilang &amp; IP yang Salah

**Gejala**: SSH ke alamat IP statis yang seharusnya selalu sama, gagal
terus — server ternyata mendapat IP DHCP yang berbeda sama sekali.

**Akar masalah sebenarnya**: Direktori konfigurasi NetworkManager
**hilang total** (bukan cuma satu file, seluruh direktori). Tanpa
konfigurasi apa pun, NetworkManager jatuh ke perilaku default paling
polos: minta IP lewat DHCP biasa — bukan IP statis yang seharusnya
dipakai. Profil koneksi (termasuk kredensial WiFi) untungnya berhasil
ditemukan kembali di `lost+found` (area filesystem tempat data
"yatim" pasca kerusakan disimpan oleh `fsck`) dan dikembalikan secara
manual, lengkap dengan permission yang benar (NetworkManager menolak
memuat file profil yang permission-nya terlalu longgar — pelajaran
tambahan: permission file konfigurasi jaringan itu penting, bukan
sekadar formalitas).

**Pelajaran**: Kalau server tiba-tiba dapat IP yang tidak semestinya
padahal Anda yakin sudah setting statis, cek dulu apakah
direktori/file konfigurasi jaringan itu sendiri masih ada &amp; utuh —
bukan cuma mengecek isi settingnya benar atau salah.

### Babak 5: nginx Menolak Start — Perlombaan Melawan Waktu

**Gejala**: nginx gagal start berulang kali saat boot, sampai systemd
menyerah dengan pesan "start request repeated too quickly".

**Akar masalah sebenarnya**: nginx dikonfigurasi untuk `listen` di
alamat IP Tailscale server (bukan `0.0.0.0`/localhost — lihat
[Chapter 06](../06-reverse-proxy-cloudflare-tunnel/) untuk kenapa
pola ini kadang dipakai). Saat boot, Tailscale butuh waktu untuk
mendapat alamat IP-nya — dan nginx mencoba start **sebelum** itu
terjadi. `bind()` ke alamat yang belum ada langsung gagal. Dependency
`After=tailscaled` yang sudah dipasang sebelumnya ternyata tidak cukup,
karena `tailscaled` sendiri juga belum benar-benar "online" (butuh
jaringan yang, ironisnya, baru pulih di Babak 4 di atas) — rantai
kegagalan yang saling terkait.

**Fix**: Kombinasi dua lapis — retry otomatis di level systemd
(`Restart=on-failure`), DAN mengizinkan nginx bind ke alamat yang
belum ada sama sekali lewat sysctl `net.ipv4.ip_nonlocal_bind = 1`
(detail lengkap di Chapter 06). Begitu Tailscale akhirnya siap, nginx
otomatis bisa melayani di alamat itu tanpa perlu restart manual.

**Pelajaran**: `After=` di systemd cuma menjamin **urutan** start,
bukan bahwa service yang di-`After`-kan itu sudah benar-benar **siap
sepenuhnya**. Untuk service yang bind ke alamat dinamis, jangan
bergantung pada urutan start saja — beri jaring pengaman tambahan.

## Kesimpulan &amp; Pelajaran yang Dipetik

Lima babak di atas, dari satu pemicu yang sama (mati listrik), memakan
waktu penyelidikan bertahap — setiap kali satu lapisan masalah selesai
diperbaiki, lapisan berikutnya baru terlihat. Beberapa pelajaran lintas
insiden yang layak dibawa ke server Anda sendiri:

1. **"Baca sempurna, tulis mati" = curigai storage/HMB dulu**, jangan
   buang waktu mengejar bug filesystem.
2. **Boot yang "selesai tanpa error" tidak berarti sehat** — verifikasi
   substansinya (apakah service benar-benar start), bukan cuma status
   proses boot.
3. **Direktori kecil yang jarang dipikirkan** (`/etc/alternatives`,
   config NetworkManager) bisa jadi titik gagal tunggal untuk banyak
   fungsi yang sekilas tidak berhubungan.
4. **Kerusakan filesystem level rendah bisa mengacak APA SAJA** —
   bukan cuma file besar/penting yang terlihat jelas, tapi juga file
   "boring" yang tidak pernah terpikir perlu diperiksa.
5. **`After=` bukan jaminan "siap"**, cuma jaminan "urutan". Beri
   jaring pengaman tambahan untuk dependency yang benar-benar kritis.
6. **Backup lapisan sistem** (Chapter 11) — crontab, config `/etc`,
   metadata paket — **bukan formalitas**. Semua insiden di atas akan
   jauh lebih cepat dipulihkan kalau ada backup sistem yang bisa
   langsung dibandingkan/direstorasi, dibanding harus merekonstruksi
   semuanya dari nol lewat investigasi manual seperti kronologi di
   atas.
7. **UPS. Beli UPS.** Pemicu asli semua ini adalah satu kali mati
   listrik. Server ini akhirnya selamat &amp; pulih penuh, tapi biaya
   waktu investigasi di atas jauh lebih mahal dari harga UPS kecil
   sekalipun.

---

*Insiden berikutnya (kalau ada) akan ditambahkan sebagai "Insiden #2"
dan seterusnya — bab ini living document, bukan cerita yang selesai
sekali ditulis.*

## Kembali ke

⬅️ [Chapter 13 — Operasional & Dokumentasi](../13-operasional-dokumentasi-ai-assisted/)

⬅️⬅️ [Daftar Isi](../../README.md)
