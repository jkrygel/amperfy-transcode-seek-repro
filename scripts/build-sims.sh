#!/usr/bin/env bash
# Builds Amperfy master and the PR branch, then installs each build in its own simulator.
set -euo pipefail
cd "$(dirname "$0")/.."

PR=${PR:-859}
REPO=${AMPERFY_REPO:-https://github.com/BLeeEZ/amperfy.git}
WORK=${WORK:-$PWD/work}
DEVICE_TYPE=${DEVICE_TYPE:-iPhone 17 Pro}
BUNDLE_ID=de.familie-zimba.amperfy-music

# Newest available iOS runtime, unless RUNTIME is set
RUNTIME=${RUNTIME:-$(xcrun simctl list -j runtimes | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]]
print(max(runtimes, key=lambda r: [int(p) for p in r["version"].split(".")])["identifier"])')}

simulator() { # $1 = name; prints the UDID, and creates the simulator if it does not exist
  local udid
  udid=$(xcrun simctl list -j devices | python3 -c '
import json, sys
name = sys.argv[1]
print(next((d["udid"] for ds in json.load(sys.stdin)["devices"].values() for d in ds
            if d["name"] == name and d["isAvailable"]), ""))' "$1")
  [ -n "$udid" ] || udid=$(xcrun simctl create "$1" "$DEVICE_TYPE" "$RUNTIME")
  echo "$udid"
}

checkout() { # $1 = worktree dir, $2 = ref
  if [ -d "$1" ]; then
    git -C "$1" checkout -q --detach "$2"
  else
    git -C "$WORK/amperfy" worktree add -q --detach "$1" "$2"
  fi
  echo "$(basename "$1"): $(git -C "$1" log -1 --format='%h %s')"
}

build_and_install() { # $1 = name, $2 = worktree dir, $3 = simulator UDID
  local derived="$WORK/derived-$1" log="$WORK/build-$1.log"
  echo "Building $1 (log: $log)"
  xcodebuild -project "$2/Amperfy.xcodeproj" -scheme Amperfy -configuration Debug \
    -destination "platform=iOS Simulator,id=$3" -derivedDataPath "$derived" build >"$log" 2>&1 ||
    { echo "Build of $1 failed. Read $log."; exit 1; }
  xcrun simctl boot "$3" 2>/dev/null || true
  xcrun simctl install "$3" "$derived/Build/Products/Debug-iphonesimulator/Amperfy.app"
  xcrun simctl launch "$3" "$BUNDLE_ID" >/dev/null
  echo "Installed $1 in simulator $3"
}

mkdir -p "$WORK"
[ -d "$WORK/amperfy" ] || git clone -q "$REPO" "$WORK/amperfy"
git -C "$WORK/amperfy" fetch -q origin master "+pull/$PR/head:refs/remotes/origin/pr-$PR"
checkout "$WORK/master" origin/master
checkout "$WORK/pr-$PR" "origin/pr-$PR"

master_sim=$(simulator "Amperfy master")
pr_sim=$(simulator "Amperfy PR $PR")
build_and_install master "$WORK/master" "$master_sim"
build_and_install "pr-$PR" "$WORK/pr-$PR" "$pr_sim"

echo
echo "Simulator \"Amperfy master\": $master_sim"
echo "Simulator \"Amperfy PR $PR\": $pr_sim"
echo "Open both simulators from Xcode to see their screens."
