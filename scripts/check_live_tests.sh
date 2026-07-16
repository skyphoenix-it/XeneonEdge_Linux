#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# check_live_tests.sh — every test_*() we write must actually RUN.
#
# QtTest overloads the `_data` suffix: `test_X_data()` is the DATA PROVIDER for
# `test_X()`, not a test. So a function named `test_the_url_has_no_hourly_data()`
# is silently registered as the provider for `test_the_url_has_no_hourly()` —
# which does not exist — and QtTest runs NEITHER. It does not warn. The suite
# stays green. The guard you believe you have is inert.
#
# This is not hypothetical: it shipped three times here (2026-07-16). One was a
# weather-egress guard whose whole job was to fail if the request ever grew an
# `&hourly=` series; a deliberate sabotage proved it never fired. Another had
# stale expectations from a preset re-authoring — it never ran, so nobody knew.
#
# A test that cannot fail is worse than no test: it spends the reviewer's trust
# without earning it. So: a `test_*_data()` is legal ONLY when its `test_*()`
# partner exists in the same file.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0
while IFS= read -r file; do
    while IFS= read -r fn; do
        base="${fn%_data}"
        if ! grep -qE "function[[:space:]]+${base}[[:space:]]*\(" "$file"; then
            echo "  $file: ${fn}() never runs"
            echo "      QtTest treats it as the data provider for ${base}(), which does not exist."
            echo "      Fix: rename it so it does not end in '_data' (e.g. ..._document, ..._series)."
            fail=1
        fi
    done < <(grep -oE "function[[:space:]]+test_[A-Za-z0-9_]*_data[[:space:]]*\(" "$file" \
             | grep -oE "test_[A-Za-z0-9_]*_data")
done < <(find tests -name 'tst_*.qml' -type f | sort)

if [ "$fail" -ne 0 ]; then
    echo
    echo "FAIL: the tests above are defined but never execute (QtTest '_data' suffix)."
    exit 1
fi
echo "OK: no test_*_data() without a matching test_*() — every test can run."
