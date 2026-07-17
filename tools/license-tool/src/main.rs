//! xeneon-license — the issuer's key tool. NOT shipped in the app.
//!
//!   keygen                          generate the issuer keypair (once, ever)
//!   mint --seed <b64> --to <name> --id <id> [--expires <unix|never>] [--tier pro]
//!                                   sign one licence key
//!
//! All signing goes through the shared `xeneon_license_tool` lib, so the CLI, the
//! purchase webhook, and the app's verifier can never disagree about the format.

use ed25519_dalek::SigningKey;
use std::process::exit;
use xeneon_core::license::b64url_encode;
use xeneon_license_tool::{build_payload, seed_from_b64, sign_payload};

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

    let seed = seed_from_b64(&seed_b64).unwrap_or_else(|e| die(&e));
    println!(
        "{}",
        sign_payload(&seed, &build_payload(&tier, &expires, &issued_to, &id))
    );
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
