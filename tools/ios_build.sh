#!/bin/bash
# Builds Melt a Glacier for iPhone. Needs a Mac with Xcode and Godot (the
# "iOS build" workflow runs it on a GitHub Mac runner).
#
#   tools/ios_build.sh check        unsigned build: proves the game exports, compiles and packages for iPhone
#   tools/ios_build.sh testflight   signs with the App Store Connect API key and uploads to TestFlight
#
# Environment:
#   GODOT          path to the Godot binary (required), the version in tools/plugin_versions.env
#   FLAVOR         store (default): live ads and real purchases, the build you publish.
#                  An upload stops early unless tests/release_check.gd passes (every store id filled in).
#                  preview: Google's test ads, for trying the game.
#   VERSION        version shown on the App Store (default: export_presets.cfg's short_version)
#   BUILD_NUMBER   must go up with every upload. Default for testflight: one more than the
#                  highest build App Store Connect already has (tools/next_build_number.mjs); for check: 1
#   ASC_APP_ID     the game's App Store Connect id (testflight only, to find the next build number)
#   WORK           scratch folder for logs and the archive (default: a new temp folder)
#   testflight only: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (the .p8 text, or base64 of it), APPLE_TEAM_ID
#
# The native halves of the ad and store plugins come from tools/fetch_plugins.sh ios.
# Nothing here submits the game for review. An upload lands in TestFlight; sending a
# build to App Review stays a manual step in App Store Connect.
set -euo pipefail

mode="${1:-check}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
case "$mode" in check|testflight) ;; *) echo "Mode must be check or testflight" >&2; exit 2;; esac
: "${GODOT:?set GODOT to the Godot binary}"
source tools/plugin_versions.env
have_godot="$("$GODOT" --version 2>/dev/null | head -1)"
case "$have_godot" in "$GODOT_VERSION".stable*) ;; *) echo "Needs Godot $GODOT_VERSION, but GODOT is $have_godot" >&2; exit 2;; esac

FLAVOR="${FLAVOR:-store}"
case "$FLAVOR" in store|preview) ;; *) echo "FLAVOR must be store or preview" >&2; exit 2;; esac
preset_value() { python3 -c "import re,sys; s=open('export_presets.cfg').read(); i=s.index('name=\"iOS\"'); m=re.search(r'^application/'+sys.argv[1]+r'=\"([^\"]*)\"', s[i:], re.M); print(m.group(1) if m else '')" "$1"; }
VERSION="${VERSION:-$(preset_value short_version)}"
echo "$VERSION" | grep -Eq '^[0-9]+(\.[0-9]+){0,2}$' || { echo "VERSION must look like 1.0.0" >&2; exit 2; }
bundle_id="$(preset_value bundle_identifier)"
[ -n "$bundle_id" ] || { echo "The iOS preset has no bundle identifier" >&2; exit 2; }
WORK="${WORK:-$(mktemp -d)}"
mkdir -p "$WORK"
logs="$WORK/logs"; mkdir -p "$logs"
name="MeltAGlacier"

say() { printf '\n== %s\n' "$*"; }

# Runs xcodebuild quietly into a log; on failure prints the errors and the tail.
xcb() {
  local log="$1"; shift
  if xcodebuild "$@" > "$log" 2>&1; then
    grep -E '^\*\* .* \*\*$' "$log" | tail -1 || true
    return 0
  fi
  echo "xcodebuild failed. Errors:" >&2
  grep -nE 'error:|errors? generated|\*\* .*FAILED \*\*|Provisioning|No profiles|No signing|requires a' "$log" | head -60 >&2 || true
  echo "--- last lines of $(basename "$log") ---" >&2
  tail -40 "$log" >&2
  return 1
}

team="ABCDE12345"   # Godot insists on a team id; any one does for an unsigned build
if [ "$mode" = "testflight" ]; then
  missing=""
  for v in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8 APPLE_TEAM_ID; do
    eval "val=\${$v:-}"
    [ -n "$val" ] || missing="$missing $v"
  done
  if [ -n "$missing" ]; then
    echo "Can't sign: these secrets are not set:$missing" >&2
    echo "They live under the organization's Settings > Secrets and variables > Actions." >&2
    exit 3
  fi
  team="$APPLE_TEAM_ID"
  if [ -z "${BUILD_NUMBER:-}" ]; then
    [ -n "${ASC_APP_ID:-}" ] || { echo "Set BUILD_NUMBER or ASC_APP_ID" >&2; exit 2; }
    BUILD_NUMBER="$(node tools/next_build_number.mjs "$ASC_APP_ID")"
  fi
