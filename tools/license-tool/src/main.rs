//! xeneon-license — the issuer's key tool. NOT shipped in the app.
//!
//!   keygen                          generate the issuer keypair (once, ever)
//!   mint --seed <b64> --to <name> --id <id> [--expires <unix|never>] [--tier pro]
//!                                   sign one licence key
//!
//! The key format is exactly what core/src/license.rs verifies:
//!   XE1.<base64url(payload_json)>.<base64url(ed25519_sig)>
//! and the signature covers the ASCII bytes of `XE1.<base64url(payload)>` (the
//! ENCODED form — the JWT rule). We reuse the app's own `b64url_encode` so a
//! minted key can never encode differently from what the app decodes.

use ed25519_dalek::{Signer, SigningKey};
use std::process::exit;
use xeneon_core::license::b64url_encode;

fn die(msg: &str) -> ! {
    eprintln!("error: {msg}");
    exit(2);
}

fn arg_val(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1))
        .cloned()
}

fn seed_from_b64(s: &str) -> [u8; 32] {
    let bytes = xeneon_core::license::b64url_decode(s)
        .unwrap_or_else(|| die("--seed is not valid base64url"));
    if bytes.len() != 32 {
        die("--seed must decode to exactly 32 bytes");
    }
    let mut out = [0u8; 32];
    out.copy_from_slice(&bytes);
    out
}

// Minimal JSON string escaping for the two free-text fields (name, id). The
// payload is small and hand-built so the tool has no serde dependency; only `"`
// and `\` and control chars need escaping for valid JSON.
fn json_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

fn keygen() {
    let mut seed = [0u8; 32];
    getrandom::getrandom(&mut seed).unwrap_or_else(|_| die("no OS randomness available"));
    let sk = SigningKey::from_bytes(&seed);
    let pk = sk.verifying_key();

    println!("Xeneon Edge licence keypair — generate this ONCE.\n");
    println!("1) PUBLIC key — paste into core/src/license.rs, replacing the all-zero");
    println!("   ISSUER_PUBLIC_KEY placeholder (this is what arms verification):\n");
    print!("const ISSUER_PUBLIC_KEY: [u8; 32] = [");
    for (i, b) in pk.to_bytes().iter().enumerate() {
        if i % 12 == 0 {
            print!("\n    ");
        }
        print!("{b}, ");
    }
    println!("\n];\n");
    println!("2) PRIVATE seed — the SECRET. Store it in your password manager and");
    println!("   NEVER commit it. It is what `mint --seed` needs to sign keys.");
    println!("   Anyone with this seed can issue Pro licences:\n");
    println!("   {}\n", b64url_encode(&seed));
    println!("If this seed ever leaks: generate a new keypair, ship the new public");
    println!("key in an app update, and every key signed with the old seed stops");
    println!("verifying (fails soft to free).");
}

fn mint(args: &[String]) {
    let seed_b64 = arg_val(args, "--seed").unwrap_or_else(|| die("--seed <base64url> is required"));
    let issued_to = arg_val(args, "--to").unwrap_or_else(|| die("--to <name/email> is required"));
    let id = arg_val(args, "--id").unwrap_or_else(|| die("--id <licence id> is required"));
    let tier = arg_val(args, "--tier").unwrap_or_else(|| "pro".to_string());
    // --expires: a Unix timestamp, or "never" for perpetual. Perpetual is the
    // default so a one-time purchase does not silently expire.
    let expires = match arg_val(args, "--expires").as_deref() {
        None | Some("never") | Some("none") => "null".to_string(),
        Some(v) => v
            .parse::<i64>()
            .map(|n| n.to_string())
            .unwrap_or_else(|_| die("--expires must be a Unix timestamp or 'never'")),
    };

    let payload = format!(
        r#"{{"tier":"{}","expires":{},"issued_to":"{}","id":"{}"}}"#,
        json_escape(&tier),
        expires,
        json_escape(&issued_to),
        json_escape(&id)
    );

    println!("{}", sign_payload(&seed_from_b64(&seed_b64), &payload));
}

