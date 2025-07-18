//
//  MindfulBooWidgetBundle.swift
//  MindfulBooWidget
//
//  Created by Evangelos Meklis on 18/7/25.
//

import WidgetKit
import SwiftUI

@main
struct MindfulBooWidgetBundle: WidgetBundle {
    var body: some Widget {
        MindfulBooWidget()
        MindfulBooWidgetControl()
        MindfulBooWidgetLiveActivity()
    }
}
