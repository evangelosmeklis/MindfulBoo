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
    }

    // Static data that doesn't change
    var sessionDuration: TimeInterval
}

enum SessionState: String, Codable, Hashable {
    case running
    case paused
    case ended
}

struct MindfulBooWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MindfulBooActivityAttributes.self) { context in
            // Lock screen/banner UI
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "lotus")
                        .font(.title2)
                    Text("MindfulBoo Session")
                        .font(.headline)
                }
                
                ProgressView(value: context.state.progress)
                    .progressViewStyle(.linear)
                
                Text(timerInterval: Date.now...Date.now.addingTimeInterval(context.state.timeRemaining), countsDown: true)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.5))
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "lotus")
                        .font(.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...Date.now.addingTimeInterval(context.state.timeRemaining), countsDown: true)
                        .font(.title)
                        .fontWeight(.semibold)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.linear)
                        .tint(.white)
                }
            } compactLeading: {
                Image(systemName: "lotus")
            } compactTrailing: {
                Text(timerInterval: Date.now...Date.now.addingTimeInterval(context.state.timeRemaining), countsDown: true)
                    .frame(width: 50)
            } minimal: {
                Image(systemName: "lotus")
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.white)
        }
    }
}

