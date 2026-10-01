import Combine
import Foundation

@MainActor
final class MedicationListViewModel: ObservableObject {
    @Published private(set) var medications: [Medication]
    @Published private(set) var isLoading: Bool
    @Published var errorMessage: String?

    private let reviewMedicationsUseCase: ReviewMedicationsUseCase

    var activeMedications: [Medication] {
        medications.filter(\.isActive)
    }

    var inactiveMedications: [Medication] {
        medications.filter { !$0.isActive }
    }

    init(
        reviewMedicationsUseCase: ReviewMedicationsUseCase,
        medications: [Medication] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.reviewMedicationsUseCase = reviewMedicationsUseCase
        self.medications = medications
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }

    func loadMedications() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            medications = try await reviewMedicationsUseCase.execute()
        } catch let error as ReviewMedicationsUseCaseError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = "We couldn't load your medications. Please try again."
        }
    }

    func retry() async {
        await loadMedications()
    }

    private func mapError(_ error: ReviewMedicationsUseCaseError) -> String {
        switch error {
        case .persistenceFailure:
            return "We couldn't load your medications. Please try again."
        }
    }
}
