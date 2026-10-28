#!/usr/bin/env sh
# Builds the examples and both test runners with Free Pascal.
#   ./build.sh            -> build/fpc/bin/*
#   FPC=/path/to/fpc ./build.sh
# Delphi users: use build.bat (Windows). Delphi for Linux needs the PAServer
# toolchain, so it is not scripted here.
set -eu

ROOT=$(cd "$(dirname "$0")" && pwd)
FPC=${FPC:-fpc}
OUT="$ROOT/build/fpc"

if ! command -v "$FPC" >/dev/null 2>&1; then
  echo "error: Free Pascal compiler '$FPC' not found (install fp-compiler / set FPC=...)" >&2
  exit 1
fi

mkdir -p "$OUT/bin" "$OUT/units"
echo "Compiler : $($FPC -iV)  ($($FPC -iTO)-$($FPC -iTP))"

FLAGS="-Mdelphi -O2 -vewn -Fi$ROOT/src -Fu$ROOT/src -Fu$ROOT/src/curl -Fu$ROOT/vendor \
-Fu$ROOT/tests/support -Fu$ROOT/tests/unit -Fu$ROOT/tests/integration \
-FU$OUT/units -FE$OUT/bin"

for prog in examples/Example.Get.dpr examples/Example.Post.dpr examples/Example.Builder.dpr examples/Example.Upload.dpr \
            tests/RunUnitTests.dpr tests/RunIntegrationTests.dpr; do
  echo "Building $prog"
  # shellcheck disable=SC2086
  "$FPC" $FLAGS "$ROOT/$prog" 2>&1 | grep -E "Error|Fatal|Warning" || true
  name=$(basename "$prog" .dpr)
  [ -x "$OUT/bin/$name" ] || { echo "BUILD FAILED: $prog" >&2; exit 1; }
done

cp "$ROOT/data/services" "$OUT/bin/services"   # bundled /etc/services copy (see Http.Services)
echo "OK -> $OUT/bin"
echo "Note: libcurl must be loadable as 'libcurl.so' (Debian/Ubuntu: apt install libcurl4-openssl-dev)."
