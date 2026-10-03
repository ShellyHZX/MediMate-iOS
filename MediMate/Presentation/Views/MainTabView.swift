import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var dependencies: MedicationManagementDependencies

    var body: some View {
        TabView {
            TodayTabView(
                reviewTodaysMedicationUseCase: dependencies.reviewTodaysMedicationUseCase,
                recordDoseAsTakenUseCase: dependencies.recordDoseAsTakenUseCase,
                recordMedicationMomentAsTakenUseCase: dependencies.recordMedicationMomentAsTakenUseCase,
                skipScheduledDoseUseCase: dependencies.skipScheduledDoseUseCase,
                correctDoseRecordUseCase: dependencies.correctDoseRecordUseCase
            )
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }

            MedicationTabView(reviewMedicationsUseCase: dependencies.reviewMedicationsUseCase)
                .tabItem {
                    Label("Medications", systemImage: "pills")
                }

            ActivityTabView(
                reviewMedicationHistoryUseCase: dependencies.reviewMedicationHistoryUseCase,
                correctDoseRecordUseCase: dependencies.correctDoseRecordUseCase
            )
            .tabItem {
                Label("Activity", systemImage: "clock.badge.checkmark")
            }
        }
        .tint(MediMateTheme.accent)
    }
}
