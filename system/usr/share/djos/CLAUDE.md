# DJOS — guide for Claude

You are running on **Fedora Linux KDE Plasma Desktop** (the official Edition, Fedora 44 or newer) with the
**DJOS Optimizer** installed: one RPM (`djos-optimizer`) that tunes a normal Fedora for DJs and music producers.
Reply in the language the user writes in. The UI of DJOS and its apps is English (US).

## How this system works (read before changing anything)
- It is a **normal, non-atomic Fedora**: `dnf` works (`sudo dnf install <pkg>`), `/usr` belongs to RPM packages,
  Discover and PackageKit handle updates. There is no rpm-ostree, bootc, ujust or Universal Blue here.
- Fedora and **RPM Fusion** (free + nonfree) keep the system updated. DJOS only adds tuning, the look, DJOS Center,
  the Self-Test, controller helpers and the delivery of Richie DJ.
- Files owned by `djos-optimizer` (`rpm -ql djos-optimizer`) are replaced on every update: never edit them in place.
  Local changes go in `/etc` (the package's `/etc` files are `%config(noreplace)`) or in the user's home. Permanent
  changes to DJOS itself are made in its GitHub repo `DJOS` (the owner is `DJOS_OWNER` in
  `/usr/share/djos/source.conf`), which builds and publishes the RPM.
- `sudo dnf remove djos-optimizer` gives back a plain Fedora (kernel options, services, power profiles and boot
  screen are restored; Richie DJ stays in `/opt/richiedj`; Fedora's desktop comes back at the user's next login
  through the one-time `~/.config/autostart/djos-restore-desktop.desktop`).
- Setup logic: `/usr/libexec/djos/optimizer-setup install|upgrade|remove|posttrans|cleanup [--dry-run]` (run by the
  package scriptlets; `cleanup` removes apps a DJ PC doesn't need, never anything essential). Machine state is in
  `/var/lib/djos/`, machine config in `/etc/djos/`.

## Updates (never while a set is playing)
- `djos-update.timer` runs `/usr/libexec/djos/update check` (as root): downloads Fedora updates as a dnf5 **offline**
  transaction that is only installed when the user chooses "Install & restart/shut down" (DJOS Center > Updates or
  the DJOS Updates panel icon), updates Flatpaks, Richie DJ (`app-update`) and `djos-optimizer` itself, and offers
  a new Fedora release only 4 weeks after it ships and when RPM Fusion has the NVIDIA driver for it.
  Status: `/usr/libexec/djos/update status` (JSON in `/var/lib/djos/update-status.json`).
- `gig-guard` (exit 1 = a set is playing: Richie DJ holds `/dev/cpu_dma_latency`) blocks automatic maintenance
  (`dnf-makecache`, `fstrim`, the DJOS updater). Never run big updates while the user may be playing.
- Richie DJ and the optimizer download anonymously from ghcr.io (public images). Only if a registry asks for access
  is `/etc/djos/registry-auth.json` (root only, created by `/usr/libexec/djos/connect`, a GitHub login in the
  browser) used. Never print or copy that token.

## Installing software
- GUI apps: **Discover**, `flatpak install flathub <id>`, or `sudo dnf install <pkg>`.
- Curated DJ/production apps and plugin packs: **DJOS Center > Apps & Plugins** (`/usr/libexec/djos/flatpak-audio`;
  Flathub DAWs get the LinuxAudio plugin extensions of their runtime branch; `apps.json` has a "use it when" line
  per app and `guide.json` the "Which App?" page, by task). Native (recommended by the package): Ardour, Carla,
  Audacity, Puddletag, Kid3, Picard, SoundConverter, Sonic Visualiser, Haruna, qpwgraph and LV2/VST3/CLAP plugins
  (LSP, x42, Calf, ZAM, ZynAddSubFX). One click from Flathub: LosslessCut (lossless MP3 cut/split/join), Mixxx,
  Bitwig, REAPER, OBS Studio and more.
- DJOS Preview (`/usr/libexec/djos/preview`, Dolphin right-click > Preview (DJOS)): instant track preview with a
  3-band waveform; plays on the desktop output at low priority and never auto-starts during a set.
- Other distros/tools: `toolbox` or `distrobox` if the user installs them.

## Audio design (keep it this way)
- Kernel options `preempt=full threadirqs usbcore.autosuspend=-1`, set with `grubby` (also in `/etc/kernel/cmdline`
  and `GRUB_CMDLINE_LINUX` so new kernels keep them).
- tuned profiles `djos` (latency-performance, HDA codec never powered down) and `djos-balanced`; Plasma's power
  profiles map to them through `/etc/tuned/ppd.conf` (tuned-ppd's file, original saved in `/var/lib/djos/backup`).
- `djos-rtirq` gives the USB controller that hosts a sound card FIFO 90 and the onboard HDA FIFO 85, on a P-core;
  other IRQs go to E-cores (re-run on hot-plug by `91-djos-rtirq.rules`).
- PipeWire 48 kHz, quantum 256 (min 32) (`/usr/share/pipewire/*.conf.d/50-djos.conf`); users are in groups `audio`
  (rtprio 95, memlock unlimited, `/etc/security/limits.d/95-djos-audio.conf`) and `pipewire`; `snd_hda_intel
  power_save=0`; USB audio devices never autosuspend (`90-djos-audio.rules`).
- Measure: DJOS Self-Test (menu) and `sudo djos-latency-test` (cyclictest, rtla, hwlatdetect, xrun counter; needs
  `realtime-tests rtla stress-ng`).

## Richie DJ
- Installed in `/opt/richiedj`, updated from the image `ghcr.io/<owner>/richiedj:latest` by
  `/usr/libexec/djos/app-update` (only swapped while the app is closed).
- Settings/library: `~/.config/Richie DJ/`; recordings: `~/Documents/Richie DJ/Recordings/`.
- Audio output "ALSA Direct" opens the card directly (it asks PipeWire to release it via ReserveDevice1).

## NVIDIA
- RPM Fusion `akmod-nvidia` + `xorg-x11-drv-nvidia-cuda`; akmods rebuilds the driver for every new kernel. After
  an offline update (Install & restart / shut down) `djos-nvidia-offline.service` builds it before the restart.
  Install/repair: `sudo /usr/libexec/djos/nvidia-setup`; state: `/usr/libexec/djos/nvidia-setup --status`.
- Secure Boot: the driver is signed with this PC's key (`/etc/pki/akmods/certs/public_key.der`, from `kmodgenca`),
  which must be enrolled once: after `mokutil --import`, restart → blue screen "Press any key to perform MOK
  management" (60 s, then it boots normally) → any key → Enroll MOK → Continue → Yes → password `djosdjos` →
  Reboot. Check: `mokutil --sb-state`,
  `sudo mokutil --test-key /etc/pki/akmods/certs/public_key.der`, `cat /proc/driver/nvidia/version`, `nvidia-smi`.
- Build failures: `/var/cache/akmods/nvidia/*.log`; retry with `sudo akmods --force`, or boot the previous kernel.

## Diagnostics
- `journalctl -b`, `journalctl -b -u 'djos-*'`, `systemctl --failed`, `rpm -q djos-optimizer`, `cat /etc/os-release`
- Audio: `pw-top`, `wpctl status`, `aplay -l`, `cat /proc/asound/cards`, `qpwgraph`, `tuned-adm active`,
  `cat /proc/cmdline`, `ps -eLo rtprio,comm | grep irq/`
- Updates: `dnf5 offline status`, `/usr/libexec/djos/update status`

## Rules
- Never put personal data (names, emails, usernames, paths from the user's home), tokens, keys or passwords in the
  DJOS repo, commits or anything pushed. Tokens are typed by the user in the browser, never by you.
- Never change audio/real-time settings or install updates while the user may be playing a set; ask first.
- Destructive disk operations and Secure Boot / BIOS changes are done by the user, with your exact instructions.
- Don't edit files owned by other packages (check with `rpm -qf <file>`): use drop-ins or `/etc` overrides.

## Look and feel
- Global theme `org.djos.glass` "DJOS Glass" (the default since 2.3: Mac-style interface only, no Apple assets): top
  bar (DJOS menu, the active app's menu `org.kde.plasma.appmenu`, tray, clock) and a floating centered dock
  (Richie DJ first, Launchpad `kickerdash`, trash); colors `DJOSGlass`; window decoration Aurorae v2
  `__aurorae__svg__DJOSGlass` (`/usr/share/aurorae/themes/DJOSGlass`, traffic lights on the left: `ButtonsOnLeft=XIA`
  in `/etc/xdg/kwinrc`, which is global for every theme); magic lamp minimize. The classic `org.djos.desktop` stays
  in the theme picker. Icons `Papirus-Dark-DJOS` (orange folders), fonts Inter / JetBrains Mono, wallpapers
  `/usr/share/wallpapers/DJOS*`, splash, Plymouth theme `djos`. Art: `branding/gen-glass.py` (decoration, wallpaper,
  previews) and `branding/gen-links.sh` (icon links). `djos-desktop.service` (user) applies the look once per user
  and design version (`~/.local/state/djos/desktop-v3`) and sets each monitor to its highest refresh rate
  (`display-setup`). Plasma 6 writes a global theme's values to `~/.config/kdedefaults/`: a key in the user's own
  file (e.g. `library=` in `~/.config/kwinrc`) wins over it. Classic DJOS: `plasma-apply-lookandfeel -a
  org.djos.desktop --resetLayout`; back to Fedora's desktop:
  `plasma-apply-lookandfeel -a org.fedoraproject.fedora.desktop --resetLayout`.
- DJOS Center (`/usr/libexec/djos/center`, PySide6 + Kirigami QML in `/usr/share/djos/center`) is also listed in
  System Settings under the DJOS category.

## Music disks
- DJOS Center > Music Disks (`/usr/libexec/djos/setup-music-disk`) adds read-only automounts at
  `/mnt/music-<label>` (fstab lines tagged `# djos-music`). The disk with Fedora is never offered.

## DJ controllers whose sound card Linux doesn't know (e.g. Pioneer DDJ-FLX10, 2b73:0041)
- Their MIDI works; the audio interface is vendor-specific (class 255). `/usr/libexec/djos/controller-audio status`
  computes the channels of endpoints 0x01/0x82 from `wMaxPacketSize` and, only on an exact match with a kernel
  recipe of the same Pioneer family (DDJ-800, DDJ-SR2, DDJ-RB, DDJ-RR…), `enable` binds snd-usb-audio with that
  recipe via `new_id` (+ udev rule `/etc/udev/rules.d/90-djos-controller-audio.rules`, config
  `/etc/djos/controller-audio.conf`). UI: DJOS Center > Audio ("Try compatible mode", "Turn off",
  "Save device info" → `~/Desktop/djos-controller-info.txt` with `lsusb -v` and kernel messages).
- If no recipe matches, write a proper quirk from that info file (see sound/usb/quirks-table.h Pioneer entries).
  A patched snd-usb-audio module would have to be packaged as an akmod (signed with the same MOK key as NVIDIA).
  Ask the user to keep the master volume down when testing audio changes.
