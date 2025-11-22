//
//  PrepItApp.swift
//  PrepIt
//
//  Created by John Campbell on 10/23/25.
//

import SwiftUI

@main
struct PrepItApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(SessionViewModel())
        }
    }
}
