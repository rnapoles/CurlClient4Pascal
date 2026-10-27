#!/usr/bin/env sh
# Builds, then runs: unit tests, integration tests (against the bundled local
# echo server, started automatically) and the three examples as a smoke test.
#   ./test.sh            PORT via TEST_PORT (default 18080)
set -u

ROOT=$(cd "$(dirname "$0")" && pwd)
BIN="$ROOT/build/fpc/bin"
PORT=${TEST_PORT:-18080}
BASE="http://127.0.0.1:$PORT"
FAILED=0

"$ROOT/build.sh" || exit 1

echo; echo "=== Unit tests (no network) ==="
"$BIN/RunUnitTests" || FAILED=1

echo; echo "=== Integration tests (libcurl) ==="
SERVER_PID=""
if command -v python3 >/dev/null 2>&1; then
  python3 "$ROOT/tests/support/echo_server.py" "$PORT" >/dev/null 2>&1 &
  SERVER_PID=$!
  trap '[ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null' EXIT INT TERM
  i=0
  until python3 -c "import socket,sys; socket.create_connection(('127.0.0.1',$PORT),0.3).close()" 2>/dev/null; do
    i=$((i + 1)); [ "$i" -gt 50 ] && { echo "echo server did not start" >&2; exit 1; }
    sleep 0.1
  done
  HTTP_TEST_BASE_URL="$BASE" "$BIN/RunIntegrationTests" || FAILED=1

  echo; echo "=== Examples (smoke test against local server) ==="
  mkdir -p "$ROOT/build/fpc/run" && cd "$ROOT/build/fpc/run" || exit 1
  for ex in Example.Get Example.Post Example.Builder; do
    "$BIN/$ex" "$BASE" >/dev/null 2>&1 && echo "[PASS] $ex" || { echo "[FAIL] $ex"; FAILED=1; }
  done
  "$BIN/Example.Upload" "$BASE" /upload >/dev/null 2>&1 && echo "[PASS] Example.Upload" || { echo "[FAIL] Example.Upload"; FAILED=1; }
else
  echo "python3 not found: integration tests will be skipped (network-free ones still run)"
  "$BIN/RunIntegrationTests" || FAILED=1
fi

echo
[ "$FAILED" -eq 0 ] && echo "ALL GREEN" || echo "SOME TESTS FAILED"
exit "$FAILED"
