//
//  AuthStoreTests.swift
//  checklist-appTests
//
//  In-memory SwiftData tests for the `AuthStore` session. Covers sign-in
//  success/failure, sign-out, session persistence across "relaunch"
//  (fresh AuthStore backed by the same UserDefaults), and graceful
//  logout when the current user is deleted.
//

import XCTest
import SwiftData
@testable import checklist_app

@MainActor
final class AuthStoreTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var authStore: AuthStore!

    override func setUp() {
        super.setUp()

        // Fresh in-memory SwiftData container per test (matches the
        // `isStoredInMemoryOnly` tooling path the app itself uses under
        // previews/XCTest). Tests stay isolated, no on-disk state leaks.
        let schema = Schema([User.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        // Isolated UserDefaults suite per test — fully removed on tearDown
        // so no test reads another test's persisted session.
        suiteName = "checklist-app-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        authStore = AuthStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        authStore = nil
        defaults = nil
        context = nil
        container = nil
        suiteName = nil
        super.tearDown()
    }

    /// Helper: insert a user with a known PIN already configured.
    @discardableResult
    private func makeUser(name: String, role: UserRole = .staff, pin: String) -> User {
        let user = User(name: name, role: role)
        try! user.setPin(pin)
        context.insert(user)
        try! context.save()
        return user
    }

    // MARK: - Sign-in

    func testSignIn_correctPin_succeeds_andSetsCurrentUser() {
        let user = makeUser(name: "Alex", pin: "1234")

        let result = authStore.signIn(user: user, pin: "1234")

        XCTAssertTrue(result, "correct PIN signs in")
        XCTAssertEqual(authStore.currentUser(in: context)?.id, user.id)
    }

    func testSignIn_wrongPin_fails_andLeavesSessionUntouched() {
        let user = makeUser(name: "Alex", pin: "1234")

        let result = authStore.signIn(user: user, pin: "5678")

        XCTAssertFalse(result, "wrong PIN fails")
        XCTAssertNil(authStore.currentUser(in: context), "failed sign-in does not set a user")
    }

    func testSignIn_wrongPin_doesNotSignOutPriorUser() {
        // Shared-device scenario: Alex is signed in, Jordan picks up the
        // phone and fat-fingers their PIN. Alex's session must survive the
        // bad attempt until Jordan's correct PIN or an explicit sign-out.
        let alex = makeUser(name: "Alex", pin: "1234")
        let jordan = makeUser(name: "Jordan", pin: "5678")
        authStore.signIn(user: alex, pin: "1234")

        _ = authStore.signIn(user: jordan, pin: "0000") // wrong

        XCTAssertEqual(
            authStore.currentUser(in: context)?.id,
            alex.id,
            "wrong-PIN attempt does not sign out the prior user"
        )
    }

    func testSignIn_userWithoutPin_fails() {
        // A user exists in the directory but has never been assigned a PIN
        // (e.g. invited but not configured). Cannot sign in.
        let user = User(name: "Pending", role: .staff)
        context.insert(user)
        try! context.save()

        let result = authStore.signIn(user: user, pin: "1234")

        XCTAssertFalse(result)
        XCTAssertNil(authStore.currentUser(in: context))
    }

    // MARK: - Sign-out

    func testSignOut_clearsCurrentUser() {
        let user = makeUser(name: "Alex", pin: "1234")
        authStore.signIn(user: user, pin: "1234")

        authStore.signOut()

        XCTAssertNil(authStore.currentUser(in: context))
    }

    func testSignOut_persistenceIsClearedSoRelaunchDoesNotRestore() {
        let user = makeUser(name: "Alex", pin: "1234")
        authStore.signIn(user: user, pin: "1234")
        authStore.signOut()

        let relaunched = AuthStore(defaults: defaults)

        XCTAssertNil(relaunched.currentUser(in: context))
    }

    // MARK: - Session persistence across "relaunch"

    func testSession_restoresAcrossAuthStoreInstances() {
        // Simulates the app being backgrounded and relaunched: a fresh
        // AuthStore reading the same UserDefaults must pick up where the
        // prior session left off. The PIN is NOT re-entered — the trust
        // window extends across app lifetime per the ADR.
        let user = makeUser(name: "Alex", pin: "1234")
        authStore.signIn(user: user, pin: "1234")

        let relaunched = AuthStore(defaults: defaults)

        XCTAssertEqual(relaunched.currentUser(in: context)?.id, user.id)
    }

    func testSession_withNoPriorSession_isLoggedOut() {
        // Fresh install / first launch.
        let freshStore = AuthStore(defaults: defaults)

        XCTAssertNil(freshStore.currentUser(in: context))
    }

    // MARK: - Deleted user → logged out

    func testCurrentUser_returnsNil_ifUserDeleted() {
        // A signed-in user who is later deleted (future staff-management
        // feature) must not stay "current" — that would resurrect a
        // non-existent identity. The fetch returns nil and the UI gates
        // back to the login screen.
        let user = makeUser(name: "Alex", pin: "1234")
        authStore.signIn(user: user, pin: "1234")

        context.delete(user)
        try? context.save()

        XCTAssertNil(authStore.currentUser(in: context))
    }

    // MARK: - User PIN model coverage

    func testUserSetPin_thenMatchesPin_returnsTrue() {
        let user = User(name: "Alex", role: .staff)
        XCTAssertFalse(user.hasPin, "fresh user has no PIN")

        try! user.setPin("1234")

        XCTAssertTrue(user.hasPin)
        XCTAssertTrue(user.matchesPin("1234"))
        XCTAssertFalse(user.matchesPin("5678"))
    }

    func testUserSetPin_replacesPriorPin() {
        let user = User(name: "Alex", role: .staff)
        try! user.setPin("1234")

        try! user.setPin("5678")

        XCTAssertFalse(user.matchesPin("1234"), "old PIN no longer valid")
        XCTAssertTrue(user.matchesPin("5678"), "new PIN works")
    }

    func testUserSetPin_invalidPin_throws() {
        let user = User(name: "Alex", role: .staff)

        XCTAssertThrowsError(try user.setPin("12a4")) { error in
            guard case PinError.invalidFormat = error else {
                XCTFail("expected invalidFormat, got \(error)")
                return
            }
        }
    }

    func testUserMatchesPin_withNoPinSet_returnsFalse() {
        let user = User(name: "Alex", role: .staff)

        XCTAssertFalse(user.matchesPin("1234"), "no PIN set → no PIN matches")
    }
}
