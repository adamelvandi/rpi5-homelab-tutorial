# 03 — Storage & Reliabilitas NVMe (NVMe Reliability)

> ⚠️ **Ini bab paling penting di seluruh tutorial.** Kalau Anda cuma
> punya waktu membaca satu bab sebelum menaruh beban produksi apa pun
> di server Anda, baca bab ini. Server di balik tutorial ini pernah
> **freeze permanen total** karena isu yang dibahas di sini — dan
> ceritanya bukan kasus langka, ini karakteristik kelas hardware
> tertentu yang banyak dijual tanpa peringatan jelas.

## Quick Start

Kalau Anda pakai Raspberry Pi 5 + NVMe HAT + SSD apa pun, **wajib** cek
dan pasang parameter ini SEBELUM menaruh beban produksi:

**1. Cek apakah HMB (Host Memory Buffer) aktif:**

```bash
dmesg | grep -i "host memory"
```

- ✅ **BENAR**: `nvme nvme0: allocated 64 MiB host memory buffer.`
- 🚨 **BAHAYA**: `nvme nvme0: min host memory (3 MiB) above limit (0 MiB)`
  — HMB MATI, server Anda dalam risiko freeze di bawah beban tulis.

**2. Kalau BAHAYA, tambahkan ini ke `/boot/firmware/cmdline.txt`**
(satu baris, tambahkan di akhir baris yang sudah ada — jangan buat baris
baru):

```
nvme.max_host_mem_size_mb=64 nvme_core.io_timeout=180 nvme_core.default_ps_max_latency_us=0 pcie_aspm=off
```

**3. Di `/boot/firmware/config.txt`, tambahkan:**

```
dtparam=pciex1_gen=1
```

*(Gen 1, bukan Gen 2 — lihat penjelasan di bawah kenapa ini bukan
tentang kecepatan.)*

**4. Reboot, lalu cek ulang langkah 1.** Harus muncul baris "allocated
64 MiB host memory buffer" sekarang.

**5. Kecilkan ukuran journal ext4** (mengurangi beban tulis pasca-crash
kalau suatu saat terjadi mati listrik):

```bash
sudo e2fsck -f -y /dev/nvme0n1p2      # HARUS bersih dulu (exit 0)
sudo tune2fs -O ^has_journal /dev/nvme0n1p2
sudo tune2fs -J size=128 -j /dev/nvme0n1p2
sudo e2fsck -f -y /dev/nvme0n1p2      # verifikasi ulang
```

*(Sesuaikan `/dev/nvme0n1p2` dengan partisi root Anda — cek dulu dengan
`lsblk`. Filesystem WAJIB unmounted &amp; bersih sebelum langkah ini.)*

## Kenapa Begini

### Apa itu SSD "DRAM-less", dan kenapa ini penting

Setiap SSD (termasuk NVMe) punya tabel pemetaan internal — **FTL
(Flash Translation Layer)** — yang mencatat di mana setiap blok data
sebenarnya disimpan di chip NAND flash. Tabel ini butuh disimpan di
memori cepat supaya bisa diakses instan.

- **SSD DRAM-based**: punya chip RAM sendiri di board SSD, khusus untuk
  tabel FTL ini. Cepat, independen dari sistem host.
- **SSD DRAM-less**: tidak punya RAM sendiri sama sekali (ini yang
  membuatnya lebih murah untuk diproduksi). Sebagai gantinya, ia
  memakai fitur bernama **Host Memory Buffer (HMB)** — meminjam
  sepotong kecil RAM dari sistem host (dalam kasus RPi5, RAM Pi itu
  sendiri) untuk menyimpan tabel FTL-nya.

Kalau HMB berhasil dialokasikan, SSD DRAM-less bisa berjalan cukup
dekat dengan performa SSD DRAM-based untuk kebanyakan beban kerja.
**Tapi kalau HMB tidak aktif** — baik karena firmware, driver, atau
kernel command line yang tidak tepat — SSD DRAM-less terpaksa menyimpan
&amp; membaca ulang tabel FTL-nya langsung dari NAND flash setiap kali,
yang jauh lebih lambat.

### Kenapa ini bisa membuat Raspberry Pi 5 freeze total

Di bawah beban tulis yang tersebar &amp; berkelanjutan — contoh nyata:
restore database besar, replay journal filesystem setelah crash, atau
banyak service start bersamaan saat boot — permintaan lookup FTL ke NAND
yang terus-menerus ini bisa membuat **latensi I/O melewati batas
timeout controller**. Ketika itu terjadi, controller SSD bisa reset
atau — dalam kasus paling buruk — **freeze permanen** yang cuma bisa
diperbaiki dengan cabut daya total (bukan reboot biasa).

**Ciri khas yang harus langsung membuat Anda curiga ke HMB**: sistem
bisa **membaca** data dengan sempurna (boot berhasil sampai titik
tertentu, file bisa dibaca), tapi **menulis** apa pun membuat sistem
hang. Kalau Anda melihat pola ini, jangan buang waktu mengejar "bug
filesystem" — cek HMB dulu.

**Kenapa ini sering tidak ketahuan dari `cmdline.txt` biasa**: firmware
Raspberry Pi bisa menyuntikkan `nvme.max_host_mem_size_mb=0` ke kernel
command line **secara otomatis di level firmware**, yang artinya
**tidak akan terlihat** kalau Anda cuma membuka &amp; membaca file
`/boot/firmware/cmdline.txt` — parameter itu cuma muncul di
`/proc/cmdline` (command line yang SEBENARNYA diterima kernel saat
boot). Ini sebabnya langkah verifikasi di Quick Start memakai `dmesg`
(bukti hasil nyata), bukan cuma membaca isi file config.

