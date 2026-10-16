#!/usr/bin/env bash
# Source this helper from repository scripts; all workarounds stay in a temp cache.
set -euo pipefail
ADEUX_PYTHON="${ADEUX_PYTHON:-/usr/bin/python3}"
ADEUX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADEUX_CACHE="${ADEUX_CACHE_DIR:-${TMPDIR:-/tmp}/adeux-development}"
mkdir -p "$ADEUX_CACHE"
export CLANG_MODULE_CACHE_PATH="$ADEUX_CACHE/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$ADEUX_CACHE/modules"
ADEUX_SWIFT_ARGS=(--scratch-path "${ADEUX_BUILD_DIR:-$ADEUX_ROOT/.build}" --cache-path "$ADEUX_CACHE/spm" --config-path "$ADEUX_CACHE/config" --security-path "$ADEUX_CACHE/security" --disable-sandbox)
ADEUX_COMPILER_ARGS=()
ADEUX_TEST_ARGS=()
ADEUX_DEVELOPER="$(xcode-select -p)"
# Some standalone CLT installations contain Swift 6 public and Swift 5 private
# PackageDescription interfaces. Use a temporary public-interface-only copy.
if [[ "$ADEUX_DEVELOPER" == */CommandLineTools ]]; then
    ADEUX_MANIFEST="$ADEUX_DEVELOPER/usr/lib/swift/pm/ManifestAPI"
    if [[ -f "$ADEUX_MANIFEST/PackageDescription.swiftmodule/arm64-apple-macos.private.swiftinterface" ]] && "$ADEUX_PYTHON" - "$ADEUX_MANIFEST" <<'PY'
from pathlib import Path
import re, sys
root = Path(sys.argv[1]) / 'PackageDescription.swiftmodule'
def version(name):
    text = (root / name).read_text()
    match = re.search(r'swift-compiler-version: Apple Swift version (\d+)', text)
    return match.group(1) if match else ''
sys.exit(0 if version('arm64-apple-macos.swiftinterface') != version('arm64-apple-macos.private.swiftinterface') else 1)
PY
    then
        "$ADEUX_PYTHON" - "$ADEUX_MANIFEST" "$ADEUX_CACHE" <<'PY'
from pathlib import Path
import shutil, sys
source, cache = map(Path, sys.argv[1:])
fixed = cache / 'ManifestAPI'
module = fixed / 'PackageDescription.swiftmodule'
module.mkdir(parents=True, exist_ok=True)
for path in (source / 'PackageDescription.swiftmodule').glob('*-apple-macos.swiftinterface'):
    destination = module / path.name
    if not destination.exists() or destination.read_bytes() != path.read_bytes():
        shutil.copy2(path, destination)
library = source / 'libPackageDescription.dylib'
if not (fixed / library.name).exists() or (fixed / library.name).stat().st_mtime_ns != library.stat().st_mtime_ns:
    shutil.copy2(library, fixed / library.name)
# source is <developer>/usr/lib/swift/pm/ManifestAPI.
compiler = source.parents[3] / 'bin/swiftc'
wrapper = cache / 'swiftc-wrapper'
content = '#!/usr/bin/python3\nimport os,sys\nsource='+repr(str(source))+'\nfixed='+repr(str(fixed))+'\ncompiler='+repr(str(compiler))+'\nargs=[arg.replace(source,fixed) for arg in sys.argv[1:]]\nos.execv(compiler,[compiler]+args)\n'
if not wrapper.exists() or wrapper.read_text() != content:
    import tempfile, os
    descriptor, temporary = tempfile.mkstemp(dir=cache, prefix='swiftc-wrapper-')
    with os.fdopen(descriptor, 'w') as file:
        file.write(content)
    os.chmod(temporary, 0o755)
    os.replace(temporary, wrapper)
PY
        export SWIFT_EXEC="$ADEUX_CACHE/swiftc-wrapper"
    fi
    ADEUX_SWIFT_ARGS+=(--build-system native)
    ADEUX_FRAMEWORKS="$ADEUX_DEVELOPER/Library/Developer/Frameworks"
    if [[ -d "$ADEUX_FRAMEWORKS/Testing.framework" ]]; then
        ADEUX_COMPILER_ARGS+=(-Xswiftc -F -Xswiftc "$ADEUX_FRAMEWORKS")
        ADEUX_TEST_ARGS+=(-Xswiftc -external-plugin-path -Xswiftc "$ADEUX_DEVELOPER/usr/lib/swift/host/plugins/testing#$ADEUX_DEVELOPER/usr/bin/swift-plugin-server" -Xlinker -F -Xlinker "$ADEUX_FRAMEWORKS" -Xlinker -rpath -Xlinker "$ADEUX_FRAMEWORKS" -Xlinker -rpath -Xlinker "$ADEUX_DEVELOPER/Library/Developer/usr/lib")
    fi
fi
