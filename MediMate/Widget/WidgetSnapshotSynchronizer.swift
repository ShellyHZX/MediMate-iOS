import Foundation
import WidgetKit

protocol WidgetSnapshotSynchronizing {
    func sync(referenceDate: Date) async
}

struct WidgetSnapshotSynchronizer: WidgetSnapshotSynchronizing {
    private let reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase
    private let snapshotStore: MedicationWidgetSnapshotStore
    private let calendar: Calendar

    init(
        reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase,
        snapshotStore: MedicationWidgetSnapshotStore,
        calendar: Calendar
    ) {
        self.reviewTodaysMedicationUseCase = reviewTodaysMedicationUseCase
        self.snapshotStore = snapshotStore
        self.calendar = calendar
    }

    func sync(referenceDate: Date) async {
        do {
            let summary = try await reviewTodaysMedicationUseCase.execute(referenceDate: referenceDate)
            let snapshot = makeSnapshot(from: summary, referenceDate: referenceDate)
            try snapshotStore.write(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: MedicationWidgetSharedConfiguration.widgetKind)
        } catch {
            print("Widget snapshot sync failed: \(error)")
        }
    }

    private func makeSnapshot(
        from summary: DailyMedicationSummary,
        referenceDate: Date
    ) -> MedicationWidgetSnapshot {
        let moments = moments(from: summary.doses)
        let finalizedCount = moments.reduce(0) { $0 + $1.finalizedCount }

        return MedicationWidgetSnapshot(
            generatedAt: referenceDate,
            dayStart: calendar.startOfDay(for: referenceDate),
            completedCount: finalizedCount,
            totalCount: summary.totalCount,
            moments: moments
        )
    }

    private func moments(from doses: [ScheduledDose]) -> [MedicationWidgetMoment] {
        var dosesByMoment: [Date: [ScheduledDose]] = [:]

        for dose in doses {
            let momentDate = calendarMinute(for: dose.scheduledAt)
            dosesByMoment[momentDate, default: []].append(dose)
        }

        return dosesByMoment
            .map { scheduledAt, momentDoses in
                let sortedDoses = momentDoses.sorted {
                    if $0.medicationName == $1.medicationName {
                        return $0.id.uuidString < $1.id.uuidString
                    }

                    return $0.medicationName.localizedStandardCompare($1.medicationName) == .orderedAscending
                }
                let items = sortedDoses.map { dose in
                    MedicationWidgetItem(
                        id: dose.id,
                        name: dose.medicationName,
                        dosageText: MedicationPresentationFormatter.dosage(dose.dosage),
                        isFinalized: isFinalized(dose)
                    )
                }

                return MedicationWidgetMoment(
                    scheduledAt: scheduledAt,
                    medications: items,
                    hasUnresolvedDoses: items.contains { !$0.isFinalized },
                    finalizedCount: items.filter(\.isFinalized).count
                )
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private func isFinalized(_ dose: ScheduledDose) -> Bool {
        switch dose.status {
        case .taken, .skipped:
            return true
        case .upcoming, .due, .missed:
            return false
        }
    }

    private func calendarMinute(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }
}
