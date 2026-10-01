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
  (`dnf-makecache`, `fstrim`, `plocate-updatedb`, `raid-check`, the DJOS updater). Never run big updates while the user may be playing.
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
  other IRQs (and new ones: `/proc/irq/default_smp_affinity`) go to E-cores (re-run on hot-plug by
  `91-djos-rtirq.rules`). `irqbalance` is turned off (on install, and once on upgrade since 2.5.2; restored to
  Fedora's default on removal): it moved those interrupts every 10 s.
- PipeWire 48 kHz, quantum 256 (min 32) (`/usr/share/pipewire/*.conf.d/50-djos.conf`); the rate is fixed
  (`allowed-rates = [ 48000 ]`: switching rates reconfigures the card and many cards "pop"; everything else is
  resampled at quality 10). DJOS Center > Audio sets the rate, buffer and an optional "follow the rate of what's
  playing" (bit-perfect, may pop) in `~/.config/pipewire/pipewire.conf.d/60-djos-user.conf` + `pw-metadata`, and
  shows what each card is running at now (`/proc/asound/card*/pcm*/sub*/hw_params`, owner pid). Audio > Sound cards:
  the main card (default sink, `priority.session/driver = 3000`) and, per card, a fixed rate / buffer / PipeWire
  margin while it plays (`node.force-rate`, `node.force-quantum`, `api.alsa.headroom` in
  `~/.config/wireplumber/wireplumber.conf.d/60-djos-sound-cards.conf`, choices in `~/.config/djos/sound-cards.json`;
  applying restarts WirePlumber and is refused while a set plays) with the resulting latency (buffer + margin) / rate.
  `/usr/libexec/djos/audio-now` prints what plays now (per open output: rate, buffer incl. margin, ms, owner, main;
  `set` while a set plays; `richiedj` = what Richie DJ 1.10+ publishes once a second in
  `$XDG_RUNTIME_DIR/richiedj-status.json`: device, type, rate, buffer, latencyMs, dropouts, cpu, playing, recording)
  for the top-bar widget and the DJOS Center overview. HDMI/DisplayPort cards only offer the rates the monitor's ELD
  accepts (`/proc/asound/cardN/eld#*`, usually up to 48 kHz). WirePlumber never
  suspends ALSA outputs (`52-djos-no-suspend.conf`, `session.suspend-timeout-seconds = 0`: closing/reopening after
  5 s of silence popped on every new sound); webcam microphones (`device.form-factor = "webcam"`) get a low priority
  so the audio interface is the default input (`53-djos-webcam-mic.conf`; a user's own choice still wins). Users are in groups `audio` (rtprio 95, memlock unlimited,
  `/etc/security/limits.d/95-djos-audio.conf`) and `pipewire`; `snd_hda_intel power_save=0`; USB audio devices never
  autosuspend (`90-djos-audio.rules`); no volume-change "blip" (`/etc/xdg/plasmaparc` `AudioFeedback=false`); no system event sounds (USB device
  added/removed, dialogs, charger, trash…: `desktop-setup` drops `Sound` from those events once per user in
  `~/.config/<app>.notifyrc`, keeping the popups; a user's own setting wins).
- No background mail/calendar engine: `desktop-setup` turns off the `org.kde.kalendarac` autostart for each user (it
  started Akonadi with MySQL and ~15 agents, >1 GB RAM, at every login); opening KMail/KOrganizer still starts it.
  `djos.menu` also hides the KDE PIM helper tools (theme editors, import/export, Sieve, KTnef, GnuPG log).
- Pops/dropouts checklist (also in the Self-Test and DJOS Center > Audio): card `state` in `pw-cli info <sink id>` (should not go back to "suspended"), its real rate
  in `/proc/asound/cardN/pcm0p/sub0/hw_params`, `pw-metadata -n settings` (clock.rate / allowed-rates), `pw-top`
  (ERR column), and USB layout (`lsusb -t`): a webcam or hub sharing the audio interface's xHCI controller can cause
  dropouts; a port on another controller is better.
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
- Global theme `org.djos.glass` "DJOS Glass" (the default since 2.3: Mac-style interface only, no Apple assets, blue
  accent): a transparent top bar (the DJOS logo opens the DJOS Launchpad `org.djos.launchpad`, also Meta and the dock
  tile: full-screen grid from `/usr/libexec/djos/launchpad-apps`, search, pages, drag to reorder, right-click Add to
  Dock / Hide, power buttons; it changes the dock's launchers through `evaluateScript`; its button is the plasmoid's
  *full* representation, shown inline: as a compact one Plasma 6.7 drew nothing), the active app's name in bold
  `org.djos.appname` (TasksModel activeTask; click: Hide / Quit every window of that app) and its menu
  `org.kde.plasma.appmenu`, the DJOS Stats widget `org.djos.stats` — audio latency of the output in use (Richie DJ's
  own latency and a DROPS counter, red for a minute after a new dropout, while Richie DJ is open), CPU, GPU, RAM, CPU
  temperature from ksystemstats sensors, "SET" while a set plays; click for details, right-click to choose —,
  tray, clock) and the DJOS dock `org.djos.dock` (`/usr/share/plasma/plasmoids/
  org.djos.dock`, QML on `org.kde.taskmanager` TasksModel: macOS-style magnification (icons drawn once at full size
  and scaled on the GPU), app name label, running dot / blue pill for the active app, launch bounce, right-click
  menu, drag to reorder or out to remove, drop .desktop files to add, files onto an app to open, onto the trash to
  delete; Launchpad and trash; its panel is taller than the dock and hides when a window touches it, "dodge
  windows"); Plasma style `djos-glass` (transparent panels, no panel
  blur/contrast, 12 px rounded popups; the rest falls back to Breeze); colors `DJOSGlass`; window decoration Aurorae
  v2 `__aurorae__svg__DJOSGlass` (`/usr/share/aurorae/themes/DJOSGlass`, colored round buttons on the right in
  Windows order: `ButtonsOnRight=IAX` in `/etc/xdg/kwinrc`, which is global for every theme; GTK apps and Chrome get
  it from KDE's gtkconfig only after a KConfig change signal); magic lamp minimize. The classic `org.djos.desktop`
  stays in the theme picker. Icons `Papirus-Dark-DJOS` (Papirus' blue folders; `FOLDER_COLOR`
  in `branding/gen-links.sh`), fonts Inter / JetBrains Mono, wallpapers
  `/usr/share/wallpapers/DJOS*`, splash (DJOS Glass has its own: black, white logo, thin white bar), Plymouth theme
  `djos` (white logo on black), login screen with the DJOS-Glass wallpaper, Konsole scheme `DJOS` (neutral greys). The
  `djos` icon in `Papirus-Dark-DJOS` is the blue-violet Glass logo (the orange one stays in hicolor). Art: `branding/gen-glass.py` (decoration, Plasma
  style, app icon tiles, wallpaper, previews) and `branding/gen-links.sh` (icon links). `djos-desktop.service` (user) applies the look once per user
  and design version (`~/.local/state/djos/desktop-v4`) and sets each monitor to its highest refresh rate
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
