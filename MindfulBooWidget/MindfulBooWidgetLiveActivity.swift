//
//  MindfulBooWidgetLiveActivity.swift
//  MindfulBooWidget
//
//  Created by Evangelos Meklis on 18/7/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Attributes
struct MindfulBooActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data that changes during the session
        var timeRemaining: TimeInterval
        var progress: Double
        var sessionState: SessionState
        var sessionEndTime: Date // Add fixed end time for consistent countdown
    }

    // Static data that doesn't change
    var sessionDuration: TimeInterval
    var sessionStartTime: Date // Add start time for reference
}

enum SessionState: String, Codable, Hashable {
    case running
    case paused
    case ended
}

struct GradientProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 6)
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.green, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(progress), height: 6)
            }
        }
        .frame(height: 6)
    }
}

struct MindfulBooWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MindfulBooActivityAttributes.self) { context in
            // Lock screen/banner UI
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lotus")
                        .font(.title2)
                    Text("MindfulBoo")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)

                GradientProgressBar(progress: context.state.progress)

                Text(timerInterval: Date.now...context.state.sessionEndTime, countsDown: true)
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.green, .blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.9)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .activityBackgroundTint(Color.clear)
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "lotus")
                        .font(.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.sessionEndTime, countsDown: true)
                        .font(.title)
                        .fontWeight(.semibold)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    GradientProgressBar(progress: context.state.progress)
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: "lotus")
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.sessionEndTime, countsDown: true)
                    .frame(width: 50)
            } minimal: {
                Image(systemName: "lotus")
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.white)
        }
    }
}

