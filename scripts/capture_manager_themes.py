#!/usr/bin/env python3
"""Capture exact-candidate Manager themes without touching physical displays.

The Manager is rendered inside a private Xvfb display. Each frame starts from an
isolated config and runtime directory, and the virtual root is cropped to the
Manager's logged window rectangle. No Hub, physical output, pointer, or keyboard
input is used.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


REPO = Path(__file__).resolve().parents[1]
HARDWARE = REPO / "tests" / "hardware"
sys.path.insert(0, str(HARDWARE))

import desktop_target as dt  # noqa: E402
import e2e_harness as harness  # noqa: E402
import manager_window as mw  # noqa: E402


CAPTURE_GATE = "XENEON_MARKETING_CAPTURE"
FREE_THEMES = [
    ("dark", "Dark"), ("midnight", "Midnight"), ("aurora", "Aurora"),
    ("sunset", "Sunset"), ("nebula", "Nebula"),
    ("deep_forest", "Forest"), ("deep_ocean", "Ocean"),
    ("ember", "Ember"), ("rose_gold", "Rose Gold"), ("nord", "Nord"),
    ("dracula", "Dracula"), ("solarized", "Solarized"),
    ("gruvbox", "Gruvbox"), ("catppuccin", "Catppuccin"),
    ("tokyonight", "Tokyo Night"), ("aubergine", "Aubergine"),
    ("crimson", "Crimson"), ("oled", "OLED"), ("light", "Light"),
    ("high_contrast", "Contrast"),
]
ACCENTS = [
    ("blue", "Blue", "#58A6FF"), ("purple", "Purple", "#A371F7"),
    ("green", "Green", "#3FB950"), ("orange", "Orange", "#F0883E"),
    ("pink", "Pink", "#F778BA"), ("teal", "Teal", "#56D4DD"),
    ("red", "Red", "#F85149"), ("gold", "Gold", "#E3B341"),
    ("cyan", "Cyan", "#22D3EE"), ("magenta", "Magenta", "#E879F9"),
]


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def version_output(binary):
    return subprocess.run(
        [str(binary), "--version"], capture_output=True, text=True,
        check=True, timeout=10,
    ).stdout.strip()


def state(theme, accent="blue"):
    pages = [harness.page("Home", [
        harness.tile("clock-1", "clock", "1x1"),
        harness.tile("cpu-1", "cpu", "1x1"),
    ])]
    return harness.doc(pages, settings={
        "clock-1": {"accent": accent},
        "cpu-1": {"accent": accent},
    }, appearance={
        "themeMode": theme, "accent": accent, "bgStyle": "orbs",
        "animatedBg": True, "glass": 0.55, "glow": True,
        "gridCols": 1, "orientation": "portrait",
    })


def start_xvfb(work):
    process = subprocess.Popen(
        ["Xvfb", "-displayfd", "1", "-screen", "0", "1920x1080x24",
         "-nolisten", "tcp"], cwd=work, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, start_new_session=True,
    )
    number = process.stdout.readline().strip()
    if not number or process.poll() is not None:
        error = process.stderr.read() if process.stderr else ""
        raise RuntimeError("Xvfb did not start: %s" % error.strip())
    return process, ":" + number


def capture_one(manager, run, environment, out, key, name, filename, tag):
    from PIL import Image

    run.write_config(state(key[0], key[1]))
    log_path = out / (".%s.log" % tag)
    with open(log_path, "w", encoding="utf-8") as log_stream:
        process = subprocess.Popen(
            [str(manager)], env=environment, stdout=log_stream,
            stderr=subprocess.STDOUT, start_new_session=True,
        )
        try:
            rect = dt.manager_rect_from_log(str(log_path), timeout=15)
            if not rect:
                raise RuntimeError("Manager did not report its virtual rectangle")
            _, x, y, width, height = rect
            if x < 0 or y < 0 or x + width > 1920 or y + height > 1080:
                raise RuntimeError("Manager escaped the virtual display: %r" % (rect,))
            time.sleep(2.0)
            full_path = out / (".%s-root.png" % tag)
            subprocess.run(
                ["import", "-display", environment["DISPLAY"], "-window", "root",
                 str(full_path)], check=True, timeout=15,
            )
            try:
                image = Image.open(full_path).convert("RGB")
                crop = image.crop((x, y, x + width, y + height))
                destination = out / filename
                crop.save(destination, optimize=True)
            finally:
                try:
                    os.unlink(full_path)
                except OSError:
                    pass
            if mw.active_row(str(destination), width, height) != "Screens":
                raise RuntimeError("virtual Manager frame failed the Screens proof")
            return {
                "name": name, "file": filename, "width": width,
                "height": height, "sha256": sha256(destination),
            }
        finally:
            try:
                process.kill()
                process.wait(timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                pass
            try:
                os.unlink(log_path)
            except OSError:
                pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--manager", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--only", choices=("all", "themes", "accents"),
                        default="all")
    args = parser.parse_args()

    if os.environ.get(CAPTURE_GATE) != "1":
        raise SystemExit("set %s=1 to authorize Manager capture" % CAPTURE_GATE)
    manager = args.manager.resolve()
    if not manager.is_file() or not os.access(manager, os.X_OK):
        raise SystemExit("missing executable: %s" % manager)
    version = version_output(manager)
    if not version.endswith(" " + args.version):
        raise SystemExit("Manager version mismatch: %s" % version)

    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    previous_frames = []
    manifest_path = out / "capture-manifest.json"
    if manifest_path.is_file():
        with open(manifest_path, "r", encoding="utf-8") as stream:
            previous_frames = json.load(stream).get("frames", [])
    work = Path(tempfile.mkdtemp(prefix="edgehub-theme-xvfb-"))
    os.chmod(work, 0o700)
    run = harness.E2E(workdir=str(work))
    xvfb = None
    frames = []
    try:
        xvfb, display = start_xvfb(str(work))
        environment = dict(os.environ)
        environment["DISPLAY"] = display
        environment["QT_QPA_PLATFORM"] = "xcb"
        environment["XDG_SESSION_TYPE"] = "x11"
        environment["XDG_CONFIG_HOME"] = run.cfg
        environment["XDG_RUNTIME_DIR"] = run.run_dir
        environment.pop("WAYLAND_DISPLAY", None)

        for index, (key, name) in enumerate(FREE_THEMES, start=1):
            if args.only == "accents":
                continue
            filename = "edgehub-v%s-manager-theme-%02d-%s.png" % (
                args.version, index, key.replace("_", "-"))
            frame = capture_one(
                manager, run, environment, out, (key, "blue"), name,
                filename, "theme-%02d" % index,
            )
            frame.update({"kind": "theme", "index": index, "key": key})
            frames.append(frame)
            print("captured theme %02d/%02d %s" %
                  (index, len(FREE_THEMES), name), flush=True)

        for index, (key, name, color) in enumerate(ACCENTS, start=1):
            if args.only == "themes":
                continue
            filename = "edgehub-v%s-manager-accent-%02d-%s.png" % (
                args.version, index, key)
            frame = capture_one(
                manager, run, environment, out, ("nord", key), name,
                filename, "accent-%02d" % index,
            )
            frame.update({"kind": "accent", "index": index, "key": key,
                          "color": color, "baseTheme": "nord"})
            frames.append(frame)
            print("captured accent %02d/%02d %s" %
                  (index, len(ACCENTS), name), flush=True)
    finally:
        if xvfb:
            try:
                xvfb.kill()
                xvfb.wait(timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                pass
        run.cleanup()
        shutil.rmtree(work, ignore_errors=True)

    if args.only == "accents":
        frames = [frame for frame in previous_frames
                  if frame.get("kind") == "theme"] + frames
    elif args.only == "themes":
        frames += [frame for frame in previous_frames
                   if frame.get("kind") == "accent"]

    manifest = {
        "version": args.version,
        "commit": subprocess.run(
            ["git", "rev-parse", "v" + args.version + "^{}"], cwd=REPO,
            capture_output=True, text=True, check=True,
        ).stdout.strip(),
        "capturedAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "captureClass": "exact candidate in isolated Xvfb; not physical hardware",
        "display": "private 1920x1080 Xvfb root; no physical output",
        "versionOutput": version,
        "managerSha256": sha256(manager),
        "method": "restart Manager for each isolated config; no input",
        "themeCount": len(FREE_THEMES), "accentCount": len(ACCENTS),
        "frames": frames,
    }
    with open(manifest_path, "w", encoding="utf-8") as stream:
        json.dump(manifest, stream, indent=2, sort_keys=True)
        stream.write("\n")
    print(json.dumps(manifest, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
