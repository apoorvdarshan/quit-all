#!/bin/bash
# Builds the Debug app for a simulator and runs the unit and UI tests.
# Unsigned simulator build only: it never archives, uploads or publishes anything.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

derived_data="${IOS_TEST_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/QuitAll-simulator-tests}"
packages="${IOS_TEST_PACKAGES:-$derived_data/SourcePackages}"
results="${IOS_TEST_RESULTS:-$derived_data/TestResults/$(date -u +%Y%m%dT%H%M%SZ)-$$}"
mkdir -p "$results"
if [[ -e "$results/Tests.xcresult" ]]; then
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

cleanup() {
  # Only the simulator created by this invocation is removed.
  xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
  xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# English/US so currency and date text is deterministic; the UI tests also
# pass the language, locale and a UTC time zone when they launch the app.
xcodebuild test \
  -project "ios/Quit All.xcodeproj" \
  -scheme "Quit All" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -destination-timeout 120 \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$packages" \
  -onlyUsePackageVersionsFromResolvedFile \
  -resultBundlePath "$results/Tests.xcresult" \
  -testLanguage en \
  -testRegion US \
  -enableCodeCoverage YES \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$results/xcodebuild.log"

# A run that silently executed nothing must not pass: both bundles need tests.
xcrun xcresulttool get test-results tests --path "$results/Tests.xcresult" --format json \
  > "$results/tests.json"
python3 - "$results/tests.json" <<'PY'
import collections, json, sys
tree = json.load(open(sys.argv[1]))
counts = collections.Counter()
results = collections.Counter()
def walk(node, bundle=None):
    if node.get('nodeType') in ('Unit test bundle', 'UI test bundle'):
        bundle = node.get('name')
    if node.get('nodeType') == 'Test Case':
        counts[bundle] += 1
        results[node.get('result', 'unknown')] += 1
    for child in node.get('children', []):
        walk(child, bundle)
for node in tree.get('testNodes', []):
    walk(node)
for bundle in ('QuitAllTests', 'QuitAllUITests'):
    print(f'{bundle}: {counts[bundle]} tests')
print('results:', dict(results))
missing = [b for b in ('QuitAllTests', 'QuitAllUITests') if counts[b] == 0]
if missing:
    raise SystemExit(f'error: no tests ran in {", ".join(missing)}')
if results.get('Passed', 0) == 0:
    raise SystemExit('error: no test passed')
PY
echo "Results: $results/Tests.xcresult"
