//
//  KnuckleTimerActivityBundle.swift
//  KnuckleTimerActivity
//
//  Created by Paul Mignard on 1/31/26.
//

import WidgetKit
import SwiftUI

@main
struct KnuckleTimerActivityBundle: WidgetBundle {
    var body: some Widget {
        KnuckleTimerWidget()
        if #available(iOS 16.2, *) {
            KnuckleTimerActivityLiveActivity()
        }
    }
}
