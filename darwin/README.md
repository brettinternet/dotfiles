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
chromium-apps --install-url-handler
```

Then select **Chromium Default** in **System Settings → Desktop & Dock → Default
web browser**. The handler receives HTTP/HTTPS URL events and invokes Chromium
with `--user-data-dir=~/Library/Application Support/Chromium` (expanded to an
absolute path), so external links target the base profile even while isolated
profiles are running. Opening the handler directly opens base Chromium.

This does not intercept links clicked inside a browser or apps that explicitly
choose another browser. It does not handle local HTML files or custom URL schemes.
To undo, select Chromium or another browser as the default. To update the handler,
rerun the install command; it needs macOS's `osacompile` and `codesign` tools.

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
