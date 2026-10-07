#!/usr/bin/env bash
# Spins up a throwaway local Postgres, applies the Nutriq migrations on top of a
# tiny Supabase auth stub, and runs the two-user RLS isolation, coach-allowance and photo-scan tests.
# Requires: initdb, pg_ctl, createdb, psql (e.g. `brew install postgresql`).
set -euo pipefail
# macOS Postgres refuses to start without a valid locale ("postmaster became multithreaded").
export LC_ALL=C LANG=C

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
cleanup() {
  pg_ctl -D "$TMP/data" stop -m fast >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

initdb -D "$TMP/data" -U postgres -A trust >/dev/null
pg_ctl -D "$TMP/data" -o "-k $TMP -c listen_addresses=''" -l "$TMP/postgres.log" -w start >/dev/null
createdb -h "$TMP" -U postgres nutriq_test

PSQL=(psql -h "$TMP" -U postgres -d nutriq_test -v ON_ERROR_STOP=1 -q)
"${PSQL[@]}" -f "$HERE/local_auth_stub.sql"
for migration in "$HERE"/../migrations/*.sql; do
  "${PSQL[@]}" -f "$migration"
done
for test in rls_isolation_test.sql coach_usage_test.sql photo_scan_test.sql; do
  "${PSQL[@]}" -t -A -f "$HERE/$test" 2>&1 | grep -E "ok - |FAIL|ERROR|passed" | sed -E 's/^psql:[^ ]+ (NOTICE:  )?//'
done
