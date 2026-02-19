import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Attributes (must match AllTypes.swift in main target)
struct MindfulBooActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: TimeInterval
        var progress: Double
        var sessionState: SessionState
        var sessionEndTime: Date
    }
    var sessionDuration: TimeInterval
    var sessionStartTime: Date
}

enum SessionState: String, Codable, Hashable {
    case running, paused, ended
}

// MARK: - Design tokens (dark palette — lock screen is always dark)
private extension Color {
    static let wBg      = Color(red: 0.051, green: 0.047, blue: 0.043)
    static let wSurface = Color(red: 0.110, green: 0.100, blue: 0.090)
    static let wPrimary = Color(red: 0.945, green: 0.922, blue: 0.890)
    static let wSecond  = Color(red: 0.600, green: 0.565, blue: 0.535)
    static let wAccent  = Color(red: 0.830, green: 0.698, blue: 0.510)
}

// MARK: - Thin progress bar
private struct MBProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.wSecond.opacity(0.20))
                    .frame(height: 2)
                Capsule()
                    .fill(Color.wAccent)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))), height: 2)
            }
        }
        .frame(height: 2)
    }
}

// MARK: - Lock screen / notification banner view
private struct LockScreenView: View {
    let context: ActivityViewContext<MindfulBooActivityAttributes>

    private var stateLabel: String {
        switch context.state.sessionState {
        case .paused: return "paused"
        case .ended:  return "complete"
        default:      return "meditating"
        }
    }

    private var progressPercent: Int {
        Int(context.state.progress * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "leaf")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(.wAccent)
                    Text("mindfulboo")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(2.5)
                        .foregroundColor(.wSecond)
                }
                Spacer()
                Text(stateLabel)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .foregroundColor(.wSecond.opacity(0.65))
            }
            .padding(.bottom, 20)

            // ── Countdown timer ──────────────────────────────────────
            if context.state.sessionState == .ended {
                Text("session complete")
                    .font(.custom("Georgia-Italic", size: 30))
                    .foregroundColor(.wPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)
            } else if context.state.sessionState == .paused {
                // Static display when paused
                let m = Int(context.state.timeRemaining) / 60
                let s = Int(context.state.timeRemaining) % 60
                Text(String(format: "%d:%02d", m, s))
                    .font(.custom("Georgia", size: 48))
                    .monospacedDigit()
                    .foregroundColor(.wPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)
            } else {
                Text(timerInterval: Date.now...context.state.sessionEndTime, countsDown: true)
                    .font(.custom("Georgia", size: 48))
                    .monospacedDigit()
                    .foregroundColor(.wPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)
            }

            Text("remaining")
                .font(.system(size: 8, weight: .medium))
                .tracking(3)
                .foregroundColor(.wSecond)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)

            // ── Progress bar ─────────────────────────────────────────
            HStack(alignment: .center, spacing: 10) {
                MBProgressBar(progress: context.state.progress)
                Text("\(progressPercent)%")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(.wAccent)
                    .monospacedDigit()
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(Color.wBg)
    }
}

// MARK: - Widget
struct MindfulBooWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MindfulBooActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.wBg)
                .activitySystemActionForegroundColor(Color.wAccent)

        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded ──────────────────────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.wAccent)
                        Text("mindfulboo")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(1.5)
                            .foregroundColor(.wPrimary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.sessionEndTime, countsDown: true)
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(.wAccent)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        MBProgressBar(progress: context.state.progress)
                        HStack {
                            Text("meditating")
                                .font(.system(size: 9, weight: .medium))
                                .tracking(2)
                                .foregroundColor(.wSecond)
                            Spacer()
                            Text("\(Int(context.state.progress * 100))% complete")
                                .font(.system(size: 9, weight: .medium))
                                .tracking(1)
                                .foregroundColor(.wSecond)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "leaf")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.wAccent)
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.sessionEndTime, countsDown: true)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.wAccent)
                    .frame(width: 46)
            } minimal: {
                Image(systemName: "leaf")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.wAccent)
            }
            .keylineTint(Color.wAccent)
        }
    }
}
