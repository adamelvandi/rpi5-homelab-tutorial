# Diagrams

Semua diagram arsitektur/alur di tutorial ini ditulis sebagai **kode
Mermaid inline langsung di tiap file `README.md` chapter** (bukan file
gambar terpisah di folder ini) — GitHub merender kode Mermaid di dalam
blok ` ```mermaid ` secara otomatis jadi diagram visual.

Keuntungan pendekatan ini dibanding file gambar (`.png`/`.svg`)
terpisah:
- **Selalu sinkron dengan teks** — diagram di-review &amp; diedit lewat
  Pull Request yang sama seperti isi tulisan, tidak ada file gambar
  basi yang lupa diperbarui.
- **Bisa di-diff** seperti kode biasa di git, bukan file biner.
- Tidak butuh software desain gambar terpisah untuk berkontribusi.

Diagram yang sudah ada, tersebar di beberapa chapter:
- `README.md` (root) &amp; [Chapter 00](../../docs/00-pengantar/) — arsitektur besar keseluruhan sistem
- [Chapter 03](../../docs/03-storage-nvme-reliability/) — perbandingan SSD DRAM-based vs DRAM-less + HMB
- [Chapter 06](../../docs/06-reverse-proxy-cloudflare-tunnel/) — port-forward tradisional vs Cloudflare Tunnel
- [Chapter 07](../../docs/07-docker-infrastruktur/) — isolasi network Docker
- [Chapter 08](../../docs/08-lcd-oled-status-display/) — wiring I2C OLED
- [Chapter 09](../../docs/09-monitoring-alert-telegram/) — sequence diagram alert-hanya-saat-berubah
- [Chapter 11](../../docs/11-backup-strategi-4-lapis/) — jadwal &amp; alur 4 lapis backup
- [Chapter 99](../../docs/99-studi-kasus-insiden/) — timeline kaskade 5 babak insiden

Folder ini tetap ada untuk aset gambar non-diagram (screenshot dashboard,
dll) kalau suatu saat dibutuhkan — saat ini kosong.
