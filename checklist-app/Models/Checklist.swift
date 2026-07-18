//
//  Checklist.swift
//  checklist-app
//
//  Created by Ace on 2026-07-14.
//

import Foundation
import SwiftData

/// A named checklist grouped by where work happens (`area`: FOH/BOH) and how
/// often it recurs (`cadence`: daily/weekly). Daily checklists carry a `phase`
/// (opening/closing); weekly checklists leave `phase` nil — their duties are
/// bound to a `Weekday`, not a service phase. Owns an ordered list of duties
/// (`TaskItem`). See CONTEXT.md.
@Model
final class Checklist {
    var title: String
    var area: Area
    var cadence: Cadence
    /// Nil for weekly checklists (weekly duties are bound to a `Weekday`,
    /// not a service phase).
    var phase: Phase?
    var createdAt: Date
    var updatedAt: Date

    /// The ordered duties within this checklist.
    /// `.cascade`: deleting a checklist also deletes its duties (and, via
    /// TaskItem's own cascade, their completion logs).
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.checklist)
    var tasks: [TaskItem] = []

    init(
        title: String,
        area: Area,
        cadence: Cadence,
        phase: Phase? = nil,
        createdAt: Date = .now
    ) {
        self.title = title
        self.area = area
        self.cadence = cadence
        self.phase = phase
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
