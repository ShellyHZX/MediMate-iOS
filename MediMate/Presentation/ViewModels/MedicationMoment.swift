import Foundation

struct MedicationMoment: Identifiable, Equatable {
    let scheduledAt: Date
    let doses: [ScheduledDose]

    var id: Date {
        scheduledAt
    }

    var unresolvedDoses: [ScheduledDose] {
        doses.filter { $0.status == .upcoming || $0.status == .due || $0.status == .missed }
    }

    var hasUnresolvedDoses: Bool {
        !unresolvedDoses.isEmpty
    }

    var scheduledMedicationCount: Int {
        doses.count
    }
}
