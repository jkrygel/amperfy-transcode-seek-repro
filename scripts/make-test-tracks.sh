#!/usr/bin/env bash
# Makes three 5-minute FLAC test tracks with the ffmpeg in the Navidrome image.
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=${NAVIDROME_IMAGE:-deluan/navidrome:0.64.2}
ALBUM_DIR="music/Test Artist/Seek Test Album"
mkdir -p "$ALBUM_DIR" data

track=0
for freq in 220 330 440; do
  track=$((track + 1))
  docker run --rm --entrypoint ffmpeg -v "$PWD/music:/music" "$IMAGE" \
    -loglevel error -y \
    -f lavfi -i "sine=frequency=$freq:beep_factor=4:duration=300" -ac 2 -ar 44100 \
    -metadata title="Seek Test $track ($freq Hz)" \
    -metadata artist="Test Artist" -metadata album_artist="Test Artist" \
    -metadata album="Seek Test Album" -metadata track="$track" \
    "/music/Test Artist/Seek Test Album/0$track - Seek Test $track.flac"
done

ls -l "$ALBUM_DIR"
