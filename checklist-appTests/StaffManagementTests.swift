//
//  StaffManagementTests.swift
//  checklist-appTests
//
//  Pure-logic tests for the permission helpers in
//  `StaffManagement/StaffManagement.swift`. No SwiftData container needed —
//  `User` instances are constructed detached and never inserted, since the
//  helpers only read `id`, `role`, and `isManager`. Mirrors the
//  `PinHasherTests.swift` AAA style.
//
//  See `docs/adr/0003-staff-management-and-duty-permissions.md` for the
//  locked-in rules: self-protection (cannot delete/demote self) and
//  last-manager protection (store always retains >=1 manager).
//

import XCTest
@testable import checklist_app

final class StaffManagementTests: XCTestCase {

    /// Detached user — not inserted into any ModelContext. Sufficient for
    /// testing pure permission logic which only reads properties.
    private func makeUser(name: String = "User", role: UserRole = .staff) -> User {
        User(name: name, role: role)
    }

    // MARK: - canCreateUser

    func testCanCreateUser_manager_returnsTrue() {
        let manager = makeUser(role: .manager)
        XCTAssertTrue(StaffManagement.canCreateUser(currentUser: manager))
    }

    func testCanCreateUser_staff_returnsFalse() {
        let staff = makeUser(role: .staff)
        XCTAssertFalse(StaffManagement.canCreateUser(currentUser: staff))
    }

    // MARK: - canEdit (rename / reset PIN)

    func testCanEdit_managerEditingSelf_returnsTrue() {
        // A manager changing their own name or PIN is allowed — it's their
        // own account.
        let manager = makeUser(role: .manager)
        XCTAssertTrue(StaffManagement.canEdit(user: manager, currentUser: manager))
    }

    func testCanEdit_managerEditingOther_returnsTrue() {
        let manager = makeUser(name: "Alex", role: .manager)
        let staff = makeUser(name: "Sam", role: .staff)
        XCTAssertTrue(StaffManagement.canEdit(user: staff, currentUser: manager))
    }

    func testCanEdit_staffEditingSelf_returnsFalse() {
        // Staff cannot manage users at all — including themselves.
        let staff = makeUser(role: .staff)
        XCTAssertFalse(StaffManagement.canEdit(user: staff, currentUser: staff))
    }

    func testCanEdit_staffEditingOther_returnsFalse() {
        let staff = makeUser(name: "Alex", role: .staff)
        let other = makeUser(name: "Sam", role: .staff)
        XCTAssertFalse(StaffManagement.canEdit(user: other, currentUser: staff))
    }

    // MARK: - canPromote (staff -> manager)

    func testCanPromote_managerPromotingStaff_returnsTrue() {
        let manager = makeUser(role: .manager)
        let staff = makeUser(role: .staff)
        XCTAssertTrue(StaffManagement.canPromote(user: staff, currentUser: manager))
    }

    func testCanPromote_managerPromotingManager_returnsFalse() {
        // Already a manager; the promote button should hide (no-op).
        let m1 = makeUser(name: "Alex", role: .manager)
        let m2 = makeUser(name: "Sam", role: .manager)
        XCTAssertFalse(StaffManagement.canPromote(user: m2, currentUser: m1))
    }

    func testCanPromote_staffPromoting_returnsFalse() {
        let staff = makeUser(role: .staff)
        let other = makeUser(role: .staff)
        XCTAssertFalse(StaffManagement.canPromote(user: other, currentUser: staff))
    }

    // MARK: - canDemote (manager -> staff)

    func testCanDemote_managerDemotesAnotherManager_returnsTrue() {
        // 2 managers in the store; demoting one leaves 1 — allowed.
        let m1 = makeUser(name: "Alex", role: .manager)
        let m2 = makeUser(name: "Sam", role: .manager)
        XCTAssertTrue(StaffManagement.canDemote(user: m2, currentUser: m1, allUsers: [m1, m2]))
    }

    func testCanDemote_self_returnsFalse() {
        // Self-protection: even with another manager present, you cannot
        // demote yourself. Hand-off requires promoting someone else first.
        let m1 = makeUser(name: "Alex", role: .manager)
        let m2 = makeUser(name: "Sam", role: .manager)
        XCTAssertFalse(
            StaffManagement.canDemote(user: m1, currentUser: m1, allUsers: [m1, m2]),
            "self-protection: cannot demote self"
        )
    }

    func testCanDemote_lastManager_returnsFalse() {
        // Defense in depth: even though self-protection covers the normal
        // case, last-manager protection also fires if a buggy call site
        // passes an `allUsers` that doesn't include `currentUser`. The
        // invariant is "store must retain >=1 manager" — full stop.
        let loneManager = makeUser(name: "Sam", role: .manager)
        let currentUser = makeUser(name: "Alex", role: .manager)
        XCTAssertFalse(
            StaffManagement.canDemote(user: loneManager, currentUser: currentUser, allUsers: [loneManager]),
            "last-manager protection: cannot leave store with 0 managers"
        )
    }

    func testCanDemote_nonManagerTarget_returnsFalse() {
        // Can't demote someone who's already staff — no-op, hide the button.
        let manager = makeUser(role: .manager)
        let staff = makeUser(role: .staff)
        XCTAssertFalse(StaffManagement.canDemote(user: staff, currentUser: manager, allUsers: [manager, staff]))
    }

    func testCanDemote_staffCurrentUser_returnsFalse() {
        let staff = makeUser(role: .staff)
        let manager = makeUser(role: .manager)
        XCTAssertFalse(StaffManagement.canDemote(user: manager, currentUser: staff, allUsers: [staff, manager]))
    }

    // MARK: - canDelete

    func testCanDelete_managerDeletesStaff_returnsTrue() {
        let manager = makeUser(role: .manager)
        let staff = makeUser(role: .staff)
        XCTAssertTrue(StaffManagement.canDelete(user: staff, currentUser: manager, allUsers: [manager, staff]))
    }

    func testCanDelete_managerDeletesOtherManager_returnsTrue() {
        // 2 managers; deleting one leaves 1 — allowed.
        let m1 = makeUser(name: "Alex", role: .manager)
        let m2 = makeUser(name: "Sam", role: .manager)
        XCTAssertTrue(StaffManagement.canDelete(user: m2, currentUser: m1, allUsers: [m1, m2]))
    }

    func testCanDelete_self_returnsFalse() {
        let m1 = makeUser(name: "Alex", role: .manager)
        let m2 = makeUser(name: "Sam", role: .manager)
        XCTAssertFalse(
            StaffManagement.canDelete(user: m1, currentUser: m1, allUsers: [m1, m2]),
            "self-protection: cannot delete self"
        )
    }

    func testCanDelete_lastManager_returnsFalse() {
        // Defensive: same shape as the demote case. Guards against a partial
        // `allUsers` list at the call site.
        let loneManager = makeUser(name: "Sam", role: .manager)
        let currentUser = makeUser(name: "Alex", role: .manager)
        XCTAssertFalse(
            StaffManagement.canDelete(user: loneManager, currentUser: currentUser, allUsers: [loneManager]),
            "last-manager protection: cannot leave store with 0 managers"
        )
    }

    func testCanDelete_staffCurrentUser_returnsFalse() {
        let staff = makeUser(role: .staff)
        let manager = makeUser(role: .manager)
        XCTAssertFalse(StaffManagement.canDelete(user: manager, currentUser: staff, allUsers: [staff, manager]))
    }
}
