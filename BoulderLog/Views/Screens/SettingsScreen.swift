import SwiftUI
import SwiftData
import UIKit

struct SettingsScreen: View {
    @Query(sort: \SessionEntity.date, order: .reverse) private var sessions: [SessionEntity]
    @Query(sort: \ProjectEntryEntity.updatedAt, order: .reverse) private var entries: [ProjectEntryEntity]
    @Environment(\.openURL) private var openURL

    var selectTab: (AppTab) -> Void = { _ in }

    private let analytics = AnalyticsService()
    private let actionColumns = [GridItem(.flexible(), spacing: DojoSpace.sm), GridItem(.flexible(), spacing: DojoSpace.sm)]

    var body: some View {
        NavigationStack {
            DojoScreen {
                ScrollView {
                    VStack(spacing: DojoSpace.lg) {
                        heroCard
                        quickActionsCard
                        workflowCard
                        snapshotCard
                        privacyCard
                    }
                    .padding(.vertical, DojoSpace.lg)
                }
            }
            .navigationTitle("Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DojoTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var heroCard: some View {
        DojoSurface(cornerRadius: 24) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DojoTheme.surface.opacity(0.45),
                                Color.white.opacity(0.76)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(DojoTheme.accentPrimary.opacity(0.14))
                    .frame(width: 150, height: 150)
                    .offset(x: 140, y: -60)

                Circle()
                    .fill(DojoTheme.accentSecondary.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .offset(x: -30, y: 110)

                VStack(alignment: .leading, spacing: DojoSpace.md) {
                    HStack(spacing: DojoSpace.sm) {
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(DojoTheme.accentPrimary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("BoulderLog Guide")
                                .font(DojoType.section)
                            Text("Local route extraction, clean logs, fast review")
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                        }
                    }

                    Text("Track each climb from wall photo to finished blueprint.")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(DojoTheme.textPrimary)

                    Text("BoulderLog keeps your sessions, route notes, hold edits, and PNG exports organized. The workflow stays local and manual where it matters: crop the wall, confirm the holds, then save a route you can actually revisit.")
                        .font(DojoType.body)
                        .foregroundStyle(DojoTheme.textPrimary)

                    HStack(spacing: DojoSpace.sm) {
                        guideBadge(title: "Local extraction")
                        guideBadge(title: "Editable holds")
                        guideBadge(title: "PNG export")
                    }
                }
            }
        }
    }

    private var quickActionsCard: some View {
        DojoSurface {
            VStack(alignment: .leading, spacing: DojoSpace.md) {
                DojoSectionHeader(title: "Where To Go", subtitle: "Use this tab as a map, then jump straight into the app")

                LazyVGrid(columns: actionColumns, spacing: DojoSpace.sm) {
                    GuideActionTile(
                        title: "Sessions",
                        detail: "Start a log day and add projects.",
                        icon: "book.closed",
                        action: { selectTab(.sessions) }
                    )

                    GuideActionTile(
                        title: "Library",
                        detail: "Review saved projects and blueprints.",
                        icon: "square.stack.3d.up",
                        action: { selectTab(.library) }
                    )

                    GuideActionTile(
                        title: "Insights",
                        detail: "See trends from your climbing history.",
                        icon: "chart.line.uptrend.xyaxis",
                        action: { selectTab(.insights) }
                    )

                    GuideActionTile(
                        title: "iPhone Settings",
                        detail: "Manage camera and photo permissions.",
                        icon: "slider.horizontal.3",
                        action: openSystemSettings
                    )
                }
            }
        }
    }

    private var workflowCard: some View {
        DojoSurface {
            VStack(alignment: .leading, spacing: DojoSpace.md) {
                DojoSectionHeader(title: "How It Works", subtitle: "The shortest path from climb to reusable record")

                GuideStepRow(
                    number: "1",
                    title: "Create a session",
                    detail: "Use the Sessions tab to log the gym and date. Every project belongs to a session."
                )

                GuideStepRow(
                    number: "2",
                    title: "Build the project",
                    detail: "Add a wall photo, crop the route, choose the route color, and fine-tune the detected holds."
                )

                GuideStepRow(
                    number: "3",
                    title: "Save and export",
                    detail: "Review the blueprint, update grade and status, then export a PNG from the project editor or detail view."
                )
            }
        }
    }

    private var snapshotCard: some View {
        DojoSurface {
            VStack(alignment: .leading, spacing: DojoSpace.md) {
                DojoSectionHeader(title: "Your Snapshot", subtitle: snapshotSubtitle)

                HStack(spacing: DojoSpace.sm) {
                    SnapshotPill(value: "\(sessions.count)", label: "Sessions")
                    SnapshotPill(value: "\(entries.count)", label: "Projects")
                    SnapshotPill(value: sentCountLabel, label: "Sent")
                }

                VStack(alignment: .leading, spacing: DojoSpace.sm) {
                    snapshotRow(title: "Best logged send", detail: bestSentGrade)
                    snapshotRow(title: "Latest session", detail: latestSessionLabel)
                    snapshotRow(title: "Next best move", detail: nextStepDetail)
                }
            }
        }
    }

    private var privacyCard: some View {
        DojoSurface {
            VStack(alignment: .leading, spacing: DojoSpace.md) {
                DojoSectionHeader(title: "What The App Stores", subtitle: "Clear expectations for everyday use")

                GuideInfoRow(
                    icon: "internaldrive",
                    title: "Stored locally",
                    detail: "Sessions, project notes, wall photos, hold outlines, and blueprint edits stay on device."
                )

                GuideInfoRow(
                    icon: "camera",
                    title: "Permissions",
                    detail: "Camera and Photos are only used when you capture or import a wall image."
                )

                GuideInfoRow(
                    icon: "square.and.arrow.up",
                    title: "Sharing",
                    detail: "Blueprint export creates a PNG you can send, save, or keep for your own log."
                )
            }
        }
    }

    private func guideBadge(title: String) -> some View {
        Text(title)
            .font(DojoType.caption.weight(.medium))
            .foregroundStyle(DojoTheme.textPrimary)
            .padding(.horizontal, DojoSpace.md)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.76))
                    .overlay(Capsule(style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
            )
    }

