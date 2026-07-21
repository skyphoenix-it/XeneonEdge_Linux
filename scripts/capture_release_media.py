#!/usr/bin/env python3
"""Capture auditable release media from the real Edge and Manager.

The script launches explicitly selected binaries with isolated config and
runtime directories, captures only cropped product surfaces, rotates the real
Edge output through KScreen, and restores the complete display baseline in a
finally block. Full-desktop Spectacle frames exist only in a private temporary
directory long enough to crop the requested product surface.

Run on an attended KDE Wayland session:

    XENEON_MARKETING_CAPTURE=1 XENEON_MARKETING_DISPLAY=1 \
      python3 scripts/capture_release_media.py \
        --version 1.0.0-beta.1 --hub /path/to/xeneon-edge-hub \
        --manager /path/to/xeneon-edge-manager --out captures/release
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
import display_lifecycle_test as lifecycle  # noqa: E402
import e2e_harness as harness  # noqa: E402
import manager_window as mw  # noqa: E402


CAPTURE_GATE = "XENEON_MARKETING_CAPTURE"
DISPLAY_GATE = "XENEON_MARKETING_DISPLAY"


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


def appearance(orientation, theme="midnight", background="orbs"):
    return {
        "mode": "dark",
        "themeMode": theme,
        "accent": "#58A6FF",
        "bgStyle": background,
        "animatedBg": True,
        "glass": 0.55,
        "glow": True,
        "gridCols": 1,
        "orientation": orientation,
    }


def curated_state(orientation="portrait", theme="midnight"):
    return harness.doc([
        harness.page("System", [
            harness.tile("demo-cpu", "cpu", "1x1"),
            harness.tile("demo-gpu", "gpu", "1x1"),
            harness.tile("demo-ram", "ram", "1x1"),
        ]),
        harness.page("Focus", [
            harness.tile("demo-focus", "focus", "1x1"),
            harness.tile("demo-tasks", "tasks", "1x2"),
        ]),
        harness.page("At a glance", [
            harness.tile("demo-clock", "clock", "1x1"),
            harness.tile("demo-weather", "weather", "1x1"),
            harness.tile("demo-moon", "moon", "1x1"),
        ]),
    ], settings={
        "demo-focus": {
            "preset": "classic", "phase": "work", "running": False,
            "endEpoch": 0, "pausedRemaining": 1500, "doneToday": 2,
            "day": time.strftime("%Y-%m-%d"), "points": 8,
            "dailyGoal": 4, "rewardPoints": True, "celebrate": True,
            "autoStartBreak": False,
        },
        "demo-tasks": {"items": [
            {"text": "Review the dashboard", "done": True},
            {"text": "Ship the beta", "done": False},
        ]},
        "demo-weather": {"location": "Vienna", "unit": "c"},
    }, appearance=appearance(orientation, theme))


def crop_canvas_rect(work, destination, rect, tag):
    from PIL import Image

    full_path = dt._full_grab(str(work), tag)
    if not full_path:
        raise RuntimeError("Spectacle did not produce a desktop frame")
    try:
        image = Image.open(full_path).convert("RGB")
        screens = dt.screens()
        logical_w = max(x + width for _, x, y, width, height in screens)
        logical_h = max(y + height for _, x, y, width, height in screens)
        scale_x = image.width / logical_w
        scale_y = image.height / logical_h
        _, x, y, width, height = rect
        box = (
            round(x * scale_x), round(y * scale_y),
            round((x + width) * scale_x), round((y + height) * scale_y),
        )
        cropped = image.crop(box)
        cropped.save(destination, optimize=True)
        return {"width": cropped.width, "height": cropped.height}
    finally:
        try:
            os.unlink(full_path)
        except OSError:
            pass


def wait_manager_rect(log_path):
    rect = dt.manager_rect_from_log(str(log_path), timeout=20)
    if not rect:
        raise RuntimeError("could not locate the Manager window")
    return rect


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--hub", required=True, type=Path)
    parser.add_argument("--manager", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--hub-only", action="store_true",
                        help="capture Hub orientations without opening Manager")
    args = parser.parse_args()

    if os.environ.get(CAPTURE_GATE) != "1":
        raise SystemExit("set %s=1 to authorize real display capture" % CAPTURE_GATE)
    if os.environ.get(DISPLAY_GATE) != "1":
        raise SystemExit("set %s=1 to authorize temporary Edge rotation" % DISPLAY_GATE)
    if os.environ.get("XDG_SESSION_TYPE") != "wayland":
        raise SystemExit("release capture requires the verified KDE Wayland session")

    hub = args.hub.resolve()
    manager = args.manager.resolve()
    for binary in (hub, manager):
        if not binary.is_file() or not os.access(binary, os.X_OK):
            raise SystemExit("missing executable: %s" % binary)
    versions = {"hub": version_output(hub), "manager": version_output(manager)}
    for label, output in versions.items():
        if not output.endswith(" " + args.version):
            raise SystemExit("%s version mismatch: %s" % (label, output))

    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="edgehub-media-"))
    os.chmod(work, 0o700)
    baseline = lifecycle.doctor_json()
    with open(out / "kscreen-baseline.json", "w", encoding="utf-8") as stream:
        json.dump(baseline, stream, indent=2, sort_keys=True)

    edge = next((item for item in baseline.get("outputs", [])
                 if item.get("enabled") and
                 ("XENEON" in ((item.get("model") or "") + " " +
                                (item.get("name") or "")).upper()
                  or (item.get("size", {}).get("width"),
                      item.get("size", {}).get("height")) in
                  ((2560, 720), (720, 2560)))), None)
    if not edge:
        raise SystemExit("no enabled 2560x720 Edge output found")
    edge_name = edge["name"]

    harness.HUB = str(hub)
    harness.MANAGER = str(manager)
    run = harness.E2E(workdir=str(work))
    manager_process = None
    manager_log_stream = None
    frames = []
    file_version = "v" + args.version
    try:
        portrait = curated_state("portrait")
        run.write_config(portrait)
        if not run.launch_hub() or not run.verify_target_window():
            raise RuntimeError("Hub was not verified on the physical Edge")
        run.set_state(portrait)
        time.sleep(1.5)

        portrait_rect = next(screen for screen in dt.screens()
                             if screen[0] == edge_name)
        target = out / ("edgehub-%s-hub-portrait-hero-01.png" % file_version)
        size = crop_canvas_rect(work, target, portrait_rect, "hub-portrait")
        frames.append({"file": target.name, "surface": "Hub",
                       "orientation": "portrait", **size})

        if not args.hub_only:
            environment = dict(os.environ)
            environment["XDG_CONFIG_HOME"] = run.cfg
            environment["XDG_RUNTIME_DIR"] = run.run_dir
            harness._abs_wayland_display(environment)
            manager_log = out / "manager-capture.log"
            manager_log_stream = open(manager_log, "w", encoding="utf-8")
            manager_process = subprocess.Popen(
                [str(manager)], env=environment, stdout=manager_log_stream,
                stderr=subprocess.STDOUT, start_new_session=True,
            )
            manager_rect = wait_manager_rect(manager_log)
            dt.assert_rect_on_a_desktop_screen(manager_rect, edge_name)
            time.sleep(1.5)
            front_check = mw.grab_rect(manager_rect, str(work),
                                       "manager-front-check")
            active_row = mw.active_row(front_check, manager_rect[3],
                                       manager_rect[4]) if front_check else None
            if active_row != "Screens":
                raise RuntimeError(
                    "Manager is not frontmost on its Screens tab; refusing to "
                    "capture unrelated desktop content"
                )
            target = out / ("edgehub-%s-manager-layout-01.png" % file_version)
            size = crop_canvas_rect(work, target, manager_rect, "manager-layout")
            frames.append({"file": target.name, "surface": "Manager",
                           "state": "layout", **size})

            run.set_state(curated_state("portrait", theme="light"))
            time.sleep(5.0)
            target = out / ("edgehub-%s-manager-theme-light-01.png" % file_version)
            size = crop_canvas_rect(work, target, manager_rect,
                                    "manager-theme-light")
            frames.append({"file": target.name, "surface": "Manager",
                           "state": "light theme reflected live", **size})

            run.set_state(curated_state("landscape", theme="midnight"))
            time.sleep(5.0)
            target = out / ("edgehub-%s-manager-landscape-preview-01.png" %
                            file_version)
            size = crop_canvas_rect(work, target, manager_rect,
                                    "manager-landscape-preview")
            frames.append({"file": target.name, "surface": "Manager",
                           "orientation": "landscape preview", **size})

        lifecycle.apply_doctor("output.%s.rotation.none" % edge_name,
                               "output.%s.scale.1" % edge_name)
        # KScreen has already made the output landscape. Auto therefore leaves
        # content upright; a second fixed landscape rotation would turn it
        # sideways in the captured compositor frame.
        run.set_state(curated_state("auto"))
        time.sleep(1.5)
        landscape_rect = next(screen for screen in dt.screens()
                              if screen[0] == edge_name)
        if landscape_rect[3:] != (2560, 720):
            raise RuntimeError("Edge did not reach native landscape: %r" %
                               (landscape_rect,))
        target = out / ("edgehub-%s-hub-landscape-hero-01.png" % file_version)
        size = crop_canvas_rect(work, target, landscape_rect, "hub-landscape")
        frames.append({"file": target.name, "surface": "Hub",
                       "orientation": "landscape", **size})
    finally:
        if manager_process:
            try:
                manager_process.kill()
                manager_process.wait(timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                pass
        if manager_log_stream:
            manager_log_stream.close()
        try:
            lifecycle.apply_doctor(*lifecycle.restore_settings(baseline))
        finally:
            run.cleanup()
            shutil.rmtree(work, ignore_errors=True)

    restored = lifecycle.doctor_json()
    if lifecycle.restore_settings(restored) != lifecycle.restore_settings(baseline):
        raise RuntimeError("KScreen baseline was not restored exactly")

    manifest = {
        "version": args.version,
        "commit": subprocess.run(
            ["git", "rev-parse", "v" + args.version + "^{}"], cwd=REPO,
            capture_output=True, text=True, check=True,
        ).stdout.strip(),
        "capturedAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "session": {"desktop": os.environ.get("XDG_CURRENT_DESKTOP"),
                    "type": os.environ.get("XDG_SESSION_TYPE"),
                    "edgeOutput": edge_name},
        "versions": versions,
        "binaries": {"hubSha256": sha256(hub),
                     "managerSha256": sha256(manager)},
        "privacy": "isolated config/runtime; temporary desktop frames deleted after crop",
        "frames": frames,
    }
    with open(out / "capture-manifest.json", "w", encoding="utf-8") as stream:
        json.dump(manifest, stream, indent=2, sort_keys=True)
        stream.write("\n")
    print(json.dumps(manifest, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
