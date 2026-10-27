#!/usr/bin/env python3
"""Lists the completed stream requests from the Navidrome log, without credentials.

A seek in the PR build shows as a request with a timeOffset value. The "expected"
column is the size of a constant-bitrate stream from timeOffset to the end of the song.
"""
import os
import re
import subprocess

CONTAINER = os.environ.get("CONTAINER", "amperfy-seek-repro")
SONG_SECONDS = 300

log = subprocess.run(
    ["docker", "logs", CONTAINER], capture_output=True, text=True, check=True
)
lines = (log.stdout + log.stderr).splitlines()


def param(line, name, default="-"):
    match = re.search(r"[?&]" + name + r"=([^&\" ]+)", line)
    return match.group(1) if match else default


def value(line, pattern, default="-"):
    match = re.search(pattern, line)
    return match.group(1) if match else default


print(f"{'time (UTC)':<20} {'format':<6} {'kbps':>5} {'timeOffset':>10} {'bytes':>9} {'expected':>9} {'elapsed':>8}")
for line in sorted(lines):
    if 'msg="HTTP: GET ' not in line or "/rest/stream" not in line:
        continue
    time = value(line, r'time="([^"]+)"')[:19]
    fmt = param(line, "format", "raw")
    kbps = param(line, "maxBitRate")
    offset = param(line, "timeOffset", "0")
    expected = "-"
    if fmt == "mp3" and kbps.isdigit():
        expected = str((SONG_SECONDS - int(offset)) * int(kbps) * 1000 // 8)
    size = value(line, r"responseSize=(\d+)")
    elapsed = value(line, r"elapsedTime=(\S+)")
    print(f"{time:<20} {fmt:<6} {kbps:>5} {offset:>10} {size:>9} {expected:>9} {elapsed:>8}")
