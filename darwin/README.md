# Darwin

## Isolated Chromium launchers

Needs `/Applications/Chromium.app` (Brewfile's ungoogled-chromium).

```sh
mkdir -p ~/.config/chromium-apps/icons
cp -n darwin/chromium-apps.example.json ~/.config/chromium-apps/config.json
chromium-apps                     # → ~/Applications/<name>.app
```

```json
{ "apps": [{ "id": "work", "name": "Work", "icon": "~/.config/chromium-apps/icons/work.icns" }] }
```

Each app's data lives in `~/Library/Application Support/Chromium-Profiles/<id>`; keep `id` stable when renaming. Removing an entry leaves its app and data. Separate data, **not a sandbox**.

### Hammerspoon media control

`make darwin` installs Chromium initial preferences enabling **View → Developer → Allow JavaScript from Apple Events** for first-run setup. This lets local automation execute JavaScript in browser tabs. Existing profiles must enable the setting manually; their live preferences are not overwritten.

The same file sets WebRTC to `default_public_interface_only`. ungoogled-chromium defaults to `disable_non_proxied_udp`, which leaves voice calls (Discord, Meet) stuck connecting without a proxy. Existing profiles need `webrtc.ip_handling_policy` set in their `Default/Preferences` while Chromium is quit.

### Route external links to base Chromium

```sh
chromium-apps --install-url-handler --set-default   # needs Xcode CLT
```

Installs **Chromium Default**, an HTTP/HTTPS handler that opens base Chromium even while isolated profiles run. Undo by picking another default browser.

### Remote debugging of the everyday browser

```sh
make darwin
chromium-apps --install-url-handler --enable-remote-debugging --set-default --pin-to-dock
# quit Chromium, open "Chromium Default", then:
curl -s http://127.0.0.1:9222/json/version
```

MCP config: `--browserUrl=http://127.0.0.1:9222` (not `--autoConnect`). Hammerspoon and Stream Deck launch through the wrapper. Opening `Chromium.app` directly skips the flag.

> [!WARNING]
> Port 9222 is unauthenticated: any local process gets your signed-in browser. Keep it on loopback.

Disable: rerun `chromium-apps --install-url-handler` without `--enable-remote-debugging`, then restart Chromium.

```sh
python3 -m unittest discover -s darwin/tests
```

## Closed-lid awake

```sh
task setup:lid-awake                          # lid open; one sudo prompt
task setup:lid-awake -- --admin ADMIN_USER    # borrow an admin account
sudo pmset -a disablesleep 0                  # emergency reset
```

Adds a Hammerspoon **Lid** menu that toggles `pmset disablesleep`. A root LaunchDaemon resets it on battery, restart, or reboot. Log: `/var/log/local.lid-awake.log`. Keep the laptop ventilated; never transport it enabled.

## Window rules

```sh
task setup:window-rules          # then allow it in Privacy & Security
task setup:window-rules-check    # shows a test restart prompt; passes if deferred
launchctl bootout gui/$(id -u)/local.window-rules   # remove
```

A LaunchAgent applies `rules` in `darwin/scripts/window-rules.swift` to app launches. The included rule presses the quit key on SimpleMDM's swiftDialog restart prompt to defer it. It sends a `tell` notification after five failed deferrals. Log: `~/Library/Logs/local.window-rules.log`.

## Fonts

`make darwin` installs [IoskeleyMono-Term](https://github.com/ahatem/IoskeleyMono/releases/latest) unless any version is present:

```sh
python3 darwin/scripts/install-ioskeley-font.py
```
