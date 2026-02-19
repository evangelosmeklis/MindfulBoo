import SwiftUI

// MARK: - Session History View

struct SessionHistoryView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var healthStore: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSession: Session?
    @State private var showingDeleteAllAlert = false

    var body: some View {
        ZStack {
            Color.mbBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("history")
                            .font(.custom("Georgia-Italic", size: 30))
                            .foregroundColor(.mbPrimary)
                        Text("\(sessionManager.sessions.count) sessions")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbSecondary)
                    }

                    Spacer()

                    HStack(spacing: 16) {
                        if !sessionManager.sessions.isEmpty {
                            Button("delete all") {
                                showingDeleteAllAlert = true
                            }
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(.red.opacity(0.55))
                        }

                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Circle()
                                .stroke(Color.mbSecondary.opacity(0.20), lineWidth: 0.7)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .light))
                                        .foregroundColor(.mbSecondary)
                                )
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 48)
                .padding(.bottom, 32)

                if sessionManager.sessions.isEmpty {
                    Spacer()
                    EmptyHistoryView()
                    Spacer()
                } else {
                    // Stats row
                    SessionSummaryStatsView(sessions: sessionManager.sessions)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 28)

                    // Separator
                    Rectangle()
                        .fill(Color.mbSecondary.opacity(0.10))
                        .frame(height: 0.5)
                        .padding(.horizontal, 28)

                    // Sessions list
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(sessionManager.sessions.reversed()) { session in
                                SessionRowView(session: session)
                                    .onTapGesture { selectedSession = session }

                                Rectangle()
                                    .fill(Color.mbSecondary.opacity(0.07))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 28)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .alert("Delete All Sessions", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                sessionManager.deleteAllSessions()
            }
        } message: {
            Text("This cannot be undone. Your mindful minutes remain safely in the Health app.")
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
    }

}

// MARK: - Summary Stats

struct SessionSummaryStatsView: View {
    let sessions: [Session]

    private var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.effectiveDuration }
    }
    private var completedCount: Int {
        sessions.filter { $0.isCompleted }.count
    }
    private var averageDuration: TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        return totalDuration / Double(sessions.count)
    }
    private var totalStr: String {
        let h = Int(totalDuration) / 3600
        let m = (Int(totalDuration) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
    private var avgStr: String { "\(Int(averageDuration) / 60)m" }

    var body: some View {
        HStack(spacing: 0) {
            statCell(value: totalStr, label: "total time")
            thinDivider
            statCell(value: "\(sessions.count)", label: "sessions")
            thinDivider
            statCell(value: avgStr, label: "average")
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.custom("Georgia", size: 22))
                .foregroundColor(.mbPrimary)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundColor(.mbSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color.mbSecondary.opacity(0.15))
            .frame(width: 0.5, height: 36)
    }
}

// MARK: - Stats Card (kept for compatibility)

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.custom("Georgia", size: 20))
                .foregroundColor(.mbPrimary)
            Text(title)
                .font(.system(size: 8, weight: .medium))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundColor(.mbSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.mbSurface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Empty History

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .stroke(Color.mbSecondary.opacity(0.18), lineWidth: 0.7)
                .frame(width: 68, height: 68)
                .overlay(
                    Image(systemName: "leaf")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundColor(Color.mbSecondary.opacity(0.45))
                )

            Text("no sessions yet")
                .font(.custom("Georgia-Italic", size: 20))
                .foregroundColor(Color.mbPrimary.opacity(0.45))

            Text("begin your first meditation")
                .font(.system(size: 8, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(Color.mbSecondary.opacity(0.55))
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(session.formattedDate)
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(.mbPrimary)
                Text(session.formattedDuration)
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundColor(.mbSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text("\(Int(session.completionPercentage * 100))%")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(session.isCompleted ? Color.mbAccent : .mbPrimary)
                Text(session.isCompleted ? "complete" : "partial")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundColor(Color.mbSecondary.opacity(0.55))
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    let session: Session
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false

    var body: some View {
        ZStack {
            Color.mbBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("session")
                            .font(.custom("Georgia-Italic", size: 30))
                            .foregroundColor(.mbPrimary)
                        Text(session.formattedDate)
                            .font(.system(size: 8, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbSecondary)
                    }

                    Spacer()

                    HStack(spacing: 16) {
                        Button("delete") { showingDeleteAlert = true }
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(.red.opacity(0.55))

                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Circle()
                                .stroke(Color.mbSecondary.opacity(0.20), lineWidth: 0.7)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .light))
                                        .foregroundColor(.mbSecondary)
                                )
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 48)
                .padding(.bottom, 44)

                // Detail rows
                SessionSummaryCard(session: session)
                    .padding(.horizontal, 28)

                Spacer()

                // Insight
                if let insight = sessionInsight {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("insight")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbSecondary)
                        Text(insight)
                            .font(.custom("Georgia-Italic", size: 16))
                            .foregroundColor(Color.mbPrimary.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }
                    .padding(24)
                    .background(Color.mbSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.mbSecondary.opacity(0.10), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 28)
                    .padding(.bottom, 44)
                }
            }
        }
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                sessionManager.deleteSession(session)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("This cannot be undone. Your mindful minutes remain in the Health app.")
        }
    }

    private var sessionInsight: String? {
        let minutes = Int(session.effectiveDuration) / 60
        if session.isCompleted && minutes >= 20 {
            return "A deep practice. Extended sessions reveal layers of awareness that shorter ones only hint at."
        } else if session.isCompleted && minutes >= 10 {
            return "Consistency over intensity. This session is a stone laid on the path."
        } else if session.isCompleted {
            return "Even a few minutes of stillness can shift the entire quality of a day."
        } else {
            return "Every interrupted practice is still practice. Returning matters more than perfection."
        }
    }
}

// MARK: - Session Summary Card

struct SessionSummaryCard: View {
    let session: Session

    var body: some View {
        VStack(spacing: 0) {
            detailRow(label: "duration",    value: session.formattedDuration)
            separator
            detailRow(label: "completion",  value: "\(Int(session.completionPercentage * 100))%",
                      valueColor: session.isCompleted ? Color.mbAccent : .mbPrimary)
            separator
            detailRow(label: "status",      value: session.isCompleted ? "completed" : "ended early")
            separator
            detailRow(label: "health sync", value: "synced", valueColor: Color.mbAccent)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.mbSecondary.opacity(0.08))
            .frame(height: 0.5)
    }

    private func detailRow(label: String, value: String, valueColor: Color = .mbPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundColor(.mbSecondary)
            Spacer()
            Text(value)
                .font(.custom("Georgia", size: 16))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Session Insights Card (kept for compatibility)

struct SessionInsightsCard: View {
    let session: Session
    var body: some View { EmptyView() }
}

// MARK: - Insight Row (kept for compatibility)

struct InsightRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var body: some View { EmptyView() }
}

#Preview {
    SessionHistoryView()
        .environmentObject(SessionManager())
        .environmentObject(HealthKitManager())
}
