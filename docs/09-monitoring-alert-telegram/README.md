# 09 — Monitoring & Auto-Alert Telegram

## Quick Start

**1. Buat bot Telegram** — chat ke [@BotFather](https://t.me/BotFather)
di Telegram, `/newbot`, ikuti instruksi, simpan **bot token** yang
diberikan. Dapatkan juga **chat ID** Anda (chat ke
[@userinfobot](https://t.me/userinfobot) untuk lihat ID Anda sendiri).

**2. Fungsi kirim pesan sederhana** (`scripts/telegram-notify.sh.example`):

```bash
#!/bin/bash
# Simpan token & chat ID di file terpisah yang TIDAK di-commit ke git
source /etc/telegram-bot.env   # berisi BOT_TOKEN=... CHAT_ID=...

send_telegram() {
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="$1" \
    -d parse_mode="Markdown" > /dev/null
}
```

**3. Script health-check inti** (`scripts/health-check.sh.example`) —
jalankan tiap beberapa menit lewat cron:

```bash
#!/bin/bash
source /path/ke/telegram-notify.sh
STATE_FILE="/tmp/health-check-state"
mkdir -p "$(dirname "$STATE_FILE")"

check_and_alert() {
  local key="$1" current_status="$2" message="$3"
  local last_status
  last_status=$(grep "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2)

  if [ "$current_status" != "$last_status" ]; then
    send_telegram "$message"
    sed -i "/^${key}=/d" "$STATE_FILE" 2>/dev/null
    echo "${key}=${current_status}" >> "$STATE_FILE"
  fi
}

# Contoh cek 1: container Docker down
for container in app-a app-b; do
  status=$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null)
  if [ "$status" != "true" ]; then
    check_and_alert "container_${container}" "down" "🚨 Container *${container}* DOWN!"
  else
    check_and_alert "container_${container}" "up" "✅ Container *${container}* kembali normal."
  fi
done

# Contoh cek 2: disk penuh
disk_usage=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$disk_usage" -ge 85 ]; then
  check_and_alert "disk" "full" "🚨 Disk terpakai ${disk_usage}%!"
else
  check_and_alert "disk" "ok" "✅ Disk kembali normal (${disk_usage}%)."
fi
```

```bash
crontab -e
# */5 * * * * /path/ke/health-check.sh >> /path/ke/health.log 2>&1
```

## Kenapa Begini

### Kenapa Telegram, bukan email

Email untuk alert server punya masalah nyata: **latensi tidak
terprediksi** (bisa masuk spam folder, delivery bisa delay beberapa
menit sampai jam tergantung provider), dan orang jarang cek email
secara real-time di HP. Notifikasi Telegram masuk sebagai push
notification instan, dan API-nya sangat sederhana (satu `curl` request,
tidak perlu setup SMTP server sendiri yang justru menambah satu lagi
komponen yang bisa gagal).

### Prinsip paling penting: alert HANYA saat status BERUBAH

Ini pembeda antara sistem monitoring yang benar-benar dipakai vs yang
di-mute setelah 2 hari. Kalau script health-check mengirim pesan
**setiap kali dijalankan** (misalnya tiap 5 menit) selama kondisi
bermasalah masih berlangsung, Anda akan menerima puluhan notifikasi
untuk **satu insiden yang sama** — dan reaksi manusiawi terhadap spam
seperti itu adalah mematikan notifikasi sepenuhnya, yang berarti alert
BENERAN yang penting nanti juga tidak akan Anda lihat.

Pola `check_and_alert` di atas menyimpan state terakhir tiap pengecekan
ke file, dan **hanya mengirim pesan kalau state berubah** dari
sebelumnya (baik dari OK→bermasalah, MAUPUN dari bermasalah→OK — Anda
tetap ingin tahu kapan masalah selesai, bukan cuma kapan mulai). Hasil:
satu insiden = maksimal dua notifikasi (mulai &amp; selesai), bukan
puluhan.

### Kenapa bot dua arah (bisa di-query), bukan cuma kirim notifikasi

Selain menerima alert otomatis, bot Telegram yang sama bisa
dikonfigurasi menerima **command** dari Anda (`/status`, `/restart_app_a`,
dll) lewat polling atau webhook ke Telegram Bot API. Ini mengubah bot
dari sekadar "corong notifikasi satu arah" jadi **kontrol jarak jauh
ringan** — berguna kalau Anda perlu cek status atau restart sesuatu
saat sedang tidak di depan laptop tapi punya HP di tangan.

Implementasi dasarnya: script Python/Node kecil yang polling endpoint
`getUpdates` dari Bot API, mencocokkan teks command yang masuk, lalu
menjalankan action yang sesuai (dengan validasi ketat siapa yang boleh
mengirim command — cek `chat_id` pengirim cocok dengan chat ID Anda
sendiri, supaya bot tidak bisa dikontrol orang lain kalau token bocor).

### Apa saja yang layak di-monitor (daftar praktis)

- **Container Docker down** — contoh di atas.
- **Disk penuh** — ambang batas realistis (85% sudah cukup jadi
  peringatan dini sebelum benar-benar 100%).
- **Suhu CPU/NVMe tinggi** — indikasi pendinginan bermasalah sebelum
  terjadi thermal throttling.
- **Unit systemd berstatus `failed`** — `systemctl --failed` yang
  hasilnya bukan kosong.
- **IP publik berubah** — kalau Anda tidak pakai domain dinamis DNS
  dan bergantung pada IP tetap untuk sesuatu, perubahan IP ISP perlu
  diketahui segera.
- **Service kritis diam-diam ke-disable** — `systemctl is-enabled
  <service>` yang tidak lagi `enabled` padahal seharusnya selalu aktif
  setiap boot.

### Kenapa interval singkat (`*/5 menit`), bukan tiap jam

Untuk deteksi dini masalah kelas "container crash" atau "disk mendadak
penuh", interval 5 menit adalah keseimbangan wajar antara **kecepatan
deteksi** (maksimal 5 menit delay sebelum Anda tahu) dan **beban
sistem** (script health-check yang ringan tidak akan membebani server
meski jalan tiap 5 menit). Untuk pengecekan yang lebih berat (misalnya
snapshot lengkap kondisi sistem untuk arsip/inventory), interval lebih
jarang (`*/15 menit` atau tiap jam) lebih masuk akal.

## Checklist sebelum lanjut

- [ ] Bot Telegram dibuat, token &amp; chat ID tersimpan di file
      terpisah (BUKAN hardcode di script, BUKAN commit ke git)
- [ ] Script health-check jalan lewat cron, terbukti mengirim
      notifikasi test yang benar
- [ ] **Terverifikasi**: menjalankan check yang sama berulang kali
      TIDAK mengirim notifikasi berulang selama state tidak berubah
- [ ] Minimal 3-4 kategori cek dari daftar di atas sudah aktif

## Lanjut ke

➡️ [Chapter 10 — AI Lokal (Ollama)](../10-ai-lokal-ollama/)

⬅️ [Chapter 08 — LCD OLED Status Display](../08-lcd-oled-status-display/)
