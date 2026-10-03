import SwiftUI

enum MediMateTheme {
    static let background = Color("MediMateBackground")
    static let surface = Color("MediMateSurface")
    static let elevatedSurface = Color("MediMateElevatedSurface")
    static let primaryText = Color("MediMatePrimaryText")
    static let secondaryText = Color("MediMateSecondaryText")
    static let accent = Color("MediMateAccent")
    static let accentTint = Color("MediMateAccentTint")
    static let border = Color("MediMateBorder")

    static let cornerRadius: CGFloat = 16
    static let compactCornerRadius: CGFloat = 12
}

struct MediMateSurface<Content: View>: View {
    enum Style {
        case standard
        case highlighted
        case flat
    }

    let style: Style
    @ViewBuilder let content: Content

    init(style: Style = .standard, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: MediMateTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: MediMateTheme.cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(color: shadowColor, radius: 10, x: 0, y: 4)
    }

    private var backgroundColor: Color {
        switch style {
        case .standard:
            return MediMateTheme.surface
        case .highlighted:
            return MediMateTheme.accentTint
        case .flat:
            return MediMateTheme.elevatedSurface
        }
    }

    private var borderColor: Color {
        switch style {
        case .highlighted:
            return MediMateTheme.accent.opacity(0.28)
        case .standard, .flat:
            return MediMateTheme.border
        }
    }

    private var shadowColor: Color {
        switch style {
        case .standard, .highlighted:
            return Color.black.opacity(0.05)
        case .flat:
            return .clear
        }
    }
}

struct MediMateStatusBadge: View {
    let status: DoseStatus
    var compact = false

    var body: some View {
        Label {
            Text(label)
                .font(.caption.weight(.semibold))
        } icon: {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 5 : 6)
        .background(backgroundColor, in: Capsule())
        .accessibilityLabel(label)
    }

    private var label: String {
        switch status {
        case .taken:
            return "Taken"
        case .due:
            return "Due"
        case .upcoming:
            return "Upcoming"
        case .skipped:
            return "Skipped"
        case .missed:
            return "Missed"
        }
    }

    private var systemImage: String {
        switch status {
        case .taken:
            return "checkmark.circle.fill"
        case .due:
            return "exclamationmark.circle.fill"
        case .upcoming:
            return "clock.fill"
        case .skipped:
            return "minus.circle.fill"
        case .missed:
            return "xmark.circle.fill"
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .taken:
            return Color(red: 0.18, green: 0.48, blue: 0.28)
        case .due:
            return Color(red: 0.62, green: 0.38, blue: 0.08)
        case .upcoming:
            return Color(red: 0.22, green: 0.42, blue: 0.48)
        case .skipped:
            return Color.secondary
        case .missed:
            return Color(red: 0.66, green: 0.27, blue: 0.22)
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .taken:
            return Color.green.opacity(0.14)
        case .due:
            return Color.orange.opacity(0.16)
        case .upcoming:
            return MediMateTheme.accent.opacity(0.12)
        case .skipped:
            return Color.secondary.opacity(0.12)
        case .missed:
            return Color.red.opacity(0.12)
        }
    }
}

struct MedicationGlyph: View {
    let seed: String
    var isActive = true

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(isActive ? 0.18 : 0.10))

            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isActive ? color : Color.secondary)
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }

    private var symbol: String {
        let symbols = ["pills.fill", "capsule.fill", "circle.hexagongrid.fill"]
        return symbols[abs(seed.hashValue) % symbols.count]
    }

    private var color: Color {
        let colors = [
            Color(red: 0.19, green: 0.49, blue: 0.45),
            Color(red: 0.42, green: 0.48, blue: 0.28),
            Color(red: 0.40, green: 0.38, blue: 0.57),
            Color(red: 0.58, green: 0.40, blue: 0.28)
        ]
        return colors[abs(seed.hashValue) % colors.count]
    }
}

struct MediMateEmptyState: View {
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(MediMateTheme.accent)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MediMateTheme.primaryText)

                Text(message)
                    .font(.body)
                    .foregroundStyle(MediMateTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(MediMateTheme.accent)
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MediMateTheme.background)
    }
}