    private func snapshotRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: DojoSpace.sm) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
                .frame(width: 104, alignment: .leading)

            Text(detail)
                .font(DojoType.body)
                .foregroundStyle(DojoTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private var sentEntries: [ProjectEntryEntity] {
        entries.filter { $0.status == .sent || $0.status == .flashed }
    }

    private var sentCountLabel: String {
        "\(sentEntries.count)"
    }

    private var latestSessionLabel: String {
        guard let latest = sessions.first else { return "No sessions yet" }
        let gymSuffix = latest.gym.isEmpty ? "" : " at \(latest.gym)"
        return "\(latest.date.formatted(.dateTime.month(.abbreviated).day().year()))\(gymSuffix)"
    }

    private var bestSentGrade: String {
        guard let best = sentEntries.max(by: { analytics.gradeValue($0.grade) < analytics.gradeValue($1.grade) }) else {
            return "No sends logged yet"
        }
        return best.grade
    }

    private var snapshotSubtitle: String {
        if entries.isEmpty {
            return "No projects saved yet"
        }
        return "A quick read on your current log"
    }

    private var nextStepDetail: String {
        if sessions.isEmpty {
            return "Start in Sessions and create your first climbing day."
        }

        if entries.isEmpty {
            return "Open your latest session and add a project with a wall photo."
        }

        if entries.contains(where: { $0.holds.isEmpty }) {
            return "Revisit any project with missing holds and finish the blueprint before exporting."
        }

        return "Use Library to review completed projects, then check Insights for climbing trends."
    }
}

private struct GuideActionTile: View {
    let title: String
    let detail: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DojoTheme.accentPrimary)

                Text(title)
                    .font(DojoType.body.weight(.medium))
                    .foregroundStyle(DojoTheme.textPrimary)

                Text(detail)
                    .font(DojoType.caption)
                    .foregroundStyle(DojoTheme.textSecondary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .padding(DojoSpace.md)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DojoTheme.divider, lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GuideStepRow: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DojoSpace.md) {
            Text(number)
                .font(DojoType.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(DojoTheme.accentPrimary)
                )

            VStack(alignment: .leading, spacing: DojoSpace.xs) {
                Text(title)
                    .font(DojoType.body.weight(.medium))
                    .foregroundStyle(DojoTheme.textPrimary)
                Text(detail)
                    .font(DojoType.caption)
                    .foregroundStyle(DojoTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct SnapshotPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DojoTheme.textPrimary)
            Text(label)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DojoSpace.md)
        .padding(.vertical, DojoSpace.sm)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DojoTheme.divider, lineWidth: 0.8)
                )
        )
    }
}

private struct GuideInfoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DojoSpace.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DojoTheme.accentSecondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(DojoTheme.accentSecondary.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: DojoSpace.xs) {
                Text(title)
                    .font(DojoType.body.weight(.medium))
                    .foregroundStyle(DojoTheme.textPrimary)
                Text(detail)
                    .font(DojoType.caption)
                    .foregroundStyle(DojoTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
