import SwiftUI

struct MainTabView: View {
    private enum Tab {
        case today
        case medications
        case activity
    }

    @EnvironmentObject private var dependencies: MedicationManagementDependencies
    @State private var selectedTab: Tab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayTabView(
                reviewTodaysMedicationUseCase: dependencies.reviewTodaysMedicationUseCase,
                recordDoseAsTakenUseCase: dependencies.recordDoseAsTakenUseCase,
                recordMedicationMomentAsTakenUseCase: dependencies.recordMedicationMomentAsTakenUseCase,
                skipScheduledDoseUseCase: dependencies.skipScheduledDoseUseCase,
                correctDoseRecordUseCase: dependencies.correctDoseRecordUseCase,
                widgetSnapshotSynchronizer: dependencies.widgetSnapshotSynchronizer
            )
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }
                .tag(Tab.today)

            MedicationTabView(reviewMedicationsUseCase: dependencies.reviewMedicationsUseCase)
                .tabItem {
                    Label("Medications", systemImage: "pills")
                }
                .tag(Tab.medications)

            ActivityTabView(
                reviewMedicationHistoryUseCase: dependencies.reviewMedicationHistoryUseCase,
                correctDoseRecordUseCase: dependencies.correctDoseRecordUseCase
            )
            .tabItem {
                Label("Activity", systemImage: "clock.badge.checkmark")
            }
            .tag(Tab.activity)
        }
        .tint(MediMateTheme.accent)
        .onOpenURL { url in
            guard url.scheme == "medimate", url.host == "today" else {
                return
            }

            selectedTab = .today
        }
    }
}