fi
BUILD_NUMBER="${BUILD_NUMBER:-1}"
echo "$BUILD_NUMBER" | grep -Eq '^[0-9]+$' || { echo "BUILD_NUMBER must be a whole number" >&2; exit 2; }

say "Xcode"
xcodebuild -version

say "Native plugins (iOS)"
bash tools/fetch_plugins.sh ios > "$logs/plugins.log" 2>&1 || { tail -30 "$logs/plugins.log"; exit 1; }

say "Import (Godot $GODOT_VERSION)"
"$GODOT" --headless --import > "$logs/import.log" 2>&1 || { tail -30 "$logs/import.log"; exit 1; }

say "Tests"
for t in smoke_test monetization_test scroll_test; do
  "$GODOT" --headless -s "res://tests/$t.gd" > "$logs/$t.log" 2>&1 || { tail -40 "$logs/$t.log"; echo "$t failed: not building." >&2; exit 1; }
  echo "$t: passed"
done

if [ "$FLAVOR" = "store" ]; then
  say "Release check (store ids)"
  if "$GODOT" --headless -s res://tests/release_check.gd -- iOS > "$logs/release_check.log" 2>&1; then
    grep -E '^Release check' "$logs/release_check.log" || echo "Release check: passed"
  else
    grep -E '^Release check|^  - ' "$logs/release_check.log" || tail -20 "$logs/release_check.log"
    if [ "$mode" = "testflight" ]; then
      echo "Refusing to upload a store build while a store id is still a placeholder." >&2
      exit 4
    fi
    echo "(Unsigned check build: carrying on. A TestFlight upload of the store build would stop here.)"
  fi
fi

say "Xcode project (Godot export)"
# Team, version, build number, and Google's test ads for a preview build.
python3 - "$team" "$VERSION" "$BUILD_NUMBER" "$FLAVOR" <<'PY'
import re, sys
team, version, build, flavor = sys.argv[1:5]
s = open("export_presets.cfg").read()
start = s.index('name="iOS"')
nxt = re.search(r"^\[preset\.\d+\]$", s[start:], re.M)
end = start + nxt.start() if nxt else len(s)
block = s[start:end]
block = re.sub(r'^custom_features=".*"$', 'custom_features="%s"' % ("test_ads" if flavor == "preview" else ""), block, count=1, flags=re.M)
for key, value in (("app_store_team_id", team), ("short_version", version), ("version", build)):
    block, n = re.subn(r'^application/%s=".*"$' % key, 'application/%s="%s"' % (key, value), block, count=1, flags=re.M)
    if n != 1:
        sys.exit("export_presets.cfg: no application/%s in the iOS preset" % key)
open("export_presets.cfg", "w").write(s[:start] + block + s[end:])
PY
rm -rf build/ios; mkdir -p build/ios
"$GODOT" --headless --export-release "iOS" "build/ios/$name.ipa" > "$logs/export.log" 2>&1 || true
project="build/ios/$name.xcodeproj"
[ -d "$project" ] || { grep -iE 'error' "$logs/export.log" | head -20; tail -20 "$logs/export.log"; echo "Godot did not write $name.xcodeproj" >&2; exit 1; }
echo "$name.xcodeproj  ($bundle_id, version $VERSION build $BUILD_NUMBER, $FLAVOR)"
info="$(grep -rl --include='*-Info.plist' CFBundleIdentifier build/ios | head -1)"
[ -n "$info" ] || { echo "No Info.plist in the exported project" >&2; exit 1; }
scheme="$(xcodebuild -list -json -project "$project" | python3 -c "import json,sys; print(json.load(sys.stdin)['project']['schemes'][0])")"
echo "scheme: $scheme"
grep -qs GADApplicationIdentifier "$info" || { echo "AdMob's app id is missing from the Info.plist" >&2; exit 1; }
grep -qs SKAdNetworkItems "$info" || echo "::warning::No SKAdNetworkItems in the Info.plist"
grep -q GodotxRevenueCat "$project/project.pbxproj" || { echo "RevenueCat is not linked in the Xcode project" >&2; exit 1; }
grep -qi admob "$project/project.pbxproj" || { echo "AdMob is not linked in the Xcode project" >&2; exit 1; }
echo "AdMob and RevenueCat: in the Xcode project"

# Reads one Info.plist value from a built .app.
plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Info.plist" 2>/dev/null || true; }

