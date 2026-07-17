# Licensing — the Pro tier

Xeneon Edge is free and fully functional. **Pro** is a low-cost "supporter" tier
that unlocks cosmetic/convenience extras — premium themes, premium preset packs,
and custom user widgets. Nothing functional is ever gated: every widget
(including the live-data HTTP/JSON and KPI ones), all accessibility, the base
themes and the base preset library stay free.

## How it works (and why it's private)

A Pro key is an **offline, signed token** — `XE1.<payload>.<signature>` — verified
against a public key compiled into the app (`core/src/license.rs`,
`ISSUER_PUBLIC_KEY`). Verifying a key:

- opens **no socket, reads no file, uses no hardware fingerprint** — the answer is
  identical under `unshare -n`. There is no "phone home" and no activation server.
- **fails soft**: any bad key — empty, garbage, forged, expired, or signed for a
  future format — resolves to the free tier. It never panics and never blocks the
  app.
- is **not a secret**: the key is safe to store in plain `config.toml`
  (`license_key = "XE1…"`). It grants nothing on its own; the entitlement is
  recomputed from the signature every time.

The tier flows: config → Rust verifier → `LicenseBridge` (hub) /
`ManagerBackend` (Manager) → QML gates on `license.isPro`. A key pasted in the
Manager while the hub is connected is pushed over the control socket so the hub
persists it (single-writer) and re-gates **live, without a restart**.

## One-time setup: arm the licensing (yours to do, like GPG signing)

The shipped `ISSUER_PUBLIC_KEY` is an **all-zero placeholder**, so until you arm
it *every key verifies as free* — the mechanism is complete but inert.

1. Generate the issuer keypair **once, ever**:

   ```
   cargo run -q --manifest-path tools/license-tool/Cargo.toml -- keygen
   ```

2. Paste the printed **public key** into `core/src/license.rs`, replacing the
   `ISSUER_PUBLIC_KEY` placeholder. Commit that (it's public).

3. Store the printed **private seed** in your password manager (next to the GPG
   signing key). **Never commit it.** Anyone with the seed can mint Pro keys.

## Selling: Lemon Squeezy (or Gumroad)

Both can auto-deliver a licence key on purchase. Two integration shapes:

- **Simplest:** let the store deliver a purchase, and mint the key yourself from
  the order (manually or via a webhook that calls the mint tool) and e-mail it.
  Fine at low volume.
- **Automated:** deploy the mint webhook (`tools/license-webhook`) and register it
  with `scripts/setup-lemonsqueezy.py`. On every purchase it verifies the webhook
  signature, mints the buyer's key (same signing code as the CLI), and e-mails it.
  The seed lives only in that service's environment — never here, never in CI, and
  never with anyone else. See `tools/license-webhook/README.md`.

Create the product (name, price, description, image) once in the Lemon Squeezy
dashboard — it needs human input and the dashboard is the right place. The price
does not affect the app. Point the app's in-Manager "Get Pro" button at the
product URL.

## Issuing a key

Never put the seed on the command line (shell history, `ps`). Pass it by env or
file:

```
export XENEON_LICENSE_SEED="$(cat ~/.secrets/xeneon-license-seed)"
./scripts/mint-license.sh --to "Ada Lovelace <ada@example.com>" --id XE-0007
# → XE1.eyJ0aWVy…
```

Options: `--to <name/email>` and `--id <id>` are required; `--tier` defaults to
`pro`; `--expires` defaults to `never` (a one-time purchase shouldn't silently
expire — pass a Unix timestamp for a subscription).

The buyer pastes the key into **Manager → About → Activate Pro**. It verifies
offline as they type (they see "unlocks Pro for <name>" before committing).

## If the seed ever leaks

Generate a new keypair, ship the new public key in an app update, and every key
signed with the old seed stops verifying (fails soft to free). Re-issue current
customers' keys under the new seed. This is why every key carries an `id` —
support and re-issue.

## What's Pro (adjustable)

Gating is a `pro:` flag on catalog items plus one `license.isPro` check, so moving
something in or out of Pro is a one-line change. Current intent: premium
theme/skin pack, premium preset pack, and custom user widgets. Functional widgets,
accessibility, base themes, and the base presets are always free.
