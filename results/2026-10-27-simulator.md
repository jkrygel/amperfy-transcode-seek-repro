# Results: 2026-10-27, iOS Simulator

## Environment

| Item | Value |
|---|---|
| Mac | macOS 27.0.1, Apple silicon |
| Xcode | 27.0 (27A266a) |
| Simulators | iPhone 17 Pro and iPhone 17 Pro Max, iOS 26.5 |
| Server | Navidrome 0.64.2 in OrbStack, transcoding cache off |
| Amperfy `master` | `9fba4192` (v2.1.2) |
| Amperfy PR #859 | `0bb92c23` |
| Amperfy setting | WiFi streaming format MP3, bitrate limit 256 kbps |

The PR branch starts from `c165a7a8`, which is older than `master`. The commits between `c165a7a8` and `master` do not change the player code.

## Server test

`scripts/check-headers.sh` passed all six tests:

```
PASS  Server announces the transcodeOffset extension
PASS  MP3 transcode, first request: Accept-Ranges is none
PASS  MP3 transcode, first request: no Content-Length
PASS  MP3 transcode, same request again: no Content-Length (cache is off)
PASS  Raw stream with a Range header: 206 Partial Content
PASS  timeOffset=150 of 300 s gives about half the bytes (4801678 of 9601521)
```

## App tests

| Test | `master` | PR #859 |
|---|---|---|
| The duration shows on the first play | Fail (`--:--`) [1] | Pass (`-4:57` remaining) [4] |
| Seek forward | Fail [1] [2] | Pass [4] |
| Seek back | Fail [1] [2] | Pass [4] |
| Do many seeks fast | Fail (the playback stops) | Pass [4] |
| Pause, then seek | Fail [2] | Pass [4] |
| Seek to 4:50 | Fail | Pass (the next track starts at 5:00) |
| Use the lock screen scrubber | Fail | Pass |

Recordings in `recordings/`:

1. `master-2-seek-ignored.mp4`
2. `master-3-seek-and-pause-fail.mp4`
3. `master-4-works-after-amperfy-download.mp4`
4. `pr-859-duration-and-seeking.mp4`

The rows without a number are from the tester's notes, without a recording.

Recording 3 shows a replay on `master` from the copy that Amperfy downloaded during the first play. The player shows a download icon instead of the antenna icon (`playType == .cache` in `PlayerUIHandler.swift`). On this replay, the duration and seeking work. The Navidrome cache is off in this test. Thus Amperfy's downloaded copy, not the Navidrome cache, makes the replay work here.

## Server log of the PR build

These lines are from `scripts/seek-log.py`, during a test of "Seek Test 2". The first line is the start of the song. Each other line is one seek. The `expected` column is `(300 s - timeOffset) x 256 kbps`. Each response is within 0.1% of the expected size. Thus each seek stream starts at the requested position and runs to the end of the song.

```
time (UTC)           format  kbps timeOffset     bytes  expected  elapsed
2026-10-27T16:38:55  mp3      256          0   9601521   9600000    2.71s
2026-10-27T16:39:03  mp3      256        164   4353625   4352000    1.27s
2026-10-27T16:39:06  mp3      256         59   7713181   7712000    2.19s
2026-10-27T16:39:09  mp3      256        138   5185364   5184000    1.45s
2026-10-27T16:39:14  mp3      256        196   3329625   3328000  955.2ms
2026-10-27T16:39:17  mp3      256        227   2337390   2336000    711ms
2026-10-27T16:39:25  mp3      256         66   7489155   7488000    2.06s
```

## Other observation

Each stream start opens two connections to `/rest/stream`. Navidrome starts a transcode for each connection. Within one second, the client closes the first connection, and Navidrome logs `write: broken pipe` for it. The second connection plays.

This occurs on the first play of a song and on each seek. Thus each seek starts two ffmpeg processes on the server.

The cause is in AudioStreaming 1.4.4, not in the PR. When AudioStreaming opens a remote stream at position 0, it first sends a probe request with `Range: bytes=0-1` (`RemoteAudioSource.initialRequest`). It reads the response headers, cancels the probe, and then opens the real stream. A PR seek opens a new stream at position 0, so each seek also sends a probe.

For a file, the probe costs 2 bytes. A live transcode cannot answer a range request, so Navidrome starts a full transcode for the probe. The log does not separate `master` from the PR, because both builds send the same client name. The code path is the same for both.

The extra transcode is a cost, not a failure. If a server sets `Transcoding.MaxConcurrent` or `Transcoding.MaxConcurrentPerUser`, fast seeks can reach the limit sooner. Both limits are off by default. This test did not set them.

## Not tested

- A real iPhone. The real-world failure is on an iPhone on cellular with MP3 at 256 kbps. On WiFi with the Raw format, the bug does not occur.
- Other transcoding formats (AAC, Opus) and the "server config" format setting.
- Ampache servers. On Ampache, the PR keeps the old seek behavior.
