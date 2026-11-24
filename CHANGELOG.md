# Changelog

## 1.0.1 (2026-11-24)

- The console's Primary DNS is always one of this computer's own addresses, read from the kernel
  (`ip -j -4 addr show`, `ip -j route get 1.1.1.1`, as Omarchy's network status does). The
  address Console Cast reports only chooses among them; any other address is never shown or
  copied, and the panel says "Not available" when this computer has no address to give.
- "Installed" now comes only from `consolecast version --json`. An answer on
  `127.0.0.1:7777` alone proves nothing: while the command is missing, the panel shows nothing
  from that port, and Stop is sent only once the command has answered.
- A new preview image.

## 1.0.0 (2026-11-23)

- First release: Console Cast's state in the bar; Start and Stop; the console's DNS addresses
  with copy; destinations; the free week or subscription.

Belweave, info@belweave.com
