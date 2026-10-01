import Foundation

struct DailyMedicationSummary: Equatable {
    let doses: [ScheduledDose]
    let completedCount: Int
    let totalCount: Int
    let priorityDose: ScheduledDose?

    init(doses: [ScheduledDose], completedCount: Int, totalCount: Int, priorityDose: ScheduledDose?) {
        self.doses = doses
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.priorityDose = priorityDose
    }
}
