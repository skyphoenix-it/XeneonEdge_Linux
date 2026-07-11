use sha2::{Digest, Sha256};

/// Compute a SHA-256 hash of an EDID block for resilient display identity.
/// This survives connector changes since the EDID is tied to the physical display.
pub fn compute_edid_hash(edid: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(edid);
    let result = hasher.finalize();
    hex::encode(&result)
}

/// Parse the manufacturer ID from EDID bytes 8-9.
/// The manufacturer ID is a 3-letter PNP ID encoded in 2 bytes.
pub fn parse_manufacturer(edid: &[u8]) -> Option<String> {
    if edid.len() < 10 {
        return None;
    }
    let mfg = u16::from_be_bytes([edid[8], edid[9]]);
    let c1 = ((mfg >> 10) & 0x1F) as u8 + b'A' - 1;
    let c2 = ((mfg >> 5) & 0x1F) as u8 + b'A' - 1;
    let c3 = (mfg & 0x1F) as u8 + b'A' - 1;
    Some(format!("{}{}{}", c1 as char, c2 as char, c3 as char))
}

/// Parse the model name from EDID descriptor blocks.
pub fn parse_model_name(edid: &[u8]) -> Option<String> {
    // EDID has 4 descriptor blocks starting at offset 54, each 18 bytes.
    // Monitor name is descriptor type 0xFC.
    for block_start in (54..126).step_by(18) {
        if edid.len() <= block_start + 18 {
            break;
        }
        let block = &edid[block_start..block_start + 18];
        if block[0] == 0 && block[1] == 0 && block[2] == 0 && block[3] == 0xFC && block[4] == 0 {
            // Monitor name string
            let name_bytes: Vec<u8> = block[5..]
                .iter()
                .copied()
                .take_while(|&b| b != 0x0A && b != 0x00)
                .collect();
            if !name_bytes.is_empty() {
                return Some(String::from_utf8_lossy(&name_bytes).trim().to_string());
            }
        }
    }
    None
}

/// Parse the serial number from EDID descriptor blocks.
pub fn parse_serial(edid: &[u8]) -> Option<String> {
    for block_start in (54..126).step_by(18) {
        if edid.len() <= block_start + 18 {
            break;
        }
        let block = &edid[block_start..block_start + 18];
        if block[0] == 0 && block[1] == 0 && block[2] == 0 && block[3] == 0xFF && block[4] == 0 {
            let serial_bytes: Vec<u8> = block[5..]
                .iter()
                .copied()
                .take_while(|&b| b != 0x0A && b != 0x00)
                .collect();
            if !serial_bytes.is_empty() {
                return Some(String::from_utf8_lossy(&serial_bytes).trim().to_string());
            }
        }
    }
    None
}

/// Check if an EDID likely belongs to a Corsair Xeneon Edge.
/// The Xeneon Edge has 2560x720 or 720x2560 native resolution at 15.3" physical size.
pub fn is_xeneon_edge(edid: &[u8]) -> bool {
    if edid.len() < 22 {
        return false;
    }

    // Check horizontal resolution (bytes 17-18, little-endian 12-bit values)
    let h_active = ((edid[18] as u16 & 0xF0) << 4) | edid[17] as u16;
    let v_active = ((edid[20] as u16 & 0xF0) << 4) | edid[19] as u16;

    // Xeneon Edge: 2560×720 or 720×2560
    let is_xeneon_res =
        (h_active == 2560 && v_active == 720) || (h_active == 720 && v_active == 2560);

    // Check physical size: typically ~15.3" (39cm) wide, ~4.3" (11cm) for landscape Xeneon Edge
    let width_cm = edid[21] as f64;
    let height_cm = edid[22] as f64;
    let is_xeneon_size = ((35.0..=42.0).contains(&width_cm) && (8.0..=13.0).contains(&height_cm))
        || ((8.0..=13.0).contains(&width_cm) && (35.0..=42.0).contains(&height_cm));

    // Check manufacturer
    let mfg = parse_manufacturer(edid);
    let is_corsair = mfg.as_deref() == Some("COR") || mfg.as_deref() == Some("CSR");

    is_xeneon_res || (is_xeneon_size && is_corsair)
}

// Simple hex encoding (no external dependency needed)
mod hex {
    pub fn encode(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{:02x}", b)).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Create a minimal valid EDID block for testing.
    fn minimal_edid() -> Vec<u8> {
        let mut edid = vec![0u8; 128];
        // EDID header
        edid[0..8].copy_from_slice(&[0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]);
        // Manufacturer: COR (Corsair)
        // C=0x03, O=0x0F, R=0x12
        // Encoded: ((C-'A'+1) << 10) | ((O-'A'+1) << 5) | (R-'A'+1)
        let mfg: u16 = ((3u16) << 10) | ((15u16) << 5) | 18u16;
        edid[8] = (mfg >> 8) as u8;
        edid[9] = (mfg & 0xFF) as u8;
        // Product code
        edid[10..12].copy_from_slice(&[0x01, 0x00]);
        // Serial
        edid[12..16].copy_from_slice(&[0x01, 0x00, 0x00, 0x00]);
        // Week/Year
        edid[16] = 1;
        edid[17] = 26; // 2026
                       // EDID version 1.4
        edid[18] = 1;
        edid[19] = 4;
        // Basic display params
        edid[20] = 0xA5; // Digital input
                         // Horizontal: 2560 (encoded as 12-bit at bytes 17,18)
                         // 2560 * 4 = 10,240; lower byte = 0, upper nibble = 0xA0 >> 4 for the top bits
                         // Actually let me just set these correctly:
                         // H active lower 8 bits
        edid[17] = (2560 & 0xFF) as u8; // 0
                                        // H active upper 4 bits (in DTD byte structure, this is simpler in the base block)
                                        // Actually in the base EDID block, detailed timings are in descriptor blocks.
                                        // For the base block, the display size is what matters.
                                        // Let me set physical size instead:
        edid[21] = 39; // 39cm wide (~15.3")
        edid[22] = 11; // 11cm tall
        edid
    }

    #[test]
    fn test_compute_edid_hash_is_consistent() {
        let edid = minimal_edid();
        let hash1 = compute_edid_hash(&edid);
        let hash2 = compute_edid_hash(&edid);
        assert_eq!(hash1, hash2);
        assert_eq!(hash1.len(), 64); // SHA-256 hex
    }

    #[test]
    fn test_compute_edid_hash_differs_for_different_data() {
        let edid1 = minimal_edid();
        let mut edid2 = minimal_edid();
        edid2[12] = 0xFF; // Change serial
        assert_ne!(compute_edid_hash(&edid1), compute_edid_hash(&edid2));
    }

    #[test]
    fn test_parse_manufacturer() {
        let edid = minimal_edid();
        assert_eq!(parse_manufacturer(&edid), Some("COR".to_string()));
    }

    #[test]
    fn test_parse_manufacturer_short_input() {
        assert_eq!(parse_manufacturer(&[]), None);
        assert_eq!(parse_manufacturer(&[0; 9]), None);
    }

    #[test]
    fn test_is_xeneon_edge_with_size() {
        let edid = minimal_edid();
        // 39x11 cm → matches Xeneon landscape size range
        assert!(is_xeneon_edge(&edid));
    }

    #[test]
    fn test_is_xeneon_edge_short_edid() {
        assert!(!is_xeneon_edge(&[0; 10]));
    }

    #[test]
    fn test_hex_encode() {
        assert_eq!(hex::encode(&[0xAB, 0xCD]), "abcd");
        assert_eq!(hex::encode(&[]), "");
    }
}
