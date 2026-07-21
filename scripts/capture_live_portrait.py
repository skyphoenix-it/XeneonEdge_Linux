#!/usr/bin/env python3
"""Record the exact Hub reflowing on a private portrait display."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

import capture_live_behavior as live


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--hub", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    if os.environ.get(live.CAPTURE_GATE) != "1":
        raise SystemExit("set %s=1 to authorize isolated capture" % live.CAPTURE_GATE)
    hub = args.hub.resolve()
    version = live.version_output(hub)
    if not version.endswith(" " + args.version):
        raise SystemExit("Hub version mismatch: %s" % version)

    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="edgehub-live-portrait-"))
    os.chmod(work, 0o700)
    run = live.harness.E2E(workdir=str(work))
    xvfb = process = recorder = None
    log_stream = None
    try:
        run.write_config(live.demo_state("portrait"))
        xvfb, display_name = live.start_xvfb(str(work), "720x2560x24")
        environment = dict(os.environ)
        environment["DISPLAY"] = display_name
        environment["QT_QPA_PLATFORM"] = "xcb"
        environment["XDG_SESSION_TYPE"] = "x11"
        environment["XDG_CONFIG_HOME"] = run.cfg
        environment["XDG_RUNTIME_DIR"] = run.run_dir
        environment.pop("WAYLAND_DISPLAY", None)

        log_path = out / "live-portrait-hub.log"
        log_stream = open(log_path, "w", encoding="utf-8")
        process = subprocess.Popen(
            [str(hub)], env=environment, stdout=log_stream,
            stderr=subprocess.STDOUT, start_new_session=True,
        )
        live.wait_socket(Path(run.sock))
        time.sleep(1.5)

        destination = out / "edgehub-live-hub-portrait.mp4"
        recorder = subprocess.Popen([
            "ffmpeg", "-hide_banner", "-loglevel", "warning", "-y",
            "-f", "x11grab", "-draw_mouse", "0", "-framerate", "30",
            "-video_size", "720x2560", "-i", display_name,
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "16",
            "-pix_fmt", "yuv420p", str(destination),
        ], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE, text=True, start_new_session=True)
        started = time.monotonic()
        actions = []
        for second, page in ((3.0, 1), (6.0, 2)):
            delay = started + second - time.monotonic()
            if delay > 0:
                time.sleep(delay)
            live.ipc(Path(run.sock), {"type": "setActivePage", "page": page})
            actions.append({"time": round(time.monotonic() - started, 3),
                            "action": "set active portrait screen",
                            "page": page})
        delay = started + 9.0 - time.monotonic()
        if delay > 0:
            time.sleep(delay)
        recorder.stdin.write("q\n")
        recorder.stdin.flush()
        recorder.wait(timeout=20)
        if recorder.returncode != 0:
            raise RuntimeError("portrait ffmpeg failed: %s" % recorder.stderr.read())
        recorder = None

        manifest = {
            "version": args.version,
            "capturedAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "captureClass": "real Hub binary in isolated portrait Xvfb",
            "physicalDisplayUsed": False,
            "physicalInputUsed": False,
            "display": "private 720x2560 Xvfb",
            "versionOutput": version,
            "hubSha256": live.sha256(hub),
            "actions": actions,
            "file": destination.name,
            "sha256": live.sha256(destination),
        }
        with open(out / "portrait-capture-manifest.json", "w",
                  encoding="utf-8") as stream:
            json.dump(manifest, stream, indent=2, sort_keys=True)
            stream.write("\n")
        print(json.dumps(manifest, indent=2, sort_keys=True))
    finally:
        if recorder and recorder.poll() is None:
            recorder.kill()
        for item in (process, xvfb):
            if item and item.poll() is None:
                item.terminate()
                try:
                    item.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    item.kill()
        if log_stream:
            log_stream.close()
        run.cleanup()
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
