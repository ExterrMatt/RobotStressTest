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

## Checklist before publishing

- [ ] Exported with `embed_pck=true` (single self-contained exe).
- [ ] Verified the exe launches on a clean machine (no `.pck` next to it).
- [ ] Zipped the build.
- [ ] Uploaded the zip and **ticked the Windows platform checkbox**.
- [ ] Project kind is **Downloadable**.
