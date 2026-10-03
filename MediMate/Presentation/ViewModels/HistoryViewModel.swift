import Combine
import Foundation

struct HistoryDaySection: Identifiable, Equatable {
    let date: Date
    let doses: [ScheduledDose]

    var id: Date {
        date
    }
}

struct ActivityDaySection: Identifiable, Equatable {
    let date: Date
    let moments: [ActivityMoment]

    var id: Date {
        date
    }
}

struct ActivityMoment: Identifiable, Equatable {
    let scheduledAt: Date
    let doses: [ScheduledDose]

    var id: Date {
        scheduledAt
    }

    var recordCount: Int {
        doses.count
    }

    var summary: String {
        let parts = [
            statusSummary(count: takenCount, label: "taken"),
            statusSummary(count: skippedCount, label: "skipped"),
            statusSummary(count: missedCount, label: "missed")
        ].compactMap { $0 }

        return parts.joined(separator: " · ")
    }

    private var takenCount: Int {
        doses.filter { $0.status == .taken }.count
    }

    private var skippedCount: Int {
        doses.filter { $0.status == .skipped }.count
    }

    private var missedCount: Int {
        doses.filter { $0.status == .missed }.count
    }

    private func statusSummary(count: Int, label: String) -> String? {
        guard count > 0 else {
            return nil
        }

        return "\(count) \(label)"
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var doses: [ScheduledDose]
    @Published private(set) var isLoading: Bool
    @Published private(set) var actionInProgressDoseID: UUID?
    @Published var errorMessage: String?
    @Published var correctionErrorMessage: String?

    private let reviewMedicationHistoryUseCase: ReviewMedicationHistoryUseCase
    private let correctDoseRecordUseCase: CorrectDoseRecordUseCase
    private let calendar: Calendar
    private let referenceDateProvider: () -> Date

    var daySections: [HistoryDaySection] {
        var sections: [HistoryDaySection] = []

        for dose in doses {
            let day = calendar.startOfDay(for: dose.scheduledAt)

            if let index = sections.firstIndex(where: { $0.date == day }) {
                var sectionDoses = sections[index].doses
                sectionDoses.append(dose)
                sections[index] = HistoryDaySection(date: day, doses: sectionDoses)
            } else {
                sections.append(HistoryDaySection(date: day, doses: [dose]))
            }
        }

        return sections
    }

    var activityDaySections: [ActivityDaySection] {
        let finalizedDoses = doses.filter { dose in
            switch dose.status {
            case .taken, .skipped, .missed:
                return true
            case .upcoming, .due:
                return false
            }
        }

        var dosesByDay: [Date: [ScheduledDose]] = [:]

        for dose in finalizedDoses {
            dosesByDay[calendar.startOfDay(for: dose.scheduledAt), default: []].append(dose)
        }

        return dosesByDay
            .map { date, dayDoses in
                ActivityDaySection(
                    date: date,
                    moments: activityMoments(for: dayDoses)
                )
            }
            .sorted { $0.date > $1.date }
    }

    func activityDayTitle(for date: Date) -> String {
        let referenceDate = referenceDateProvider()

        if calendar.isDate(date, inSameDayAs: referenceDate) {
            return "Today"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = false
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = calendar
        return formatter.string(from: date)
    }

    init(
        reviewMedicationHistoryUseCase: ReviewMedicationHistoryUseCase,
        correctDoseRecordUseCase: CorrectDoseRecordUseCase,
        calendar: Calendar,
        referenceDateProvider: @escaping () -> Date = Date.init,
        doses: [ScheduledDose] = [],
        isLoading: Bool = false,
        actionInProgressDoseID: UUID? = nil,
        errorMessage: String? = nil
    ) {
        self.reviewMedicationHistoryUseCase = reviewMedicationHistoryUseCase
        self.correctDoseRecordUseCase = correctDoseRecordUseCase
        self.calendar = calendar
        self.referenceDateProvider = referenceDateProvider
        self.doses = doses
        self.isLoading = isLoading
        self.actionInProgressDoseID = actionInProgressDoseID
        self.errorMessage = errorMessage
        self.correctionErrorMessage = nil
    }

    func loadHistory() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            doses = try await reviewMedicationHistoryUseCase.execute(referenceDate: referenceDateProvider())
        } catch let error as ReviewMedicationHistoryUseCaseError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = "We couldn't load your medication history. Please try again."
        }
    }

    func retry() async {
        await loadHistory()
    }

    func markRecordAsNotTaken(_ dose: ScheduledDose) async {
        guard actionInProgressDoseID == nil else {
            return
        }

        actionInProgressDoseID = dose.id
        correctionErrorMessage = nil

        defer {
            actionInProgressDoseID = nil
        }

        do {
            _ = try await correctDoseRecordUseCase.execute(
                scheduledDoseID: dose.id,
                correction: .notTaken,
                referenceDate: referenceDateProvider()
            )
            await loadHistory()
        } catch let error as CorrectDoseRecordUseCaseError {
            correctionErrorMessage = mapError(error)
        } catch {
            correctionErrorMessage = "We couldn't correct this record. Please try again."
        }
    }

    private func mapError(_ error: ReviewMedicationHistoryUseCaseError) -> String {
        switch error {
        case .invalidDateCalculation, .persistenceFailure:
            return "We couldn't load your activity. Please try again."
        }
    }

    private func mapError(_ error: CorrectDoseRecordUseCaseError) -> String {
        switch error {
        case .doseNotFound:
            return "This medication record is no longer available."
        case .persistenceFailure:
            return "We couldn't correct this record. Please try again."
        }
    }

    private func activityMoments(for doses: [ScheduledDose]) -> [ActivityMoment] {
        var dosesByMoment: [Date: [ScheduledDose]] = [:]

        for dose in doses {
            dosesByMoment[calendarMinute(for: dose.scheduledAt), default: []].append(dose)
        }

        return dosesByMoment
            .map { scheduledAt, momentDoses in
                ActivityMoment(
                    scheduledAt: scheduledAt,
                    doses: momentDoses.sorted {
                        if $0.medicationName == $1.medicationName {
                            return $0.id.uuidString < $1.id.uuidString
                        }

                        return $0.medicationName.localizedStandardCompare($1.medicationName) == .orderedAscending
                    }
                )
            }
            .sorted { $0.scheduledAt > $1.scheduledAt }
    }

    private func calendarMinute(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }
}
