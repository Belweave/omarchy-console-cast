# Console Cast for the Omarchy bar

Console Cast brings the built-in broadcast of a PlayStation® 5 (PS5®) or Xbox® Series X|S console into OBS Studio™ on your computer, with no capture card. This plugin puts it in the Omarchy bar.

The bar icon shows Console Cast's state at a glance:

| Icon | State |
| --- | --- |
| Crossed out, dimmed | Not installed |
| Crossed out | Off |
| Waves, dimmed | Starting |
| Waves | Ready |
| Waves, accent colour | Console connected |
| Waves, alert colour | Live |

Click it for the panel: Start and Stop, the two DNS addresses to enter on the console (with a copy button), your destinations and whether each is on, your licence status (trial days left or subscription), and a button that opens Console Cast.

## Requirements

- Omarchy 4 (the Quattro shell) on x86_64 or ARM64.
- Console Cast, installed with `curl -fsSL https://consolecast.app/install.sh | bash` or from https://consolecast.app/download. Without it the panel offers the download page.
- `wl-copy` (wl-clipboard) for the copy buttons; Omarchy includes it.

## Install

```sh
omarchy plugin add https://github.com/Belweave/omarchy-console-cast.git --enable
```

Move it in the bar if you like:

```sh
omarchy bar move belweave.console-cast --section right
```

## Use

- Left click the icon to open or close the panel; Escape closes it.
- **Start** starts Console Cast in the background (its tray icon appears; if its window is already open, it starts there). If Console Cast is running in pass-through, Start points the console's broadcast back at this computer.
- **Stop** stops Console Cast; the console has no DNS until you start it again. While the console's picture or a destination is on air, it asks for a second click.
- On the console, set Manual DNS to the two addresses the panel shows, for example primary `192.168.1.20` and secondary `0.0.0.0`.
- Destinations and stream keys are set in Console Cast itself (**Open Console Cast**).

## What it does on your computer

The plugin runs inside the Omarchy shell with your user's rights. It:

- asks Console Cast on this computer for its state (`http://127.0.0.1:7777`, every 5 seconds while Console Cast runs, every 2 seconds while the panel is open, every 15 seconds while it is off);
- runs `consolecast version --json` to see whether Console Cast is installed, and `consolecast license status` while the panel is open and Console Cast is off;
- starts `console-cast --background` (or `consolecast up` when the app is already open) when you press Start, and `console-cast` when you press Open Console Cast;
- copies an address with `wl-copy` when you press copy.

It never asks for administrator rights, never reads or stores stream keys or license keys, and never starts a broadcast or a destination.

## Remove

```sh
omarchy plugin remove belweave.console-cast
```

Removing the plugin leaves Console Cast installed. To remove Console Cast too: `consolecast uninstall`.

## Licence

Copyright 2026 Belweave. The plugin's files are licensed under the Apache License, Version 2.0 (see `LICENSE`). The licence covers the files in this repository only. Console Cast itself, the app this plugin controls, is proprietary, closed-source software from Belweave, used under the terms at https://consolecast.app/legal/terms.

Questions: info@belweave.com. Publisher: Belweave, https://consolecast.app.

PlayStation® and PS5® are registered trademarks of Sony Interactive Entertainment Inc. Xbox® is a registered trademark of Microsoft Corporation. Twitch® is a registered trademark of Twitch Interactive, Inc. OBS Studio™ is a trademark of the OBS Project. Console Cast is not affiliated with, endorsed by or sponsored by any of them.
