import Combine
import Foundation

struct HistoryDaySection: Identifiable, Equatable {
    let date: Date
    let doses: [ScheduledDose]

    var id: Date {
        date
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var doses: [ScheduledDose]
    @Published private(set) var isLoading: Bool
    @Published var errorMessage: String?

    private let reviewMedicationHistoryUseCase: ReviewMedicationHistoryUseCase
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

    init(
        reviewMedicationHistoryUseCase: ReviewMedicationHistoryUseCase,
        calendar: Calendar,
        referenceDateProvider: @escaping () -> Date = Date.init,
        doses: [ScheduledDose] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.reviewMedicationHistoryUseCase = reviewMedicationHistoryUseCase
        self.calendar = calendar
        self.referenceDateProvider = referenceDateProvider
        self.doses = doses
        self.isLoading = isLoading
        self.errorMessage = errorMessage
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

    private func mapError(_ error: ReviewMedicationHistoryUseCaseError) -> String {
        switch error {
        case .invalidDateCalculation, .persistenceFailure:
            return "We couldn't load your medication history. Please try again."
        }
    }
}
