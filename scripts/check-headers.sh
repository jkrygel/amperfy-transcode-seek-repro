#!/usr/bin/env bash
# Tests the server side of the bug with curl, without Amperfy.
# A live MP3 transcode has no Content-Length and no range support.
# A raw stream has range support. A timeOffset stream starts later in the song.
set -euo pipefail

BASE="${ND_URL:-http://127.0.0.1:4533}/rest"
AUTH="u=${ND_USER:-admin}&p=${ND_ADMIN_PASSWORD:-seektest}&v=1.16.1&c=seek-repro"
fails=0

check() { # $1 = text, then a command that must succeed
  local text=$1
  shift
  if "$@"; then echo "PASS  $text"; else echo "FAIL  $text"; fails=$((fails + 1)); fi
}
has() { grep -qi "^$2" <<<"$1"; }
lacks() { ! has "$@"; }
about_half() { (($1 * 10 > $2 * 4 && $1 * 10 < $2 * 6)); }
headers() { curl -sS -D - -o /dev/null --max-time 30 "$@" | tr -d '\r'; }
size() { curl -sS -o /dev/null --max-time 60 -w '%{size_download}' "$1"; }

song_id=$(curl -sS "$BASE/search3?$AUTH&f=json&query=Seek%20Test%201&songCount=1" |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["subsonic-response"]["searchResult3"]["song"][0]["id"])')
stream="$BASE/stream?$AUTH&id=$song_id"
echo "Song: Seek Test 1 ($song_id)"

extensions=$(curl -sS "$BASE/getOpenSubsonicExtensions?$AUTH&f=json")
check "Server announces the transcodeOffset extension" grep -q '"transcodeOffset"' <<<"$extensions"

first=$(headers "$stream&format=mp3&maxBitRate=256")
check "MP3 transcode, first request: Accept-Ranges is none" has "$first" 'accept-ranges: none'
check "MP3 transcode, first request: no Content-Length" lacks "$first" 'content-length:'

second=$(headers "$stream&format=mp3&maxBitRate=256")
check "MP3 transcode, same request again: no Content-Length (cache is off)" lacks "$second" 'content-length:'

raw=$(headers -H 'Range: bytes=100000-' "$stream&format=raw")
check "Raw stream with a Range header: 206 Partial Content" has "$raw" 'HTTP/1.1 206'

full=$(size "$stream&format=mp3&maxBitRate=256")
half=$(size "$stream&format=mp3&maxBitRate=256&timeOffset=150")
check "timeOffset=150 of 300 s gives about half the bytes ($half of $full)" about_half "$half" "$full"

echo
if ((fails == 0)); then echo "All tests passed."; else echo "$fails tests failed."; exit 1; fi
