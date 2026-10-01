import Foundation

struct ScheduledDose: Equatable, Identifiable {
    let id: UUID
    let medicationID: UUID
    let medicationName: String
    let dosage: Dosage
    let scheduledAt: Date
    let status: DoseStatus
    let takenAt: Date?

    init(
        id: UUID = UUID(),
        medicationID: UUID,
        medicationName: String,
        dosage: Dosage,
        scheduledAt: Date,
        status: DoseStatus,
        takenAt: Date? = nil
    ) {
        self.id = id
        self.medicationID = medicationID
        self.medicationName = medicationName
        self.dosage = dosage
        self.scheduledAt = scheduledAt
        self.status = status
        self.takenAt = takenAt
    }
}
