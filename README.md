# RPi 5 Homelab Tutorial

**Build a reliable, production-grade home server on a Raspberry Pi 5 — from bare metal to Docker, Tailscale, Cloudflare Tunnel, local AI, and a battle-tested backup strategy. Written from real production experience, including the incidents that almost killed it.**

> 🇬🇧 This README is in English so the project is discoverable globally.
> 🇮🇩 The full tutorial content is written in **Bahasa Indonesia** — chapter titles below are glossed in English so non-Indonesian readers can still follow the structure and use translation tools per-page if needed. A full English translation may follow if there's interest.

## Why this tutorial is different

Most homelab tutorials stop at "install Docker, done." This one doesn't, because reality didn't stop there either:

- A specific class of NVMe SSD (DRAM-less) can cause a Raspberry Pi 5 to **freeze permanently under write load** — and the fix isn't in most tutorials because most people never hit it. We did. Chapter 03 covers the full root-cause analysis and the exact kernel boot parameters that fix it.
- A power outage cascaded into filesystem corruption that took down SSH, nginx, the display manager, and networking — all from **one single symlink pointing at the wrong file**. Chapter 99 documents the entire incident, symptom by symptom, the wrong turns taken during investigation, and the real fix.
- Every operational decision here — backup layering, alerting philosophy, even how we do server maintenance with AI assistance — comes from something that actually broke first.

If you want a server that survives real failures (not just the happy path), this is the tutorial.

## What this server runs (generalized)

```
Internet
   │
   ▼
Cloudflare Tunnel  (no open inbound ports, no port-forwarding on your router)
   │
   ▼
nginx (reverse proxy, multi-domain)
   │
   ├──▶ Docker containers (one app per container, bound to 127.0.0.1 only)
   │        │
   │        ▼
   │     MariaDB (multi-database, least-privilege backup user)
   │
   └──▶ Tailscale mesh VPN  (admin access, no public SSH exposure)

Local extras: OLED status display · Telegram alert bot · on-device Ollama AI
```

A single Raspberry Pi 5 (8GB) runs multiple production web apps, background bots, a database, and a full monitoring/alerting stack — reliably, with documented recovery procedures for when (not if) something goes wrong.

## Table of contents

> Chapters marked ✅ have full content. Chapters marked 🚧 are planned (structure only) — this is a living document, core infrastructure chapters are being written first.

| # | Chapter | Status |
|---|---|---|
| 00 | [Pengantar](docs/00-pengantar/) — Introduction & architecture overview | ✅ |
| 01 | [Hardware & Persiapan](docs/01-hardware-persiapan/) — Hardware shopping list & prep | ✅ |
| 02 | [Instalasi OS & Setup Dasar](docs/02-instalasi-os-dasar/) — OS install & base setup | ✅ |
| 03 | [Storage & Reliabilitas NVMe](docs/03-storage-nvme-reliability/) — NVMe reliability (**the big one**) | ✅ |
| 04 | [Database Arsitektur](docs/04-database-arsitektur/) — Database architecture | ✅ |
| 05 | [Remote Access — Tailscale](docs/05-remote-access-tailscale/) | ✅ |
| 06 | [Reverse Proxy & Cloudflare Tunnel](docs/06-reverse-proxy-cloudflare-tunnel/) | ✅ |
| 07 | [Docker Infrastruktur](docs/07-docker-infrastruktur/) | ✅ |
| 08 | [LCD OLED Status Display](docs/08-lcd-oled-status-display/) | ✅ |
| 09 | [Monitoring & Auto-Alert Telegram](docs/09-monitoring-alert-telegram/) | ✅ |
| 10 | [AI Lokal (Ollama)](docs/10-ai-lokal-ollama/) — On-device AI | ✅ |
| 11 | [Strategi Backup Berlapis](docs/11-backup-strategi-4-lapis/) — 4-layer backup strategy | ✅ |
| 12 | [Keamanan Lanjutan](docs/12-keamanan-lanjutan/) — Advanced hardening | ✅ |
| 13 | [Operasional & Dokumentasi (AI-assisted)](docs/13-operasional-dokumentasi-ai-assisted/) | ✅ |
| 99 | [Studi Kasus Insiden](docs/99-studi-kasus-insiden/) — Real incident case studies | ✅ |
| — | [Lampiran](docs/lampiran/) — Glossary, cheat-sheet, FAQ | 🚧 |

## How to use this tutorial

Every chapter is written for **two readers at once**: if you just want to copy-paste and get moving, there's a quick-start section. If you want to understand *why* — and what breaks if you get it wrong — read the deep-dive section below it. That second part is where the real value is; skipping it is how people end up re-learning our incidents the hard way.

## Ground rules for this repo (why some things are placeholders)

This tutorial is generalized from a real production server. Domain names, IP addresses, and business-specific project names are always replaced with placeholders (`example.com`, `192.0.2.10`, "App A/B/C"). Secrets are never included — not redacted, never present in the first place. If you're adapting the scripts in `scripts/`, replace every `<PLACEHOLDER>` before running anything.

## License

MIT — see [LICENSE](LICENSE). Use it, fork it, build your own.

## Status

This repository is currently in **private draft** while content is written and reviewed. **All 16 core chapters (00–13, 99) are now complete.** Remaining: the appendix (glossary, cheat-sheet, FAQ), a full editorial sanitization pass, and diagrams/photos before this goes public.
