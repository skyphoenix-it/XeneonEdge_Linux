#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# mint-license.sh — issue a Xeneon Edge Pro licence key.
#
# Thin wrapper over the issuer tool (tools/license-tool). The SECRET signing seed
# is NEVER passed on the command line (it would land in your shell history and
# `ps`); it is read from the environment or a file:
#
#   export XENEON_LICENSE_SEED="$(cat ~/.secrets/xeneon-license-seed)"   # or
#   XENEON_LICENSE_SEED_FILE=~/.secrets/xeneon-license-seed \
#     ./scripts/mint-license.sh --to "Ada Lovelace <ada@x.io>" --id XE-0007
#
# First time only — create the keypair, paste the PUBLIC key into
# core/src/license.rs, and store the PRIVATE seed in your password manager:
#
#   cargo run -q --manifest-path tools/license-tool/Cargo.toml -- keygen
#
# Options (passed through to `mint`): --to <name/email>  --id <id>
#   [--tier pro]  [--expires <unix-seconds|never>]   (default: pro, never)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

SEED="${XENEON_LICENSE_SEED:-}"
if [ -z "$SEED" ] && [ -n "${XENEON_LICENSE_SEED_FILE:-}" ]; then
    SEED="$(tr -d '[:space:]' < "$XENEON_LICENSE_SEED_FILE")"
fi
if [ -z "$SEED" ]; then
    echo "error: no signing seed. Set XENEON_LICENSE_SEED or XENEON_LICENSE_SEED_FILE." >&2
    echo "       (Run 'cargo run --manifest-path tools/license-tool/Cargo.toml -- keygen'" >&2
    echo "        once to create it, if you have not.)" >&2
    exit 2
fi

# Pass the seed only through argv of the child we control, not the parent shell's
# history. `mint` reads --seed; we splice it in ahead of the user's args.
exec cargo run -q --manifest-path tools/license-tool/Cargo.toml -- \
    mint --seed "$SEED" "$@"
