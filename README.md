# dotfiles

Default dotfiles for LuminOS. The `luminos-desktop` package
([luminos-packages](https://github.com/Lumin-OS/luminos-packages)) installs
everything in `.config/` into `/etc/skel`, so every new user starts with
their own copy.

| Path | What it is |
|---|---|
| `.config/hypr/hyprland.lua` | Hyprland: autostart, look, keybindings, window rules |
| `.config/hypr/keyboard.lua` | The keyboard layout. Dawn, the installer, writes it with the layout chosen during the install, and `hyprland.lua` loads it with `require("keyboard")`, so keep that line |
| `.config/hypr/hypridle.conf` | Locks the screen after 5 idle minutes and turns it off after 5.5 |
| `.config/hypr/hyprlock.conf` | The lock screen |
| `.config/quickshell/shell.qml` | The bar (workspaces, clock, tray, volume, battery) and notification popups, in [Quickshell](https://quickshell.org) |
| `.config/kitty/kitty.conf` | The terminal |
| `.config/rofi/` | The app launcher (Super+R) |

The main keybindings: Super+Q opens a terminal, Super+R the launcher and
Super+E the file manager. Super+C closes a window, Super+L locks the screen
and Super+M ends the session. Print copies a screenshot of a selected
region to the clipboard.

Hyprland is configured in Lua: since 0.55, `hyprland.conf` is deprecated.
The one consequence to know: `hyprctl dispatch` takes Lua dispatchers, as in
`hyprctl dispatch 'hl.dsp.exit()'`.
