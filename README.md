# DJOS Optimizer

DJOS Optimizer turns the official **Fedora KDE Plasma Desktop** (Fedora 44 or newer) into a PC for DJs and
music production. It is a single package, `djos-optimizer`, installed on top of a normal Fedora. Fedora and
RPM Fusion keep the system itself up to date. If you remove the package, you get a plain Fedora back.

## What it does

- **Real-time audio**: kernel options `preempt=full threadirqs usbcore.autosuspend=-1`, tuned profiles `djos`
  and `djos-balanced` (the Performance and Balanced power profiles use them), high priority for sound card and
  USB interrupts, real-time and locked-memory limits for the `audio` group, PipeWire and WirePlumber settings
  for low latency, and no power saving on sound cards.
- **NVIDIA**: installs the driver from RPM Fusion and sets up the Secure Boot key for you. You see one blue
  confirmation screen at the next restart.
- **DJOS look**: the **DJOS Glass** theme: a transparent top bar with the DJOS Launchpad (all your apps, search,
  arrange and hide them, add them to the dock), the menu of the active app and the numbers a DJ wants to see (audio
  latency, CPU, GPU, RAM, temperature, and SET while you play), the DJOS dock with the Mac zoom effect
  (drag apps in, out or around; it hides when a window touches it, so you keep the whole screen), dark glass windows
  with colored round buttons on the right (Windows order), rounded menus and matching app icons in macOS blue,
  smooth and fast animations (Mac-style interface, nothing from Apple inside).
  Papirus Dark icons, the Inter font, wallpapers, and DJOS boot, login and lock screens. The
  classic DJOS theme is still in the theme picker. Each monitor runs at its highest refresh rate.
- **DJOS Center**: sound cards (the main one, and the sample rate, buffer and resulting latency of each), sample rate and buffer, a real-time checklist, performance, updates, apps and
  plugins, **Which App?** (what to use for each job: cut a track, fix tags, record a set…) and music disks. It also
  appears in System Settings under DJOS.
- **DJOS Preview**: listen to tracks instantly. Right-click tracks or a folder in Dolphin > **Preview (DJOS)**, or
  open it from the menu. Space plays and pauses at once, the arrow keys move between tracks (it keeps playing) and
  seek, and the whole waveform (bass blue, mids orange, highs white) shows in a moment. It plays on the desktop
  sound output at low priority, and it never starts by itself while a set is playing.
- **DJOS Self-Test**: one click checks the real-time setup, NVIDIA, displays, sound cards and DJ controllers,
  and plays through your sound card to count dropouts.
- **DJ controllers**: detects controllers whose sound card Linux doesn't know yet and offers a compatible mode.
- **Richie DJ**: installed and kept up to date automatically, and never replaced while it's open.
- **Apps**: Ardour, Carla, Audacity, Puddletag (like Mp3tag), Kid3, Picard, SoundConverter, Sonic Visualiser,
  Haruna and qpwgraph, plus LV2/VST3/CLAP plugins (LSP, x42, Calf, ZAM, ZynAddSubFX) and latency tools. You can
  remove any of them without removing DJOS. DJOS Center installs more with one click, such as Mixxx, LosslessCut
  (cut MP3s without re-encoding, like mp3DirectCut), Bitwig Studio, REAPER, OBS Studio and plugin packs. The app menu
  starts with DJ, Produce, Edit & Tag and Record & Stream, and folders open in Dolphin as a list with size and date.

## Install

You need:

- A fresh **Fedora KDE Plasma Desktop 44** or newer. The Atomic versions (Kinoite) are not supported.
- An internet connection. No GitHub account is needed.

Open **Konsole** and type (or paste) this command:

```bash
curl -fsSL https://raw.githubusercontent.com/DjRichieValdivia/DJOS/main/bootstrap/install.sh -o djos-install.sh && bash djos-install.sh DjRichieValdivia
```

It downloads the installer and runs it (it asks for your password). It takes 10 to 40 minutes, depending on your
internet speed, and does the following:
   - checks that this is Fedora KDE 44 or newer
   - checks that it can reach the DJOS downloads (they are public)
   - turns on RPM Fusion
   - updates Fedora
   - installs `djos-optimizer`
   - installs the NVIDIA driver, if you have an NVIDIA card
   - installs Richie DJ
   - asks whether to remove programs a DJ PC doesn't need

   If anything fails, fix what the message says and run the command again. It continues where it
   stopped. A copy of everything it shows is saved in `~/djos-install.log`.

When it finishes, restart the PC.