// Sign a payload into a full XE1 key. The signature covers the ENCODED form
// `XE1.<b64(payload)>` — the exact bytes license.rs reconstructs and verifies.
// Do NOT sign the raw JSON.
fn sign_payload(seed: &[u8; 32], payload: &str) -> String {
    let sk = SigningKey::from_bytes(seed);
    let signed = format!("XE1.{}", b64url_encode(payload.as_bytes()));
    let sig = sk.sign(signed.as_bytes());
    format!("{}.{}", signed, b64url_encode(&sig.to_bytes()))
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("keygen") => keygen(),
        Some("mint") => mint(&args),
        _ => {
            eprintln!("usage:");
            eprintln!("  xeneon-license keygen");
            eprintln!("  xeneon-license mint --seed <b64> --to <name> --id <id> \\");
            eprintln!("                      [--tier pro] [--expires <unix|never>]");
            exit(2);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signature, Verifier};

    // A minted key must (a) be the XE1.<b64>.<b64> shape, (b) carry a signature
    // that verifies against the seed's PUBLIC key over the encoded form, and (c)
    // decode back to the payload we asked for. If any of these drift, real keys
    // stop verifying in the app — so this is the crypto contract, checked without
    // touching the app's compiled-in issuer.
    #[test]
    fn a_minted_key_verifies_against_its_public_key() {
        let seed = [42u8; 32];
        let key = sign_payload(
            &seed,
            r#"{"tier":"pro","expires":null,"issued_to":"Ada","id":"XE-1"}"#,
        );

        let parts: Vec<&str> = key.split('.').collect();
        assert_eq!(parts.len(), 3, "shape XE1.<payload>.<sig>: {key}");
        assert_eq!(parts[0], "XE1");

        // Signature verifies over `XE1.<payload_b64>` (the encoded form).
        let signed = format!("{}.{}", parts[0], parts[1]);
        let sig_bytes = xeneon_core::license::b64url_decode(parts[2]).unwrap();
        let sig = Signature::from_bytes(&sig_bytes.try_into().unwrap());
        let pk = SigningKey::from_bytes(&seed).verifying_key();
        assert!(
            pk.verify(signed.as_bytes(), &sig).is_ok(),
            "signature must verify against the seed's public key"
        );

        // Payload round-trips.
        let payload = xeneon_core::license::b64url_decode(parts[1]).unwrap();
        let json = String::from_utf8(payload).unwrap();
        assert!(json.contains(r#""tier":"pro""#), "{json}");
        assert!(json.contains(r#""issued_to":"Ada""#));
    }

    #[test]
    fn tampering_with_the_payload_breaks_verification() {
        let seed = [9u8; 32];
        let key = sign_payload(&seed, r#"{"tier":"free","id":"x"}"#);
        let parts: Vec<&str> = key.split('.').collect();
        // Swap in a DIFFERENT payload (forge "pro") but keep the original sig.
        let forged_payload = b64url_encode(br#"{"tier":"pro","id":"x"}"#);
        let signed = format!("XE1.{forged_payload}");
        let sig_bytes = xeneon_core::license::b64url_decode(parts[2]).unwrap();
        let sig = Signature::from_bytes(&sig_bytes.try_into().unwrap());
        let pk = SigningKey::from_bytes(&seed).verifying_key();
        assert!(
            pk.verify(signed.as_bytes(), &sig).is_err(),
            "a forged payload must NOT verify with the original signature"
        );
    }

    #[test]
    fn json_escape_closes_the_injection_hole() {
        // A name with a quote must not break out of the JSON string (which would
        // let a buyer forge a higher tier via their own name field).
        let esc = json_escape(r#"a","tier":"pro","x":"b"#);
        assert!(
            !esc.contains(r#"","tier":"pro""#),
            "quote must be escaped: {esc}"
        );
        assert!(esc.contains(r#"\""#), "escaped form present");
    }
}
