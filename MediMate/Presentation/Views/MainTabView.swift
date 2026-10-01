import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var dependencies: MedicationManagementDependencies

    var body: some View {
        TabView {
            TodayTabView(reviewTodaysMedicationUseCase: dependencies.reviewTodaysMedicationUseCase)
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }

            MedicationTabView(reviewMedicationsUseCase: dependencies.reviewMedicationsUseCase)
                .tabItem {
                    Label("Medications", systemImage: "pills")
                }

            PlaceholderTabView(
                title: "History",
                systemImage: "clock.arrow.circlepath",
                message: "Dose history will appear here."
            )
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}

private struct PlaceholderTabView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text(message)
            }
            .navigationTitle(title)
        }
    }
}