**NVIDIA with Secure Boot:** during that restart, a blue screen says **Press any key to perform MOK
management**. Press the space bar within a minute. The menu starts on **Continue boot**, so don't press Enter right
away: use the arrow keys to choose **Enroll MOK**, then **Continue**, then **Yes**. Type the password `djosdjos`
(the keyboard uses the US layout on this screen), then choose **Reboot**. This happens only once. If you miss it,
the PC starts as usual after a minute and the blue screen comes back at the next restart.

**Windows on another disk:** DJOS adds **Windows** to the boot menu if the menu doesn't have it yet. If Windows
uses BitLocker, DJOS leaves it out (started from that menu, Windows would ask for its recovery key every time):
start it with your PC's boot menu key instead (F12 on Gigabyte boards).

## Updates

Updates are automatic, and nothing ever runs while a set is playing:

- **Fedora updates** are downloaded and prepared in the background, but they're installed only when you choose
  **Install & restart** or **Install & shut down** in DJOS Center → Updates. Nothing installs by itself
  when the PC starts.
- **Flatpak apps** update in the background.
- **Richie DJ** updates when it's closed.
- **DJOS Optimizer** updates itself when a new version is published.
- A **new Fedora version** (for example, 45) is offered in DJOS Center four weeks after its release, and
  only once RPM Fusion's NVIDIA driver supports it. It's never installed automatically. Discover doesn't offer it
  (DJOS turns that off, together with Discover's own update notifications).
- If a set starts while DJOS is downloading, the download stops and continues later. On a metered connection (a
  phone hotspot) DJOS doesn't download by itself; **Check now** still does.

You can also update from Konsole:

```bash
/usr/libexec/djos/update          # show what's pending
sudo dnf upgrade --refresh        # the normal Fedora update
```

## Uninstall

```bash
sudo dnf remove --no-autoremove djos-optimizer
```

Then restart. This undoes everything DJOS changed:

- deletes its files
- removes its kernel options (and gives back the value you had before for the same option, e.g. `preempt=`)
- restores Fedora's boot screen, power profiles and services, and removes the Windows entry DJOS added to the
  boot menu
- deletes `/etc/djos` (with a saved GitHub access, if this PC ever needed one) and the downloaded Richie DJ update
  data (about 4 GB)
- deletes the sample rate and buffer you chose in DJOS Center (Fedora's audio defaults come back)
- gives you back Fedora's desktop the next time you log in, if you still have the DJOS look

`--no-autoremove` keeps the apps and plugins that came with DJOS (Ardour, Carla, Audacity, the LV2/VST3/CLAP
plugins and the rest, about 115 packages), so your DAW and Carla sessions keep working. Without it
(`sudo dnf remove djos-optimizer`), dnf removes them too; to keep only some, mark them as yours first, for example
`sudo dnf mark user ardour9`.

Some things stay after you uninstall:

- **Richie DJ**, in `/opt/richiedj`.
- **Your music disks**: the read-only entries marked `# djos-music` in `/etc/fstab` and their `/mnt/music-*`
  folders. Delete those lines if you don't want them.
- **Your user in the `audio` and `pipewire` groups.**
- **Programs removed by the optional cleanup** during the install. Reinstall any of them with `sudo dnf install`.
- **Fedora updates DJOS had downloaded but not installed.** `sudo dnf5 offline clean` deletes them.
- **The NVIDIA driver and RPM Fusion.** They are normal Fedora packages.
- **A global theme you picked yourself.** DJOS leaves it alone. If the panel still shows missing icons, run this
  as your user (or pick "Fedora" in System Settings → Colors & Themes → Global Theme and tick "Desktop and window
  layout"):

  ```bash
  plasma-apply-lookandfeel -a org.fedoraproject.fedora.desktop --resetLayout
  ```

## For developers

| Path | What it is |
|---|---|
| `system/` | every file the package installs, at its final path |
| `packaging/djos-optimizer.spec` | the RPM recipe; the `%files` list and the list of services are generated from `system/` |
| `packaging/build-rpm.sh` | builds the RPM in a `fedora:44` container and runs rpmlint, dependency and file-conflict checks |
| `packaging/lint.sh` | `bash -n` and shellcheck for the scripts |
| `packaging/VERSION` | the package version |
| `packaging/ARCHITECTURE.md` | paths and interfaces between the parts |
| `bootstrap/install.sh` | the first-install script |
| `.github/workflows/build.yml` | builds and publishes the package |

To build locally (needs podman), run this command. The RPM ends up in `dist/`.

```bash
DJOS_OWNER=owner sh packaging/build-rpm.sh
```

To publish a release:

1. Raise `packaging/VERSION`. PCs only pick up a build whose version is higher than the one they have.
2. Push. CI publishes `ghcr.io/<owner>/djos-optimizer:<version>` and `:latest`.
3. For a GitHub Release with the RPM and `install.sh`, push a `vX.Y.Z` tag that matches `packaging/VERSION`.
