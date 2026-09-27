# DJOS — guide for Claude

You are running on **DJOS**, a Fedora atomic (bootc) desktop for DJs and music producers, built on Universal Blue
(`ghcr.io/ublue-os/kinoite-nvidia`) with KDE Plasma. Reply in the language the user writes in. The UI of DJOS and
its apps is English (US).

## How DJOS works (read before changing anything)
- The OS is an **image**. `/usr` is read-only; never try `dnf install` or writing to `/usr` (it fails by design).
- The image is built daily by GitHub Actions from the **private** repo `<owner>/djos` (the owner is the account in
  `bootc status` → `ghcr.io/<owner>/djos:<fedora version>`). To change the OS: clone the repo
  (`gh auth login`, then `gh repo clone <owner>/djos`), edit, commit, push. GitHub builds it; the PC downloads it
  in the background and applies it on the next restart. Nothing is ever reinstalled.
- Updates: `rpm-ostreed-automatic` stages OS updates (applied on restart; the previous version stays in the boot
  menu). `djos-app-update` updates private apps listed in `/etc/djos/apps.conf`. The menu app **Update DJOS**
  does both on demand. Private registry access lives in `/etc/ostree/auth.json` (root only, set by
  **Set Up DJOS Updates**).
- Installing software without touching the OS:
  - GUI apps: **Discover** / `flatpak install flathub <id>`; curated audio apps: menu **Install Audio Apps**.
  - Arch/AUR packages: `paru` / `yay` (they run in an Arch distrobox named `arch`; installed apps show up in the menu).
  - Other distros/tools: `distrobox create`.
  - Only if truly needed at system level: `rpm-ostree install <pkg>` (layering, needs a restart) — prefer changing
    the image instead.

## Audio design (keep it this way)
- Kernel args `preempt=full threadirqs usbcore.autosuspend=-1`; `djos-rtirq` gives the xHCI controller that hosts a
  USB sound card FIFO 90 and the onboard HDA FIFO 85, on a P-core; other IRQs go to E-cores.
- tuned profile `djos` (latency-performance, HDA codec never powered down); PipeWire 48 kHz, quantum 256
  (min 32); users are in groups `audio` (rtprio 95, memlock unlimited) and `pipewire`.
- `gig-guard`: updates/maintenance never run while a set is playing (Richie DJ holds `/dev/cpu_dma_latency`).
- Measure latency with `sudo djos-latency-test` (cyclictest, rtla, hwlatdetect, xrun counter).

## Richie DJ (private app)
- Installed in `/var/opt/richiedj`, updated from the private image `ghcr.io/<owner>/richiedj:latest`.
- Settings/library: `~/.config/Richie DJ/`; recordings: `~/Documents/Richie DJ/Recordings/`.
- Audio output "ALSA Direct" opens the card directly (it asks PipeWire to release it via ReserveDevice1).

## Diagnostics
- `journalctl -b`, `journalctl -b -u djos-*`, `systemctl --failed`, `bootc status`, `rpm-ostree status`
- NVIDIA: `cat /proc/driver/nvidia/version`, `mokutil --sb-state`, `mokutil --test-key /etc/pki/akmods/certs/akmods-ublue.der`
- Audio: `pw-top`, `wpctl status`, `aplay -l`, `cat /proc/asound/cards`, `qpwgraph`

## Rules
- Never put personal data (names, emails, usernames, paths from the user's home), tokens, keys or passwords in the
  DJOS repo, commits or anything pushed. Tokens are typed by the user, never by you.
- Never change audio/real-time settings while the user may be playing a set; ask first.
- Destructive disk operations and Secure Boot / BIOS changes are done by the user, with your exact instructions.
