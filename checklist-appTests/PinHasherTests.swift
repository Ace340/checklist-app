//
//  PinHasherTests.swift
//  checklist-appTests
//
//  Pure-logic tests for the PIN helpers in `Auth/PinHasher.swift`. No
//  SwiftData, no SwiftUI — covers validation rules, hash determinism, and
//  salt uniqueness. Mirrors the DutyStatusTests.swift AAA style.
//

import XCTest
@testable import checklist_app

final class PinHasherTests: XCTestCase {

    // MARK: - Slice 1: isValidPin — format rules

    func testIsValidPin_acceptsFourDigits() {
        XCTAssertTrue(isValidPin("1234"), "1234 is a valid PIN")
    }

    func testIsValidPin_acceptsAllZeros() {
        XCTAssertTrue(isValidPin("0000"), "0000 is a valid PIN (seed default)")
    }

    func testIsValidPin_acceptsAllNines() {
        XCTAssertTrue(isValidPin("9999"), "9999 is a valid PIN")
    }

    func testIsValidPin_rejectsEmpty() {
        XCTAssertFalse(isValidPin(""), "empty string is not a PIN")
    }

    func testIsValidPin_rejectsTooShort() {
        XCTAssertFalse(isValidPin("123"), "3 digits is too short")
    }

    func testIsValidPin_rejectsTooLong() {
        XCTAssertFalse(isValidPin("12345"), "5 digits is too long")
    }

    func testIsValidPin_rejectsNonDigitCharacters() {
        XCTAssertFalse(isValidPin("12a4"), "letters are not digits")
    }

    func testIsValidPin_rejectsWhitespace() {
        XCTAssertFalse(isValidPin("12 4"), "whitespace is not a digit")
    }

    func testIsValidPin_rejectsNonASCIIDigits() {
        // Arabic-Indic digit — would otherwise silently hash to a different
        // value than the user expected if we accepted it.
        XCTAssertFalse(isValidPin("١٢٣٤"), "non-ASCII digits are rejected")
    }

    // MARK: - Slice 2: hashPin — determinism

    func testHashPin_samePinSameSalt_producesSameHash() {
        let salt = generateSalt()
        let h1 = hashPin("1234", salt: salt)
        let h2 = hashPin("1234", salt: salt)
        XCTAssertEqual(h1, h2, "same PIN + same salt must hash identically")
    }

    func testHashPin_differentPin_producesDifferentHash() {
        let salt = generateSalt()
        let h1 = hashPin("1234", salt: salt)
        let h2 = hashPin("5678", salt: salt)
        XCTAssertNotEqual(h1, h2, "different PINs must hash differently")
    }

    func testHashPin_differentSalt_producesDifferentHash() {
        // The whole point of per-user salt: the same PIN across two users
        // must not produce the same hash, so a store dump doesn't reveal
        // shared PINs at a glance.
        let salt1 = generateSalt()
        let salt2 = generateSalt()
        // Guard against the (cryptographically negligible) chance of identical
        // random salts making this test flaky.
        guard salt1 != salt2 else { return }
        let h1 = hashPin("1234", salt: salt1)
        let h2 = hashPin("1234", salt: salt2)
        XCTAssertNotEqual(h1, h2, "same PIN + different salts must hash differently")
    }

    // MARK: - Slice 3: hashPin — output shape

    func testHashPin_returns64HexCharacters() {
        // SHA-256 = 32 bytes = 64 hex chars. Pins the digest length so a
        // future swap to a weaker hash (e.g. truncated) would fail loudly.
        let hash = hashPin("1234", salt: generateSalt())
        XCTAssertEqual(hash.count, 64, "SHA-256 hex output must be 64 chars")
    }

    func testHashPin_returnsLowercaseHex() {
        let hash = hashPin("1234", salt: generateSalt())
        XCTAssertTrue(
            hash.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) },
            "hash must be lowercase hex only"
        )
    }

    // MARK: - Slice 4: generateSalt — randomness

    func testGenerateSalt_returnsRequestedByteCount() {
        XCTAssertEqual(generateSalt(byteCount: 16).count, 16, "default salt is 16 bytes")
        XCTAssertEqual(generateSalt(byteCount: 32).count, 32, "explicit byteCount honored")
    }

    func testGenerateSalt_twoCallsProduceDifferentSalts() {
        // CSPRNG must not return identical salts twice in a row — if it does,
        // per-user salting provides no protection. Probability of collision
        // is ~1 in 2^128, so a single sample is sufficient.
        let salt1 = generateSalt()
        let salt2 = generateSalt()
        XCTAssertNotEqual(salt1, salt2, "two salt generations must differ")
    }
}
