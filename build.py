#!/usr/bin/env python3
"""Build each app into ports/<app>/<app>.love.

A .love file is a zip with main.lua at its root. Each app gets its own
apps/<app>/*.lua plus the shared/*.lua modules.
"""
import pathlib
import zipfile

root = pathlib.Path(__file__).resolve().parent
for app_dir in sorted((root / "apps").iterdir()):
    if not app_dir.is_dir():
        continue
    name = app_dir.name
    out = root / "ports" / name / f"{name}.love"
    out.parent.mkdir(parents=True, exist_ok=True)
    files = sorted(app_dir.glob("*.lua")) + sorted((root / "shared").glob("*.lua"))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            z.write(f, f.name)
    print(f"wrote {out} ({out.stat().st_size} bytes, {len(files)} files)")
