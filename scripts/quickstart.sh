#!/bin/bash
# scripts/quickstart.sh
#
# Bootstrap otomatis untuk semua PAKET & TOOL yang dibahas di tutorial
# ini (Chapter 02, 05, 06, 07, 08, 09, 10, 12). Aman dijalankan ulang
# (idempotent) -- tidak akan merusak apa pun kalau dijalankan dua kali.
#
# APA YANG SENGAJA TIDAK DIOTOMATISKAN, DAN KENAPA:
#   - Konfigurasi NVMe/HMB (Chapter 03) -- parameter cmdline.txt/config.txt
#     WAJIB diverifikasi manual per unit hardware (drive & HAT berbeda-beda,
#     dan salah konfigurasi di sini bisa membuat sistem freeze/rusak).
#     Script ini TIDAK menyentuh /boot/firmware/* sama sekali.
#   - Pembuatan user/database MySQL spesifik (Chapter 04) -- butuh nama
#     aplikasi & password yang cuma Anda yang tahu.
#   - Login Tailscale, token Cloudflare Tunnel, token bot Telegram --
#     semua butuh interaksi manual (buka link, login, copy token) yang
#     tidak bisa & tidak boleh diotomatiskan lewat script.
#   - UFW enable & aturan spesifik (Chapter 02) -- dibiarkan manual supaya
#     Anda sadar betul port apa yang dibuka, bukan blind-apply dari script.
#
# Cara pakai:
#   chmod +x quickstart.sh
#   ./quickstart.sh
#
# Jalankan sebagai user biasa dengan akses sudo (BUKAN sebagai root
# langsung) -- konsisten dengan Chapter 02.

set -euo pipefail

bold() { echo -e "\033[1m$1\033[0m"; }
warn() { echo -e "\033[1;33m$1\033[0m"; }
ok()   { echo -e "\033[1;32m$1\033[0m"; }

echo
bold "=========================================================="
bold "  RPi 5 Homelab Tutorial -- Quickstart Installer"
bold "=========================================================="
echo
warn "⚠️  PERINGATAN PENTING SEBELUM LANJUT:"
warn "    Kalau server ini pakai NVMe SSD, BACA Chapter 03 dulu"
warn "    (docs/03-storage-nvme-reliability/) SEBELUM menaruh beban"
warn "    produksi apa pun. Script ini TIDAK menyentuh konfigurasi"
warn "    NVMe/HMB sama sekali -- itu wajib dicek manual per hardware."
echo
read -rp "Tekan ENTER untuk lanjut, atau Ctrl+C untuk berhenti dulu... "
echo

bold "[1/8] Update sistem..."
sudo apt update && sudo apt full-upgrade -y

bold "[2/8] Firewall & fail2ban (Chapter 02, 12)..."
sudo apt install -y ufw fail2ban
ok "  Terinstall. UFW BELUM di-enable -- atur rule Anda sendiri dulu"
ok "  (lihat Chapter 02), baru 'sudo ufw enable' manual."

bold "[3/8] MariaDB (Chapter 04)..."
sudo apt install -y mariadb-server
ok "  Terinstall. Jalankan 'sudo mysql_secure_installation' lalu buat"
ok "  database/user sesuai Chapter 04 -- itu bagian yang perlu manual."

bold "[4/8] Tailscale (Chapter 05)..."
if ! command -v tailscale &> /dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
else
  ok "  Sudah terinstall, dilewati."
fi
ok "  Jalankan 'sudo tailscale up' manual untuk login ke tailnet Anda."

bold "[5/8] nginx & cloudflared (Chapter 06)..."
sudo apt install -y nginx
if ! command -v cloudflared &> /dev/null; then
  ARCH=$(dpkg --print-architecture)
  curl -L "https://pkg.cloudflare.com/cloudflared-stable-linux-${ARCH}.deb" -o /tmp/cloudflared.deb
  sudo dpkg -i /tmp/cloudflared.deb
  rm -f /tmp/cloudflared.deb
else
  ok "  cloudflared sudah terinstall, dilewati."
fi
ok "  Buat tunnel lewat dashboard Cloudflare Zero Trust, lalu jalankan:"
ok "  sudo cloudflared service install <TOKEN_DARI_DASHBOARD_ANDA>"

bold "[6/8] Docker (Chapter 07)..."
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  ok "  Terinstall. LOGOUT & LOGIN ULANG supaya grup docker aktif."
else
  ok "  Sudah terinstall, dilewati."
fi
if ! docker network inspect webapps-network &> /dev/null; then
  docker network create --subnet=172.20.0.0/16 webapps-network || \
    warn "  Gagal buat network (mungkin subnet konflik) -- sesuaikan manual."
else
  ok "  Network 'webapps-network' sudah ada, dilewati."
fi

bold "[7/8] I2C + dependency OLED (Chapter 08)..."
sudo raspi-config nonint do_i2c 0
sudo apt install -y i2c-tools python3-pip python3-pil
pip3 install luma.oled psutil --break-system-packages 2>/dev/null || \
  warn "  pip install gagal -- coba manual: pip3 install luma.oled psutil --break-system-packages"

bold "[8/8] Ollama AI lokal (Chapter 10) & tools keamanan (Chapter 12)..."
if ! command -v ollama &> /dev/null; then
  curl -fsSL https://ollama.com/install.sh | sh
else
  ok "  Ollama sudah terinstall, dilewati."
fi
sudo apt install -y rkhunter clamav clamav-daemon debsums

echo
bold "=========================================================="
ok "  Instalasi paket selesai. Langkah manual yang MASIH perlu:"
bold "=========================================================="
cat <<'EOF'

  1. [WAJIB]  Chapter 03 -- cek & konfigurasi HMB/NVMe kalau pakai SSD
              NVMe. JANGAN skip ini kalau belum dicek.
  2. Atur & enable UFW (Chapter 02) sesuai kebutuhan Anda.
  3. Buat database + user MySQL per aplikasi (Chapter 04).
  4. `sudo tailscale up` -- login ke tailnet Anda (Chapter 05).
  5. Buat tunnel di dashboard Cloudflare, install token-nya (Chapter 06).
  6. Konfigurasi nginx per aplikasi (Chapter 06), docker-compose.yml
     per aplikasi (Chapter 07).
  7. Copy file scripts/*.example -> hilangkan ".example", isi semua
     <PLACEHOLDER>, jadwalkan lewat cron (Chapter 09, 11).
  8. Buat bot Telegram lewat @BotFather, isi token di
     /etc/telegram-bot.env (Chapter 09).
  9. fail2ban jail config (Chapter 12) -- copy contoh dari chapter,
     restart fail2ban, VERIFIKASI dengan tes ban IP dummy.

EOF
