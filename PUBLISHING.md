# Publishing to itch.io

Notes for exporting **Robot Stress Test** (Godot 4.6) and uploading it so the
itch.io app and the "Install" button work correctly.

## "There are no compatible versions available" — what it means

This message from the itch.io client/website almost always means the uploaded
build has **no platform tag**, not that the build is broken. The client filters
downloads by platform (Windows / macOS / Linux); an untagged upload matches
nothing and is reported as incompatible on every machine.

### Fix (itch.io dashboard, not the repo)

1. Go to your game's **Edit game** page on itch.io.
2. Scroll to **Uploads** and click the pencil/gear on the build file.
3. Under the file, tick the **Windows** checkbox ("This file will be played on
   Windows").
4. Make sure the game's **Kind of project** is set to **Downloadable** (not
   "HTML").
5. **Save**.

The app should now offer the Windows download.

## Exporting the build

The Windows Desktop preset in `export_presets.cfg` is configured with
`binary_format/embed_pck=true`, so the export produces a **single,
self-contained** `.exe`. Do not ship a bare `.exe` alongside a separate `.pck`
— if the `.pck` is missing next to the exe the game will not launch.

Recommended: **zip the exe before uploading.**

- A `.zip` uploads and updates cleanly through Butler / the itch app.
- itch.io reliably auto-detects a zip containing a Windows executable, and a zip
  avoids browser download / SmartScreen friction on a lone `.exe`.

```
# after exporting ScrewLooseVX.Y.Z.exe from Godot:
zip ScrewLooseVX.Y.Z-windows.zip ScrewLooseVX.Y.Z.exe
```

Then upload the zip and tag it **Windows** (see fix above).

## Verify, don't trust

Every claim above is checkable. Run these before and after the fix.

### 1. Confirm the root cause on itch.io (before changing anything)

- Open the game page in a **private/incognito window**: the download row shows
  an OS icon for each tagged platform. No Windows icon = the upload is
  untagged = the exact cause of "no compatible versions".
- Definitive check via the itch.io API (get a key at
  itch.io → Settings → API keys):

  ```
  curl "https://itch.io/api/1/YOUR_API_KEY/my-games"
  ```

  Find the game in the JSON and look at `p_windows`. If it is `false` or
  absent, no upload is tagged Windows. After ticking the checkbox and saving,
  re-run the command — it must flip to `true`.

### 2. Confirm the exe is self-contained (before uploading)

Godot decides whether an exe is self-contained by reading its **last 4
bytes**: `GDPC` = embedded pack; anything else = it needs a sidecar `.pck`.
Check on Windows (PowerShell):

```powershell
$f=[IO.File]::OpenRead("C:\path\to\ScrewLooseVX.Y.Z.exe")
$f.Seek(-4,[IO.SeekOrigin]::End) | Out-Null
$b=New-Object byte[] 4; $f.Read($b,0,4) | Out-Null; $f.Close()
[Text.Encoding]::ASCII.GetString($b)
```

- New export (embed_pck=true) → prints `GDPC`.
- Old export (embed_pck=false) → prints garbage/nothing. Both directions
  should hold; if they don't, the packaging claim is wrong.

### 3. The empty-folder test (simulates exactly what a player gets)

Copy **only the exe** into an empty folder (or better, another PC) and
double-click:

- Old exe (no embedded pack, no .pck next to it) → error dialog:
  *"Couldn't load project data... Is the .pck file missing?"* — this is what
  a player would have hit after installing a lone exe.
- New exe → game boots.

Note: the preset's `export_path` is `../../ScrewLooseVX.Y.Z.exe` — **outside
the project folder** — so with the old setting the sidecar
`ScrewLooseVX.Y.Z.pck` appeared next to it up there, easy to miss when
grabbing the file to upload.

### 4. End-to-end, the player path

After re-uploading and tagging: install your own game through the **itch.io
desktop app** on Windows. Dev installs go through the same pipeline players
use. If it installs and launches, the loop is closed.

## Checklist before publishing

- [ ] Exported with `embed_pck=true` (single self-contained exe).
- [ ] Verified the exe launches on a clean machine (no `.pck` next to it).
- [ ] Zipped the build.
- [ ] Uploaded the zip and **ticked the Windows platform checkbox**.
- [ ] Project kind is **Downloadable**.
