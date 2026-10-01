import Foundation

struct Dosage: Equatable {
    let amount: Decimal
    let unit: DosageUnit

    init?(amount: Decimal, unit: DosageUnit) {
        guard amount > 0 else {
            return nil
        }

        self.amount = amount
        self.unit = unit
    }
}
