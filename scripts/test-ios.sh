#!/bin/bash
# Builds the Debug app for a simulator and runs the unit and UI tests.
# Unsigned simulator build only: it never archives, uploads or publishes anything.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

app_bundle_id="com.apoorvdarshan.Quit-All"
derived_data="${IOS_TEST_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/QuitAll-simulator-tests}"
packages="${IOS_TEST_PACKAGES:-$derived_data/SourcePackages}"
results="${IOS_TEST_RESULTS:-$derived_data/TestResults/$(date -u +%Y%m%dT%H%M%SZ)-$$}"
mkdir -p "$results"
if compgen -G "$results/*.xcresult" > /dev/null; then
  echo 'Choose an unused IOS_TEST_RESULTS directory; existing results are preserved.' >&2
  exit 1
fi

xcodebuild -version

# Create a task-owned simulator: never erase or reset a developer's existing one.
simulator_id="$(python3 - <<'PY'
import json, subprocess
data = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', '--json']))
def version(runtime):
    return tuple(int(part) for part in runtime['version'].split('.'))
runtimes = [r for r in data['runtimes'] if r.get('isAvailable') and
            '.iOS-' in r['identifier'] and version(r) >= (17, 6)]
if not runtimes:
    raise SystemExit('Install an iOS 17.6 or newer Simulator runtime in Xcode.')
runtime = max(runtimes, key=version)
iphones = [d for d in runtime.get('supportedDeviceTypes', []) if d.get('productFamily') == 'iPhone']
if not iphones:
    raise SystemExit('Selected runtime has no supported iPhone device type.')
device = next((d for d in iphones if d['name'] == 'iPhone 17 Pro'), iphones[-1])
print(subprocess.check_output(['xcrun', 'simctl', 'create', 'Quit All CI',
      device['identifier'], runtime['identifier']], text=True).strip())
PY
)"

# shellcheck disable=SC2329 # called by the EXIT trap
cleanup() {
  # Only the simulator created by this invocation is removed.
  xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
  xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
}
trap cleanup EXIT

destination=(
  -project "ios/Quit All.xcodeproj"
  -scheme "Quit All"
  -configuration Debug
  -destination "platform=iOS Simulator,id=$simulator_id"
  -destination-timeout 120
  -derivedDataPath "$derived_data"
  -clonedSourcePackagesDirPath "$packages"
  -onlyUsePackageVersionsFromResolvedFile
)

xcodebuild build-for-testing "${destination[@]}" -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$results/build.log"

# English/US so currency and date text is deterministic; the UI tests also
# pass the language, locale and a UTC time zone when they launch the app.
# Failures keep their screenshots and logs in the result bundle; the extra
# simulator sysdiagnose is skipped (collecting it can stall for 10 minutes).
# The third argument is how many simulator clones run test classes in parallel
# (1 runs everything on the created simulator).
run_bundle() {
  local bundle="$1" name="$2" workers="$3"
  local parallel=(-parallel-testing-enabled NO)
  if [ "$workers" -gt 1 ]; then
    parallel=(-parallel-testing-enabled YES -parallel-testing-worker-count "$workers")
  fi
  xcodebuild test-without-building "${destination[@]}" \
    -only-testing:"$bundle" \
    -resultBundlePath "$results/$name.xcresult" \
    -testLanguage en \
    -testRegion US \
    -enableCodeCoverage YES \
    "${parallel[@]}" \
    -maximum-concurrent-test-simulator-destinations 1 \
    -collect-test-diagnostics never \
    2>&1 | tee "$results/$name.log"
}

app_running() {
  xcrun simctl spawn "$simulator_id" launchctl list 2>/dev/null | grep -qF "UIKitApplication:${app_bundle_id}["
}

status=0
run_bundle QuitAllTests UnitTests 1 || status=1

# The unit tests run inside the app, and the UI tests use the same app. Stop
# that test host and wait until it is gone, so the first UI test launches the
# app cleanly instead of racing the host's shutdown.
xcrun simctl terminate "$simulator_id" "$app_bundle_id" >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  app_running || break
  sleep 0.5
done
if app_running; then
  echo "error: the unit-test host app did not exit; not starting the UI tests" >&2
  exit 1
fi

# Each UI test class runs on one of two simulator clones. Every clone has its
# own app data, and each test launches with --ui-testing-reset.
run_bundle QuitAllUITests UITests 2 || status=1

# A run that silently executed nothing must not pass: both bundles need tests.
python3 - "$results" <<'PY'
import collections, json, subprocess, sys
results = sys.argv[1]
counts = collections.Counter()
outcomes = collections.Counter()
def walk(node, bundle=None):
    if node.get('nodeType') in ('Unit test bundle', 'UI test bundle'):
        bundle = node.get('name')
    if node.get('nodeType') == 'Test Case':
        counts[bundle] += 1
        outcomes[node.get('result', 'unknown')] += 1
    for child in node.get('children', []):
        walk(child, bundle)
for name in ('UnitTests', 'UITests'):
    tree = json.loads(subprocess.check_output(
        ['xcrun', 'xcresulttool', 'get', 'test-results', 'tests',
         '--path', f'{results}/{name}.xcresult', '--format', 'json']))
    for node in tree.get('testNodes', []):
        walk(node)
for bundle in ('QuitAllTests', 'QuitAllUITests'):
    print(f'{bundle}: {counts[bundle]} tests')
print('results:', dict(outcomes))
missing = [b for b in ('QuitAllTests', 'QuitAllUITests') if counts[b] == 0]
if missing:
    raise SystemExit(f'error: no tests ran in {", ".join(missing)}')
PY
echo "Results: $results"
exit "$status"
