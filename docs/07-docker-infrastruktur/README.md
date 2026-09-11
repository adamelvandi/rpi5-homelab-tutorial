# 07 — Docker Infrastruktur (Docker Infrastructure)

## Quick Start

**1. Install Docker:**

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER   # supaya tidak perlu sudo tiap docker command
```

**2. Buat network khusus untuk aplikasi web** (isolasi dari bridge
default Docker):

```bash
docker network create --subnet=172.28.0.0/16 webapps-network
```

**3. Template `docker-compose.yml` per aplikasi** (satu file per app,
bukan satu file raksasa untuk semua):

```yaml
services:
  app-a:
    build: .
    container_name: app-a
    restart: unless-stopped
    ports:
      - "127.0.0.1:3001:3000"   # HANYA localhost, nginx yang expose ke luar
    networks:
      - webapps-network
    volumes:
      - ./data:/app/data        # bind-mount untuk data yang perlu diakses langsung dari host
    env_file:
      - .env                    # RAHASIA — jangan pernah commit file ini ke git

networks:
  webapps-network:
    external: true
```

```bash
docker compose up -d
```

**4. Kalau container butuh akses ke MariaDB di host** (bukan container
database terpisah), buka firewall HANYA untuk subnet Docker itu:

```bash
sudo ufw allow from 172.28.0.0/16 to any port 3306
```

## Kenapa Begini

### Kenapa 1 container = 1 aplikasi

Alternatifnya — menjejalkan banyak proses ke satu container besar —
terdengar lebih hemat resource, tapi kehilangan manfaat inti Docker:
**isolasi &amp; siklus hidup independen**. Kalau App A perlu di-restart
karena crash atau update, App B tidak boleh ikut terganggu. Kalau App A
punya dependency versi Node.js tertentu dan App B versi lain, itu tidak
boleh jadi konflik. Satu container per aplikasi membuat setiap
troubleshooting, update, dan restart **terisolasi ke dampaknya sendiri**.

### Kenapa bind ke `127.0.0.1` saja, bukan `0.0.0.0`

Ini salah satu keputusan keamanan paling penting di seluruh setup
Docker: port container **tidak pernah** di-expose langsung ke jaringan
luar (`0.0.0.0:3001:3000` akan membuat port itu bisa diakses dari LAN/
internet langsung, melewati nginx sepenuhnya). Dengan `127.0.0.1:3001:
3000`, port itu **hanya bisa diakses dari server itu sendiri** — dan
satu-satunya proses di server yang perlu mengaksesnya adalah nginx
(Chapter 06), yang kemudian menerapkan aturan &amp; keamanan tambahan
di depannya (rate-limit, header, dll).

Ini juga berarti: **kalau nginx down, aplikasi ikut tidak bisa diakses
dari luar** — yang justru benar secara keamanan (tidak ada jalur
belakang yang tiba-tiba jadi satu-satunya yang jalan).

### Kenapa network Docker terpisah, bukan default bridge

Docker punya network `bridge` default yang dipakai semua container
kalau tidak dispesifikkan lain. Masalahnya: semua container di situ
bisa saling berkomunikasi bebas secara default, termasuk container
yang seharusnya tidak saling berhubungan sama sekali (App A tidak
punya urusan bisa "melihat" App B lewat jaringan internal). Membuat
network khusus per grup aplikasi (seperti `webapps-network` di atas)
memberi:

- **Isolasi jaringan** — container di luar network itu tidak bisa
  menjangkau container di dalamnya sama sekali.
- **Subnet yang bisa Anda tunjuk eksplisit** di aturan firewall (contoh
  `172.28.0.0/16` di atas) — jadi kalau container butuh akses ke
  service di host (database, misalnya), Anda buka akses **hanya untuk
  subnet spesifik itu**, bukan untuk semua IP.

### Volume vs bind-mount — kapan pakai yang mana

- **Named volume** (`docker volume create`, atau volume tanpa path
  eksplisit di compose) — dikelola sepenuhnya oleh Docker, cocok untuk
  data yang **tidak perlu** Anda akses langsung dari host (data
  internal database container, cache, dll). Lebih portable antar host.
- **Bind-mount** (`./data:/app/data`, path eksplisit dari host) —
  cocok kalau Anda perlu mengakses/mengedit file itu langsung dari
  host (kode aplikasi saat development, file upload yang perlu
  di-backup dengan tools biasa di host, config yang perlu diedit tanpa
  masuk ke container).

**Landmine yang perlu diwaspadai**: kalau Anda memindahkan lokasi kode
aplikasi di host (reorganisasi folder, migrasi struktur direktori),
**bind-mount path di `docker-compose.yml` tidak otomatis ikut
pindah** — container akan tetap mount ke path lama (yang mungkin sudah
tidak ada isinya, atau lebih buruk, masih ada isi lama yang basi).
Selalu update &amp; verifikasi ulang path bind-mount setiap kali
struktur folder host berubah.

### Kebersihan rutin: image &amp; volume yang menumpuk

Setiap kali Anda `docker build` ulang (update kode, ganti base image),
image lama yang tidak lagi dipakai container manapun **tidak otomatis
terhapus** — ia jadi image "dangling" (`<none>:<none>`) yang tetap
memakan disk. Di server dengan banyak aplikasi yang sering di-deploy
ulang, ini bisa menumpuk sampai puluhan gigabyte tanpa disadari.
Bersihkan secara berkala (aman, tidak menyentuh apa pun yang masih
dipakai container aktif):

```bash
docker image prune -f     # hapus image dangling saja
docker volume prune -f    # hapus volume yang tidak dipakai container manapun
docker system df          # cek dulu berapa yang bisa direclaim sebelum eksekusi
```

**Jangan** pakai `docker system prune -a` tanpa pertimbangan — flag
`-a` juga menghapus image yang **masih ter-tag** tapi sedang tidak
dipakai container manapun saat ini (misalnya image versi lama yang
sengaja Anda simpan untuk rollback cepat). `docker image prune -f`
(tanpa `-a`) jauh lebih aman karena hanya menyasar image benar-benar
tanpa tag/dangling.

## Checklist sebelum lanjut

- [ ] Docker terinstall, network khusus (bukan default bridge) sudah
      dibuat untuk aplikasi web
- [ ] Semua container bind port ke `127.0.0.1` saja, tidak ada yang
      `0.0.0.0` kecuali benar-benar disengaja &amp; dipahami risikonya
- [ ] File `.env`/kredensial tidak pernah masuk ke git (`.gitignore`
      sudah mencakup `.env`, `*.env`)
- [ ] Anda tahu cara cek &amp; membersihkan image dangling secara rutin

## Selamat — infrastruktur inti selesai

Dengan Chapter 01–07, Anda sudah punya server yang: reliabel secara
storage (NVMe tidak akan freeze mendadak), aman diakses dari jarak jauh
(Tailscale, bukan port terbuka), aplikasi terekspos ke publik tanpa
port-forward (Cloudflare Tunnel), dan terisolasi rapi antar aplikasi
(Docker). Chapter selanjutnya menambahkan lapisan operasional: display
status fisik, monitoring otomatis, AI lokal, strategi backup
berlapis, dan keamanan lanjutan.

## Lanjut ke

➡️ [Chapter 08 — LCD OLED Status Display](../08-lcd-oled-status-display/) *(menyusul)*

⬅️ [Chapter 06 — Reverse Proxy &amp; Cloudflare Tunnel](../06-reverse-proxy-cloudflare-tunnel/)
