//
//  PinHasher.swift
//  checklist-app
//
//  Pure, framework-free PIN hashing + validation. No SwiftUI, no SwiftData.
//  Mirrors the `Scheduling/DutyStatus.swift` pattern: top-level functions
//  that compose into model + UI layers above. See
//  `docs/adr/0002-auth-and-current-user-session.md`.
//

import Foundation
import CryptoKit

/// Validates that `pin` is exactly 4 ASCII digits — the format enforced
/// everywhere PINs are entered or stored. Rejects empty, wrong length, and
/// non-ASCII digits (e.g. Arabic-Indic numerals) which would otherwise
/// silently produce different hashes than the user expects.
///
/// "4 digits" is the restaurant POS industry convention and is sufficient for
/// audit attribution per the ADR's threat model.
func isValidPin(_ pin: String) -> Bool {
    guard pin.count == 4 else { return false }
    return pin.allSatisfy { ("0"..."9").contains($0) }
}

/// The required PIN length, surfaced as a constant so UI and tests can stay
/// in sync if it ever changes.
let pinLength = 4

/// Generates a cryptographically-secure random salt. `SystemRandomNumberGenerator`
/// is documented as CSPRNG on Apple platforms — sufficient for the per-user
/// salt role described in the ADR.
///
/// Default 16 bytes (128 bits) matches common practice; configurable for tests.
func generateSalt(byteCount: Int = 16) -> Data {
    var rng = SystemRandomNumberGenerator()
    var bytes = [UInt8](repeating: 0, count: byteCount)
    for i in 0..<byteCount { bytes[i] = rng.next() }
    return Data(bytes)
}

/// Hashes a PIN with its per-user salt using SHA-256, returning lowercase hex.
/// The salt is prepended to the PIN bytes before hashing so the (salt, pin)
/// pair is unambiguously hashed as a single input.
///
/// Per the ADR: this defends casual observation of the store but does **not**
/// resist brute force on the 4-digit PIN space (10,000 candidates). The iOS
/// app sandbox is the real security boundary.
func hashPin(_ pin: String, salt: Data) -> String {
    var hasher = SHA256()
    hasher.update(data: salt)
    hasher.update(data: Data(pin.utf8))
    return hasher
        .finalize()
        .map { String(format: "%02x", $0) }
        .joined()
}

/// Errors thrown by PIN mutation. The only failure mode is a malformed PIN —
/// callers validate at the UI boundary with `isValidPin`, so this surfaces
/// programmer errors (e.g. seed typos) at the call site rather than trapping.
enum PinError: Error {
    case invalidFormat
}