### Kenapa `pcie_aspm=off` dan Gen 1 (bukan Gen 2)

- `pcie_aspm=off` menonaktifkan **Active State Power Management** di
  jalur PCIe — fitur hemat daya yang bisa memasukkan link PCIe ke
  status idle rendah-daya di antara transfer. Bagus untuk laptop,
  tapi transisi keluar-masuk status ini bisa menambah latensi yang
  memperparah masalah timeout di atas.
- **Gen 1, bukan Gen 2**, terdengar aneh (bukannya Gen 2 lebih cepat?)
  — tapi ini bukan soal kecepatan mentah. Sebagian kombinasi SSD +
  HAT NVMe pihak ketiga di Raspberry Pi 5 punya masalah stabilitas
  sinyal di Gen 2 yang tidak muncul di Gen 1. **Jangan naikkan ke Gen 2
  tanpa pengujian beban tulis berkelanjutan yang serius dulu** — kalau
  stabil di Gen 1, pertimbangkan baik-baik apakah kenaikan kecepatan
  sepadan dengan risikonya.

### Kenapa ukuran journal ext4 diperkecil

Journal ext4 mencatat perubahan filesystem sebelum benar-benar ditulis,
supaya kalau terjadi crash, sistem bisa "replay" journal itu untuk
kembali ke state konsisten. Tapi replay journal itu sendiri adalah
**ledakan beban tulis** — dan kalau itu terjadi tepat saat controller
SSD Anda sedang rentan (HMB baru saja aktif lagi setelah reboot,
misalnya), replay journal yang besar bisa jadi pemicu putaran kedua
masalah yang sama. Journal yang lebih kecil (128MB, dari default yang
seringkali 1GB+) berarti **ledakan tulis pasca-crash yang jauh lebih
kecil** — trade-off kecil di waktu recovery demi keandalan lebih tinggi.

### Perintah yang HARUS dihindari

- **Jangan** pakai `tune2fs -O ^has_journal` untuk "menghindari" replay
  journal sama sekali. Perintah itu justru **memaksa replay journal
  dulu** sebelum menghapusnya — kalau controller Anda sedang rentan,
  ini bisa jadi pemicu, bukan solusi.
- **Jangan** set `nr_requests` (parameter scheduler I/O block device) di
  bawah 64. Nilai terlalu rendah (misal 4) bisa menyebabkan **deadlock**
  di level kernel (`blk_mq_get_tag`) yang membuat proses stuck permanen
  di D-state — tidak bisa di-kill, tidak bisa apa-apa selain reboot
  keras.

### Kalau controller sudah drop tapi belum mati total

Kadang controller NVMe drop dari bus tapi sistem masih hidup (proses
lain masih responsif, cuma I/O ke SSD yang macet). Coba pulihkan **tanpa
reboot** dulu:

```bash
echo 1 | sudo tee /sys/bus/pci/devices/<alamat-pci-nvme-anda>/remove
sleep 4
echo 1 | sudo tee /sys/bus/pci/rescan
```

*(Cari alamat PCI NVMe Anda dengan `lspci | grep -i nvme` dulu.)*

Kalau `lspci` menunjukkan device sebagai **"conventional PCI endpoint"**
(bukan "PCIe Endpoint" seperti biasa), rescan di atas **tidak akan
menolong** — itu tanda bus PCIe benar-benar dalam status rusak dan
Anda harus **cabut daya total selama ~60 detik** (reboot software biasa
tidak memutus daya ke slot PCIe, jadi tidak akan membantu).

### Menyelamatkan data dari filesystem yang rusak TANPA menulis apa pun

Kalau filesystem sudah dalam kondisi tidak sehat dan Anda takut menulis
apa pun akan memperparah keadaan (termasuk `fsck` yang bisa menulis
perbaikan), `debugfs` dengan mode **catastrophic** adalah cara
paling aman — ini murni read-only:

```bash
sudo debugfs -c -R "ls -l /path/di/dalam/filesystem" /dev/nvme0n1p2
sudo debugfs -c -R "rdump /path/sumber /path/tujuan" /dev/nvme0n1p2
```

Tujuan dump **harus** filesystem ext4 (bukan exFAT/NTFS) supaya
permission &amp; symlink ikut tersalin dengan benar. Kalau Anda hanya
punya media exFAT, buat file image kosong dulu, format ext4, lalu mount
sebagai loop device sebagai tujuan.

## Studi kasus lengkap

Insiden nyata di balik semua peringatan di atas — kronologi lengkap,
gejala yang membingungkan di awal, jalan investigasi yang salah arah,
sampai akar masalah sebenarnya ditemukan — didokumentasikan penuh di
[Chapter 99 — Studi Kasus Insiden](../99-studi-kasus-insiden/).

## Checklist sebelum lanjut

- [ ] `dmesg | grep -i "host memory"` menunjukkan HMB aktif (bukan
      warning "min host memory above limit")
- [ ] Parameter `cmdline.txt` &amp; `config.txt` di atas sudah terpasang
      dan **selamat dari reboot** (cek ulang setelah restart)
- [ ] Journal ext4 sudah diperkecil (opsional tapi disarankan kalau
      Anda paham risikonya)
- [ ] Anda paham ciri khas "baca sempurna, tulis mati" — supaya kalau
      suatu hari muncul lagi, Anda tidak buang waktu mengejar arah yang
      salah

## Lanjut ke

➡️ [Chapter 04 — Database Arsitektur](../04-database-arsitektur/)

⬅️ [Chapter 02 — Instalasi OS &amp; Setup Dasar](../02-instalasi-os-dasar/)
