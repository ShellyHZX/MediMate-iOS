import Foundation
import Testing
@testable import MediMate

struct MedicationPresentationFormatterTests {
    @Test func dosageFormatsMeasurementUnitsWithoutDebugDecimalOutput() throws {
        let dosage = try #require(Dosage(amount: 500, unit: .mg))

        #expect(MedicationPresentationFormatter.dosage(dosage) == "500 mg")
    }

    @Test func dosagePluralizesTabletAndCapsuleUnits() throws {
        let oneTablet = try #require(Dosage(amount: 1, unit: .tablet))
        let twoTablets = try #require(Dosage(amount: 2, unit: .tablet))
        let oneCapsule = try #require(Dosage(amount: 1, unit: .capsule))
        let twoCapsules = try #require(Dosage(amount: 2, unit: .capsule))

        #expect(MedicationPresentationFormatter.dosage(oneTablet) == "1 tablet")
        #expect(MedicationPresentationFormatter.dosage(twoTablets) == "2 tablets")
        #expect(MedicationPresentationFormatter.dosage(oneCapsule) == "1 capsule")
        #expect(MedicationPresentationFormatter.dosage(twoCapsules) == "2 capsules")
    }

    @Test func doseTimesAreJoinedCompactly() throws {
        let morning = try #require(DoseTime(hour: 8, minute: 0))
        let evening = try #require(DoseTime(hour: 20, minute: 0))

        let formattedTimes = MedicationPresentationFormatter.doseTimes([morning, evening])

        #expect(formattedTimes.contains(" · "))
    }
}
