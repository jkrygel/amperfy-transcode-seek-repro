# Amperfy: duration and seeking on transcoded streams

This repository reproduces an Amperfy bug and tests the fix in [PR #859](https://github.com/BLeeEZ/amperfy/pull/859). The bug report is [#725](https://github.com/BLeeEZ/amperfy/issues/725). [#514](https://github.com/BLeeEZ/amperfy/issues/514) and problem 3 of [#672](https://github.com/BLeeEZ/amperfy/issues/672) describe the same bug.

The test makes the bug occur on every play. It does not need a slow network, a cellular connection, or a real device.

Results: [results/2026-10-27-simulator.md](results/2026-10-27-simulator.md)

## The bug

Amperfy streams a song that Navidrome transcodes, for example to MP3 at 256 kbps. The player shows a duration of 0:00. Seeking does not work. After many seeks, the playback stops, but the app continues to show "playing". If you do not seek, the song plays from start to end.

## Cause

Navidrome transcodes the song with ffmpeg while it sends the song. The size of the result is not known before the transcode is complete. Thus the response has no `Content-Length` header and has `Accept-Ranges: none`.

AudioStreaming, the player library in Amperfy, calculates the duration from the byte length. It seeks with HTTP range requests. A live transcode supports neither.

On a second play, Navidrome usually sends the song from its transcoding cache. A cached file has a size and supports range requests. Thus the bug occurs only on the first play of a song at a given format and bitrate, and it looks random.

PR #859 makes two changes:

- If the player has no duration, Amperfy shows the duration from the song metadata.
- On a live transcode, a seek starts a new stream request with the Subsonic `timeOffset` parameter. Amperfy does this only if the server announces the OpenSubsonic `transcodeOffset` extension.

## How the test makes the bug occur every time

The test server is Navidrome 0.64.2 with the transcoding cache off (`ND_TRANSCODINGCACHESIZE=0`). Thus every transcoded play is a live transcode.

## Contents

| Path | Purpose |
|---|---|
| `compose.yaml` | Navidrome test server, transcoding cache off, debug log |
| `scripts/make-test-tracks.sh` | Makes three 5-minute FLAC test tracks with the ffmpeg in the Navidrome image |
| `scripts/check-headers.sh` | Tests the server side of the bug with curl, without Amperfy |
| `scripts/build-sims.sh` | Builds Amperfy `master` and the PR, and installs each build in its own simulator |
| `scripts/seek-log.py` | Lists the stream requests from the server log, without credentials |
| `results/` | Test results |

## Requirements

- macOS with Xcode and an iOS Simulator runtime
- Docker (OrbStack or Docker Desktop)
- git, curl, and python3

## Procedure

1. Make the test tracks:

   ```sh
   ./scripts/make-test-tracks.sh
   ```

2. Start the server:

   ```sh
   docker compose up -d
   ```

3. Do the server test. Each line must show `PASS`:

   ```sh
   ./scripts/check-headers.sh
   ```

4. Build and install both Amperfy builds:

   ```sh
   ./scripts/build-sims.sh
   ```

   The script makes two simulators, "Amperfy master" and "Amperfy PR 859". The default device is an iPhone 17 Pro on the newest iOS runtime. To use a different device, set `DEVICE_TYPE`. To test a different PR, set `PR`.

5. Open both simulators from Xcode.
6. In each simulator, log in to `http://127.0.0.1:4533` with the user `admin` and the password `seektest`.
7. In each simulator, open Settings > Player, Stream & Scrobble. Set the WiFi streaming format to MP3 and the bitrate limit to 256 kbps.
8. In each simulator, play "Seek Test 1". Do the tests in the table below. Use the time counters, because the tracks are only a beep each second.
9. Show the stream requests from the server log:

   ```sh
   ./scripts/seek-log.py
   ```

   In the PR build, each seek shows as a request with a `timeOffset` value. The `bytes` column must be almost equal to the `expected` column.

## Tests

| Test | Result before the fix | Result with the fix |
|---|---|---|
| The duration shows on the first play | 0:00 | 5:00 |
| Seek forward to 2:00 | No change | The counter goes to 2:00, and the playback continues |
| Seek back to 0:30 | No change | The counter goes to 0:30, and the playback continues |
| Do many seeks fast | The playback stops | The playback continues |
| Pause, then seek | No change | The song stays paused at the new position |
| Seek to 4:50 | No change | At 5:00, "Seek Test 2" starts |
| Use the lock screen scrubber | No change | The lock screen and the player go to the new position |

## Clean up

```sh
docker compose down
rm -rf music data work
xcrun simctl delete "Amperfy master" "Amperfy PR 859"
```

## Note on the password

The server is for local tests only. `seektest` is a fixed test password. To use a different password, set `ND_ADMIN_PASSWORD` for `docker compose` and for `check-headers.sh`.
