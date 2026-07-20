//
//  MyNetBuddyApp.swift
//  MyNetBuddy
//
//  Created by Julian Alconcher on 20/07/2026.
//

import SwiftUI

@main
struct MyNetBuddyApp: App {
    @StateObject private var viewModel = NetworkViewModel()

    var body: some Scene {
        MenuBarExtra("MyNetBuddy", systemImage: viewModel.menuBarIconName) {
            MenuBarContentView(viewModel: viewModel)
                .frame(width: 360)
        }
        .menuBarExtraStyle(.window)
    }
}
