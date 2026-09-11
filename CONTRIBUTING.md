# Contributing

Thanks for considering a contribution. This started as one person's
documentation of their own Raspberry Pi 5 server — contributions that
keep that spirit (real experience, honest about failures) are welcome.

## Ways to contribute

- **Found an error or something outdated?** Open an issue or a PR directly — small fixes (typos, broken commands, outdated version numbers) don't need discussion first.
- **Have your own incident story?** Chapter 99 is explicitly designed as a living document. If you hit a real failure running a similar setup and solved it, a new "Insiden #N" entry following the existing format (symptom → wrong turn → root cause → fix → lesson) is very welcome.
- **Built this yourself and took photos?** `assets/photos/` is intentionally empty — real hardware photos (wiring, case, rack) are more valuable to readers than diagrams alone. PRs adding photos of your own build are welcome.
- **Adapting for Raspberry Pi 4, or a different SBC?** Happy to accept a variant note or a dedicated appendix section — just be clear about what's different, don't rewrite the RPi5-specific chapters (like Chapter 03's NVMe/HMB content) to be generic if the underlying hardware behavior actually differs.
- **New chapter idea?** Open an issue first to discuss scope before writing — this keeps the tutorial from sprawling into topics unrelated to running a reliable homelab server.

## Ground rules for any PR

1. **No real domain names, IP addresses, or identifying business details.** Everything in this tutorial is generalized on purpose (see the "Ground rules" section in the main README). Use placeholders (`example.com`, `192.0.2.10`, "App A/B/C") or RFC 5737 documentation ranges (`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`) for any new example.
2. **No secrets, ever** — not even redacted/fake-looking ones that could be mistaken for real. `.env`, tokens, passwords: always `<PLACEHOLDER>`.
3. **Keep the two-depth structure**: a Quick Start (copy-paste) section and a "Kenapa Begini" / deep-dive section explaining *why*. Don't add a chapter that's just commands with no explanation, or just theory with no runnable steps.
4. **Verify commands actually work before submitting** — this tutorial's whole premise is that it's grounded in real, tested experience, not copy-pasted-from-elsewhere instructions.
5. Diagrams: use Mermaid inline (see `assets/diagrams/README.md` for why), not separate image files, unless it's a real photo.

## Language

Tutorial content is in Bahasa Indonesia; the root `README.md` is in
English for discoverability. If you want to contribute an English
translation of a chapter, open an issue first so we can agree on
where translated chapters should live (likely `docs/en/`) before you
put in the work.
