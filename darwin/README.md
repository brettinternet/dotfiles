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

Run behavioral tests with `python3 -m unittest discover -s darwin/tests`.

## Fonts

Install the [`IoskeleyMono-Term` release](https://github.com/ahatem/IoskeleyMono/releases/latest) manually for Ghostty.
