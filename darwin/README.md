# Darwin

## Isolated Chromium launchers

The Darwin install links `chromium-apps` into `~/.bin`. Requires Python 3 and
`/Applications/Chromium.app` (provided by the Brewfile's ungoogled-chromium cask).
To configure it locally, from the dotfiles directory:

```sh
mkdir -p ~/.config/chromium-apps/icons
cp -n darwin/chromium-apps.example.json ~/.config/chromium-apps/config.json
chromium-apps
```

Edit that private JSON file to change names or add launchers. An optional icon
entry looks like `"icon": "~/.config/chromium-apps/icons/one.icns"`.
Keep the config and icons outside this repository. No configuration means a
successful no-op; installation does not generate launchers automatically.
You can also run `python3 darwin/scripts/chromium-apps.py --config /absolute/path/config.json`.

Launch the generated apps from `~/Applications`, Spotlight, or the Dock.
Each uses `~/Library/Application Support/Chromium-Profiles/<id>` for browser data.
Check `chrome://version` → **Profile Path** after opening one.

Keep IDs stable: changing a name and rerunning the generator renames the managed
launcher without changing its profile. Close the launcher before regenerating;
you may need to re-add a renamed app to the Dock. Removing a config entry does
not delete its launcher or browser data; remove unwanted apps manually in Finder.
The generator refuses to overwrite unrelated apps or follow symlinks inside
managed bundles. It does not modify the installed Chromium app.

Icons customize the launcher, not necessarily the running browser's Dock or
⌘Tab icon. Browser data is separate, but this is **not an OS security sandbox**:
Chromium still runs with your macOS user's permissions. These apps are launchers,
not separately registered default browsers or URL handlers.

### Route external links to base Chromium

Install the optional URL handler:

```sh
chromium-apps --install-url-handler --set-default
```

`--set-default` requires macOS 12+ and Xcode Command Line Tools (`xcrun swift`).
Approve any macOS confirmation prompts. It sets HTTP/HTTPS handlers and verifies
both through Launch Services; a failure exits nonzero and may leave one scheme
changed. It can also run alone without reinstalling or changing debugging flags.
Without this option, installation leaves default preferences alone; select
**Chromium Default** in **System Settings → Desktop & Dock → Default web browser**
manually instead. Quit and reopen Settings if its browser list is stale.

The bundle declares both HTML and XHTML support so it appears in that picker.
The CLI does not set document defaults (HTML, PDF, etc.). The handler receives HTTP/HTTPS URL events and launches Chromium
through `/usr/bin/open -n -a /Applications/Chromium.app --args` with
`--user-data-dir=~/Library/Application Support/Chromium` (expanded to an absolute
path). Launch Services registers the real browser process for tools such as
Hammerspoon; Chromium routes external links to the base profile even while
isolated profiles are running. Opening the handler directly opens base Chromium.

This does not intercept links clicked inside a browser or apps that explicitly
choose another browser. Local HTML/XHTML files explicitly opened with the wrapper
are forwarded to Chromium, but custom URL schemes are not handled.
To undo, select Chromium or another browser as the default. To update the handler,
rerun the install command; it needs macOS's `osacompile` and `codesign` tools.

### Optional unattended debugging of your everyday browser

After updating the checkout, run `make darwin` to refresh symlinks (including the
Hammerspoon launch helper). On each Mac, explicitly install the handler with
debugging enabled:

```sh
chromium-apps --install-url-handler --enable-remote-debugging --set-default --pin-to-dock
```

`--pin-to-dock` requires `dockutil` (included in `darwin/Brewfile`; install separately
with `brew install dockutil` if needed). It replaces a pinned `/Applications/Chromium.app`
with the wrapper, or adds the wrapper if absent, preserving other Dock items.
Repeated runs do not duplicate it. This option restarts the Dock, not the browser,
and can also run alone. Omit it to manage the Dock manually.

This adds `--remote-debugging-port=9222` to the handler's launch arguments. It keeps
using your existing Chromium data, logins, and extensions: no migration, copy,
sync, or new profile. This targets the Brewfile's **ungoogled-chromium**, not Google
Chrome. The installed Chromium 154 build was verified to allow port debugging on
its default data directory; branded Chrome requires a non-default directory.

Save browser work and quit Chromium normally once, then open **Chromium Default**.
Flags cannot enable debugging in an already-running browser. Select **Chromium
Default** as the default web browser and pin that launcher in the Dock instead of
Chromium. On other Macs, install the handler there too; browser data remains local.

Configure the MCP server to use `--browserUrl=http://127.0.0.1:9222`, **not**
`--autoConnect`. The direct port connection does not need the `chrome://inspect`
consent flow. Check `http://127.0.0.1:9222/json/version` after launching. The browser
must remain running and the Mac awake for unattended use.

The endpoint is unauthenticated: any local process able to connect can access your
signed-in browser. Keep it on loopback; use SSH forwarding rather than exposing
CDP to the network. Do not enable debugging on isolated app profiles with the same
port. Installation never quits the browser. Default-handler changes require the
explicit `--set-default` option; ordinary dotfiles installation enables neither
debugging nor default-browser changes.

The dotfiles' Hammerspoon keyboard, HTTP launch/focus shortcut, and Stream Deck
application action use the wrapper for cold Chromium launches when it is installed.
Running Chromium instances retain normal focus/hide behavior. Reload Hammerspoon
after updating dotfiles. Machines without the wrapper keep the previous behavior.

Opening `/Applications/Chromium.app` directly (Spotlight, Finder, login items, or
another app explicitly launching Chromium) still bypasses these flags. Launch
**Chromium Default** first; subsequent focus shortcuts do not disable debugging.
The browser's own “make default” button selects Chromium, not this handler, so
use `chromium-apps --set-default` or macOS Settings. Links within another browser
or an app's embedded browser can stay there. Isolated Chromium profiles and
custom URL schemes are unchanged.

To disable, rerun `chromium-apps --install-url-handler` **without** the debugging
option, quit Chromium, and reopen the handler. Reinstalling without the option
always resets the opt-in; it does not leave debugging silently enabled.

Run behavioral tests with `python3 -m unittest discover -s darwin/tests`.

## Optional closed-lid awake control

On each laptop that should show the Hammerspoon **Lid** menu, run from this checkout:

```sh
task setup:lid-awake
```

Requires Python 3, Xcode Command Line Tools (`xcrun swiftc`), and `sudo`. All root work
runs in one `sudo` call, so managed policies that never cache credentials prompt once.
Run it as the user who will use the menu. A standard user without sudo can borrow a
separate administrator account: `task setup:lid-awake -- --admin ADMIN_USER`. Keep the lid open during installation: starting the helper restores normal
sleep. Reload Hammerspoon afterward. Installation is local opt-in: no hostnames
are stored in dotfiles, and other workstations show no menu. Click the menu through
Apple Remote Desktop rather than relying on a keyboard shortcut.

The control uses `pmset -a disablesleep`, separately from the idle-sleep caffeine
helper. Enabling on battery is allowed. Once AC power is observed, switching to
battery restores normal sleep within about one second. A root LaunchDaemon watches
power independently of Hammerspoon and resets the override on daemon restart/reboot.
Unplugging Ethernet alone does not reset it if AC remains connected. The override
is global, not per user; this helper owns it and resets any manually enabled override
at startup or undock. Keep the laptop ventilated; never transport it while enabled.

The installer copies a compiled helper into `/Library/PrivilegedHelperTools`, installs
`/Library/LaunchDaemons/local.lid-awake.plist`, and creates
`/Library/Application Support/local.lid-awake`, owned by the installing user. The
menu creates or removes `enabled` there and the daemon applies it immediately,
so nothing uses `sudo` at runtime (managed policies such as CyberArk EPM ignore
`NOPASSWD` rules). The daemon only checks whether that file exists; it grants no
`pmset` or shell access. Requests do nothing while the daemon is stopped, and
undocking or a daemon restart deletes them. Installing removes older sudoers rules.
Rerun the installer after helper changes; updates start with normal sleep enabled.

Emergency reset (also do this before manually unloading the daemon):

```sh
sudo pmset -a disablesleep 0
```

Failures are logged to `/var/log/local.lid-awake.log`. The menu reports actual
`pmset` state, not just the last requested state. Test enabling on battery, docking,
and undocking on the target laptop before relying on unattended closed-lid access.

## Optional window rules

On a machine that should automatically handle specific app prompts, run:

```sh
task setup:window-rules
```

Requires Xcode Command Line Tools (`xcrun swiftc`); no `sudo`. The installer builds
`darwin/scripts/window-rules.swift` into
`~/Library/Application Support/local.window-rules/` and loads the LaunchAgent
`~/Library/LaunchAgents/local.window-rules.plist`. Allow that binary once under
**System Settings > Privacy & Security > Device Control and Data Access**, then confirm it
works with `task setup:window-rules-check`. That shows a 15-second test restart prompt,
unrelated to MDM, and passes only if the agent defers it.

The binary is signed with the identifier `local.window-rules` by a self-signed
**Dotfiles Local Code Signing** certificate. The first install creates it in
`~/Library/Keychains/dotfiles-local-codesign.keychain-db`, a keychain with an empty
password that is kept off the keychain search list. That keychain works from terminals
that cannot write the login keychain. Any process running as you can sign with it, which
is no more access than a login-keychain key that `codesign` can use without prompting.
macOS ties the approval to the identifier and certificate rather than the binary's hash,
so rerunning the installer after source changes keeps it. Deleting that keychain means
approving the newly signed binary again.
The log is `~/Library/Logs/local.window-rules.log`.

The agent watches app launches, including menu-bar-only apps, and applies the first
matching rule in `rules`. Each rule matches a bundle ID and inspects the process's
arguments to choose an action. Add a `Rule` for another app and an `Action` case for
a new kind of interaction, then rerun the installer.

The included rule defers the SimpleMDM uptime restart prompt. That script shows a
swiftDialog (`au.csiro.dialog`) window and restarts when swiftDialog exits with 0
(**Restart now**, or any ordinary app quit) or 4 (timer expired). Its quit key
(Command-Q unless `--quitkey` is set) exits 10, which the script treats as a deferral.
The rule matches swiftDialog windows whose title, message, or first button mentions
"restart". It posts that keystroke directly to the process once its window appears and
never quits it any other way. Other swiftDialog prompts are left alone. The prompt
returns on a later check while uptime stays high, so restart periodically.

To remove: `launchctl bootout gui/$(id -u)/local.window-rules`, then trash the plist
and the application support directory.

## Fonts

The Darwin install automatically installs the latest
[`IoskeleyMono-Term` release](https://github.com/ahatem/IoskeleyMono/releases/latest)
for Ghostty into `~/Library/Fonts` (normal width, hinted; requires Python 3 and
`gh` for downloads). It checks `system_profiler` and the user/system font
directories, skipping downloading or installing if the `Ioskeley Mono Term`
family or any `IoskeleyMonoTerm-*.ttf` files are already present, including
partial or disabled installations. It does not upgrade, enable, or overwrite
existing fonts. Font Book does not need to be opened.

To run separately: `python3 darwin/scripts/install-ioskeley-font.py`.