check_app() {
  local app="$1"
  [ -d "$app" ] || { echo "No app at $app" >&2; exit 1; }
  local got_id got_ver got_build
  got_id="$(plist "$app" CFBundleIdentifier)"
  got_ver="$(plist "$app" CFBundleShortVersionString)"
  got_build="$(plist "$app" CFBundleVersion)"
  echo "name on the home screen: $(plist "$app" CFBundleDisplayName)"
  echo "bundle id: $got_id   version: $got_ver ($got_build)   minimum iOS: $(plist "$app" MinimumOSVersion)"
  echo "architectures: $(lipo -archs "$app/$name" 2>/dev/null || echo unknown)"
  echo "size: $(du -sh "$app" | cut -f1)"
  [ "$got_id" = "$bundle_id" ] || { echo "Bundle id is $got_id, expected $bundle_id" >&2; exit 1; }
  [ "$got_ver" = "$VERSION" ] || { echo "Version is $got_ver, expected $VERSION" >&2; exit 1; }
  [ "$got_build" = "$BUILD_NUMBER" ] || { echo "Build is $got_build, expected $BUILD_NUMBER" >&2; exit 1; }
  [ -f "$app/$name.pck" ] || { echo "The game data ($name.pck) is missing from the app" >&2; exit 1; }
  [ -f "$app/Assets.car" ] || { echo "No compiled asset catalog (icons) in the app" >&2; exit 1; }
  [ -f "$app/PrivacyInfo.xcprivacy" ] || echo "::warning::No privacy manifest (PrivacyInfo.xcprivacy) in the app"
}

common=(-project "$project" -scheme "$scheme" -configuration Release -sdk iphoneos -destination "generic/platform=iOS"
  -skipPackagePluginValidation -skipMacroValidation)
unsigned=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)

if [ "$mode" = "check" ]; then
  say "Unsigned build"
  xcb "$logs/build.log" "${common[@]}" -derivedDataPath "$WORK/dd" build "${unsigned[@]}"
  check_app "$WORK/dd/Build/Products/Release-iphoneos/$name.app"
  say "OK: Melt a Glacier builds for iPhone (unsigned check, nothing uploaded)"
  exit 0
fi

# ---- testflight ------------------------------------------------------------------------
keydir="$WORK/key"; mkdir -p "$keydir"; chmod 700 "$keydir"
key="$keydir/AuthKey_${ASC_KEY_ID}.p8"
cleanup() { rm -rf "$keydir"; }
trap cleanup EXIT
umask 077
case "$ASC_KEY_P8" in
  *"BEGIN PRIVATE KEY"*) printf '%s\n' "$ASC_KEY_P8" > "$key" ;;
  *) printf '%s' "$ASC_KEY_P8" | base64 --decode > "$key" 2>/dev/null || { echo "ASC_KEY_P8 is neither the .p8 text nor base64 of it" >&2; exit 3; } ;;
esac
grep -q "BEGIN PRIVATE KEY" "$key" || { echo "ASC_KEY_P8 does not look like an App Store Connect .p8 key" >&2; exit 3; }
auth=(-allowProvisioningUpdates -authenticationKeyPath "$key" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>${APPLE_TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST

archive="$WORK/$name.xcarchive"
say "Archive (unsigned)"
xcb "$logs/archive.log" "${common[@]}" -archivePath "$archive" archive "${unsigned[@]}"
check_app "$archive/Products/Applications/$name.app"
# An unsigned archive leaves the embedded SDK frameworks (Google Mobile Ads, User
# Messaging Platform) without a signature the export will replace, and Apple then
# rejects them. Giving each one an ad hoc signature first lets the export re-sign
# them with the distribution certificate along with the app.
say "Prepare the embedded frameworks for signing"
for fw in "$archive/Products/Applications/$name.app/Frameworks/"*.framework; do
  [ -d "$fw" ] || continue
  before="$(codesign -dv "$fw" 2>&1 | grep -E '^(Authority|Signature)=' | head -1 || true)"
  codesign --force --sign - --timestamp=none "$fw"
  echo "$(basename "$fw"): was ${before:-unsigned}, now ad hoc signed"
done
say "Sign and upload to TestFlight"
# Xcode signs for the App Store with a cloud-managed certificate while it uploads
# (needs an Admin-role API key; no certificate or device on the build machine).
xcb "$logs/upload.log" -exportArchive -archivePath "$archive" -exportOptionsPlist "$WORK/ExportOptions.plist" -exportPath "$WORK/export" "${auth[@]}"
say "OK: Melt a Glacier $VERSION ($BUILD_NUMBER, $FLAVOR) uploaded. It shows in TestFlight after Apple finishes processing."
