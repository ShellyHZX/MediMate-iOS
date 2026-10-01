import Foundation

struct Medication: Equatable, Identifiable {
    let id: UUID
    let name: String
    let dosage: Dosage
    let instructions: String?
    let schedule: DoseSchedule
    let isActive: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        dosage: Dosage,
        instructions: String? = nil,
        schedule: DoseSchedule,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.instructions = instructions
        self.schedule = schedule
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
