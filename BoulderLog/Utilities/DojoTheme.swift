import SwiftUI

enum DojoTheme {
    static let background = Color(hex: "F4F1EA")
    static let surface = Color(hex: "ECE7DE")
    static let textPrimary = Color(hex: "2C2A26")
    static let textSecondary = Color(hex: "7A746B")
    static let accentPrimary = Color(hex: "D88A42")
    static let accentSecondary = Color(hex: "8E9775")
    static let divider = Color.black.opacity(0.08)
    static let holdFill = Color(hex: "BCAEA0").opacity(0.25)
}

enum DojoType {
    static let title = Font.system(size: 24, weight: .medium)
    static let section = Font.system(size: 17, weight: .medium)
    static let body = Font.system(size: 15, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
}

enum DojoSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

struct DojoScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            DojoTheme.background.ignoresSafeArea()
            content
                .foregroundStyle(DojoTheme.textPrimary)
                .padding(.horizontal, 22)
        }
    }
}

struct DojoSurface<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 18

    init(cornerRadius: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(DojoSpace.lg)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DojoTheme.surface.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(DojoTheme.divider, lineWidth: 0.8)
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 1)
    }
}

struct DojoButtonPrimary: View {
    let title: String
    var icon: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DojoSpace.sm) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(DojoType.body.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(disabled ? DojoTheme.accentPrimary.opacity(0.45) : DojoTheme.accentPrimary)
            )
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}

struct DojoButtonSecondary: View {
    let title: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DojoSpace.sm) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(DojoType.body)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(DojoTheme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.74))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DojoTheme.divider, lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct DojoTagChip: View {
    let title: String
    let selected: Bool
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) { chipBody }
                    .buttonStyle(.plain)
            } else {
                chipBody
            }
        }
    }

    private var chipBody: some View {
        Text(title)
            .font(DojoType.caption)
            .foregroundStyle(selected ? DojoTheme.textPrimary : DojoTheme.textSecondary)
            .padding(.horizontal, DojoSpace.md)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? DojoTheme.accentSecondary.opacity(0.22) : Color.white.opacity(0.76))
                    .overlay(Capsule(style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
            )
    }
}

struct DojoSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DojoSpace.xs) {
            Text(title)
                .font(DojoType.section)
                .foregroundStyle(DojoTheme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(DojoType.caption)
                    .foregroundStyle(DojoTheme.textSecondary)
            }
        }
    }
}

struct DojoEmptyState: View {
    let title: String
    let subtitle: String
    var icon: String = "circle.grid.2x2"

    var body: some View {
        DojoSurface {
            VStack(spacing: DojoSpace.md) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(DojoTheme.textSecondary)
                Text(title)
                    .font(DojoType.section)
                Text(subtitle)
                    .font(DojoType.caption)
                    .foregroundStyle(DojoTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct DojoHoldMarker: View {
    let role: HoldRole
    let diameter: CGFloat
    let orderText: String?
    var selected: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(DojoTheme.holdFill)

            Circle()
                .stroke(DojoTheme.accentSecondary, lineWidth: ringWidth)

            if role == .start {
                Circle()
                    .inset(by: 3)
                    .stroke(DojoTheme.accentSecondary, lineWidth: 1)
            }

            if let orderText {
                Text(orderText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DojoTheme.textPrimary)
            }

            if selected {
                Circle().stroke(DojoTheme.accentPrimary.opacity(0.8), lineWidth: 1.5)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var ringWidth: CGFloat {
        switch role {
        case .finish: return 2.8
        case .start: return 2.0
        case .normal: return 1.6
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
