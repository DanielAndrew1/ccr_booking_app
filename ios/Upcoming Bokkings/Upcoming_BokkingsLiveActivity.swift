//
//  Upcoming_BokkingsLiveActivity.swift
//  Upcoming Bokkings
//
//  Created by Andrew Emil on 28/12/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Upcoming_BokkingsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Upcoming_BokkingsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Upcoming_BokkingsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension Upcoming_BokkingsAttributes {
    fileprivate static var preview: Upcoming_BokkingsAttributes {
        Upcoming_BokkingsAttributes(name: "World")
    }
}

extension Upcoming_BokkingsAttributes.ContentState {
    fileprivate static var smiley: Upcoming_BokkingsAttributes.ContentState {
        Upcoming_BokkingsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Upcoming_BokkingsAttributes.ContentState {
         Upcoming_BokkingsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Upcoming_BokkingsAttributes.preview) {
   Upcoming_BokkingsLiveActivity()
} contentStates: {
    Upcoming_BokkingsAttributes.ContentState.smiley
    Upcoming_BokkingsAttributes.ContentState.starEyes
}
